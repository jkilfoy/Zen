/// §11.6.4. The desktop's side of the LAN exchange.
// `prefer_initializing_formals` fires on every private field this class is
// constructed with: it suggests `this._settings` and friends, which Dart
// forbids, because a named parameter may not begin with an underscore. The
// orchestrator ignores it once for the same reason.
// ignore_for_file: prefer_initializing_formals
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:zen_domain/zen_domain.dart';

import '../snapshot/snapshot_codec.dart';
import '../snapshot/snapshot_envelope.dart';
import '../snapshot/snapshot_format_failure.dart';
import '../sync_log.dart';
import 'lan_crypto.dart';
import 'lan_http.dart';
import 'lan_peer_input.dart';
import 'lan_protocol.dart';

/// §11.6.4. Captures this device's snapshot, `S`, as it stands right now.
typedef LanSnapshotSource = Future<SnapshotEnvelope> Function();

/// §11.6.4. Merges an inbound peer snapshot into this device.
///
/// "The handler passes the client's envelope into the same entry point
/// `"Import snapshot…"` uses, so an inbound sync is provably the same operation
/// as an import" — `SyncOrchestrator.syncWith`. Declared as a function so the
/// server depends on the operation rather than on the orchestrator, and so a
/// test can exercise the protocol without building one.
typedef LanInboundMerge = Future<void> Function(SnapshotEnvelope peer);

/// §11.6.4 step 1. An open pairing window, as the Settings screen shows it.
final class PairingWindow {
  /// Opens a window displaying [code] until [expiresAt].
  PairingWindow({required this.code, required this.expiresAt});

  /// The single-use six-digit code, leading zeros intact.
  final String code;

  /// When the window closes.
  final DateTime expiresAt;

  /// How many wrong codes have been offered.
  int failures = 0;

  /// Whether five failed attempts have closed this window (§11.6.4).
  bool get isExhausted => failures >= LanPairing.maxFailedAttempts;
}

/// §11.8. What the desktop's LAN status line reads.
final class LanServerState {
  /// Records the server's state.
  const LanServerState({
    this.running = false,
    this.port,
    this.error,
    this.pairedDevices = 0,
  });

  /// Whether the listener is up.
  final bool running;

  /// The port it bound, or `null` when it is not running.
  final int? port;

  /// Why it is not running, when something went wrong.
  final String? error;

  /// How many devices are paired.
  final int pairedDevices;
}

/// §11.6.4. The `/zen/v1` server the Windows app runs.
///
/// **Every byte this class reads came from the local network**, so each handler
/// treats its input as hostile: bodies are capped before they are buffered
/// (§11.6.4), the pairing code is compared in constant time, peer-supplied
/// strings are validated before they are stored or shown, and a `/sync` body
/// that no paired key opens is refused without saying why.
///
/// It does **not** merge. §11.6.4: "an HTTP handler re-implementing [§11.6.5's
/// steps] would be a second copy of the most dangerous code in the project."
final class LanSyncServer {
  /// Wires the server to the repositories and the merge entry point.
  LanSyncServer({
    required ReplicaRepository replicas,
    required SettingsRepository settings,
    required LanSnapshotSource snapshotSource,
    required LanInboundMerge inboundMerge,
    required Clock clock,
    required String appVersion,
    SyncLogger log = discardSyncLog,
  }) : _replicas = replicas,
       _settings = settings,
       _snapshotSource = snapshotSource,
       _inboundMerge = inboundMerge,
       _clock = clock,
       _appVersion = appVersion,
       _log = log;

  final ReplicaRepository _replicas;
  final SettingsRepository _settings;
  final LanSnapshotSource _snapshotSource;
  final LanInboundMerge _inboundMerge;
  final Clock _clock;
  final String _appVersion;
  final SyncLogger _log;

  HttpServer? _server;
  String? _error;
  PairingWindow? _window;

  /// Derived keys, by pairing key, so the HKDF pass happens once per peer
  /// rather than once per request (§11.6.4's "tries each paired peer's key").
  final Map<String, LanCipher> _ciphers = <String, LanCipher>{};

  /// Whether the listener is up.
  bool get isRunning => _server != null;

  /// The port bound, or `null`.
  int? get boundPort => _server?.port;

  /// The pairing window currently open, or `null`.
  PairingWindow? get pairingWindow {
    final PairingWindow? window = _window;
    if (window == null || !_clock.nowUtc().isBefore(window.expiresAt)) {
      return null;
    }
    return window;
  }

  /// §11.8. The status line's view of this server.
  Future<LanServerState> state() async => LanServerState(
    running: isRunning,
    port: boundPort,
    error: _error,
    pairedDevices: (await _settings.read()).syncLanPeers.length,
  );

  /// §11.6.4. Starts listening on [port].
  ///
  /// Binds `0.0.0.0` by default, because a LAN peer reaches this device by its
  /// LAN address and binding loopback would make the feature unreachable by
  /// construction. That is also what raises the Windows Firewall prompt
  /// §11.13.1 predicts on first run. [address] exists so the tests can bind
  /// loopback and so a user on a hostile network has somewhere to look.
  ///
  /// A port already in use is recorded and reported, not retried on another
  /// port: the phone was told a port, and silently moving would leave it
  /// dialling a door that is no longer there.
  Future<void> start({required int port, InternetAddress? address}) async {
    await stop();
    try {
      _server = await shelf_io.serve(
        _handler,
        address ?? InternetAddress.anyIPv4,
        port,
      );
      _error = null;
      _log('LAN sync: listening on port ${_server!.port}.');
    } on SocketException catch (error) {
      _error =
          error.osError?.errorCode == 10048 || error.osError?.errorCode == 98
          ? 'Port $port is already in use. Choose another in Settings.'
          : 'Could not listen on port $port: ${error.message}';
      _log('LAN sync: $_error');
    }
  }

  /// Stops listening and closes any open pairing window.
  Future<void> stop() async {
    final HttpServer? server = _server;
    _server = null;
    _window = null;
    if (server != null) {
      await server.close(force: true);
    }
  }

  /// §11.6.4 step 1. Opens a 5-minute pairing window with a fresh code.
  ///
  /// A second call replaces the outstanding code: one window at a time, so that
  /// a user who opens the screen twice cannot leave a forgotten code live.
  PairingWindow openPairingWindow() {
    final PairingWindow window = PairingWindow(
      code: newPairingCode(),
      expiresAt: _clock.nowUtc().add(LanPairing.window),
    );
    _window = window;
    return window;
  }

  /// Closes the pairing window without pairing.
  void closePairingWindow() => _window = null;

  Handler get _handler {
    final Router router = Router()
      ..get(LanPaths.hello, _hello)
      ..post(LanPaths.pair, _pair)
      ..post(LanPaths.sync, _sync);
    return router.call;
  }

  /// §11.6.4. `/hello`: "the only unencrypted endpoint".
  Future<Response> _hello(Request request) async =>
      jsonResponse(200, <String, Object?>{
        LanFields.protocolVersion: lanProtocolVersion,
        LanFields.replicaId: await _replicas.replicaId(),
        LanFields.deviceName: await _replicas.deviceName(),
        LanFields.appVersion: _appVersion,
      });

  /// §11.6.4 step 3. `/pair`.
  Future<Response> _pair(Request request) async {
    final Uint8List? body = await readCapped(request, LanBodyLimits.pair);
    if (body == null) {
      return problemResponse(413, 'That request was too large.');
    }

    final Map<String, Object?>? json = jsonObjectOrNull(body);
    if (json == null) {
      return problemResponse(400, 'That request could not be read.');
    }
    if (json[LanFields.protocolVersion] != lanProtocolVersion) {
      return problemResponse(
        400,
        'These copies of Zen speak different sync protocols. Update both.',
      );
    }

    final PairingWindow? window = pairingWindow;
    if (window == null) {
      return problemResponse(403, 'There is no pairing window open on the PC.');
    }
    if (window.isExhausted) {
      return problemResponse(
        429,
        'Too many wrong codes. Open a new pairing window on the PC.',
      );
    }

    final Object? code = json[LanFields.code];
    if (code is! String || !constantTimeEquals(code, window.code)) {
      window.failures++;
      if (window.isExhausted) {
        _log('LAN pairing: window closed after five wrong codes.');
      }
      return problemResponse(403, 'That code is not right.');
    }

    // The peer's own description of itself, straight off the network. Validated
    // before it is stored or rendered (§11.6.4's QR paragraph makes the same
    // point about the phone's side of this).
    final LanPeerIdentity? identity = LanPeerIdentity.parse(
      replicaId: json[LanFields.replicaId],
      deviceName: json[LanFields.deviceName],
    );
    if (identity == null) {
      return problemResponse(
        400,
        'That device did not identify itself properly.',
      );
    }

    final String psk = newPairingKey();
    await _storePeer(identity, psk);
    // "The desktop verifies the code … and closes the window." Single-use.
    _window = null;
    _log('LAN pairing: paired with "${identity.deviceName}".');

    return jsonResponse(200, <String, Object?>{
      LanFields.psk: psk,
      LanFields.replicaId: await _replicas.replicaId(),
      LanFields.deviceName: await _replicas.deviceName(),
    });
  }

  /// §11.6.4. `/sync`: the one-round-trip exchange.
  Future<Response> _sync(Request request) async {
    final Uint8List? body = await readCapped(request, LanBodyLimits.sync);
    if (body == null) {
      return problemResponse(413, 'That request was too large.');
    }

    final _OpenedMessage? opened = await _open(body);
    if (opened == null) {
      // Deliberately uninformative. An unpaired caller learns only that it is
      // not paired, not whether any device is, nor how many keys were tried.
      return problemResponse(401, 'This device is not paired with that one.');
    }

    final LanMessage message;
    try {
      message = LanMessage.parse(opened.plaintext, _clock);
    } on LanSyncFailure catch (failure) {
      return sealedProblem(opened.cipher, 400, failure.message);
    }

    final Result<SnapshotEnvelope, SnapshotFormatFailure> decoded =
        SnapshotCodec(log: _log).fromJson(message.document);
    if (decoded case Err<SnapshotEnvelope, SnapshotFormatFailure>(
      error: final SnapshotFormatFailure failure,
    )) {
      _log('LAN sync: refusing the peer snapshot. ${failure.message}');
      return sealedProblem(opened.cipher, 400, failure.message);
    }
    final SnapshotEnvelope peer = decoded.unwrap();
    if (peer.replicaId != opened.peer.replicaId) {
      // Not refused: the merge is content-based and tombstone-safe, and a
      // replicaId can legitimately change after a restore. Logged, because a
      // paired device presenting another's identity would otherwise be silent.
      _log(
        'LAN sync: "${opened.peer.deviceName}" sent a snapshot for '
        '${peer.replicaId}, not ${opened.peer.replicaId}.',
      );
    }

    // "The server MUST capture S before applying its merge." The capture is
    // first, and the response is built from it, so the snapshot returned is the
    // one the client merges against whatever the merge below then does here.
    final SnapshotEnvelope ours = await _snapshotSource();
    await _inboundMerge(peer);

    return sealedResponse(
      opened.cipher,
      LanMessage(
        sentAt: _clock.nowUtc(),
        document: SnapshotCodec(log: _log).toJson(ours),
      ),
    );
  }

  /// §11.6.4. "The server tries each paired peer's key in turn."
  Future<_OpenedMessage?> _open(Uint8List body) async {
    for (final LanPeer peer in (await _settings.read()).syncLanPeers) {
      final LanCipher cipher;
      try {
        cipher = _ciphers[peer.psk] ??= await LanCipher.forPairingKey(peer.psk);
      } on LanSyncFailure {
        continue;
      }
      final Uint8List? plaintext = await cipher.openOrNull(body);
      if (plaintext != null) {
        return _OpenedMessage(cipher, peer, plaintext);
      }
    }
    return null;
  }

  /// §11.8. Records the pairing, replacing any earlier one for the same device.
  ///
  /// "`host` and `port` are the **client's** fields … the desktop's record
  /// carries identity and key alone and never dials anything" — hence the empty
  /// host and port 0.
  Future<void> _storePeer(LanPeerIdentity identity, String psk) async {
    final Settings current = await _settings.read();
    await _settings.write(
      current.copyWith(
        syncLanPeers: <LanPeer>[
          for (final LanPeer peer in current.syncLanPeers)
            if (peer.replicaId != identity.replicaId) peer,
          LanPeer(
            replicaId: identity.replicaId,
            deviceName: identity.deviceName,
            host: '',
            port: 0,
            psk: psk,
          ),
        ],
      ),
    );
  }
}

/// A `/sync` body that one paired key opened.
final class _OpenedMessage {
  const _OpenedMessage(this.cipher, this.peer, this.plaintext);

  final LanCipher cipher;
  final LanPeer peer;
  final Uint8List plaintext;
}

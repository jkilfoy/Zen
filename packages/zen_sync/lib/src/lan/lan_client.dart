/// §11.6.4. The phone's HTTP calls: `/hello`, `/pair` and `/sync`.
// `prefer_initializing_formals` fires on every private field this class is
// constructed with: it suggests `this._settings` and friends, which Dart
// forbids, because a named parameter may not begin with an underscore. The
// orchestrator ignores it once for the same reason.
// ignore_for_file: prefer_initializing_formals
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;
import 'package:zen_domain/zen_domain.dart';

import '../snapshot/snapshot_codec.dart';
import '../snapshot/snapshot_envelope.dart';
import '../snapshot/snapshot_format_failure.dart';
import '../sync_log.dart';
import 'lan_crypto.dart';
import 'lan_peer_input.dart';
import 'lan_protocol.dart';

/// §11.6.4. What `/hello` reports about a device.
final class LanHello {
  /// Records a `/hello` response.
  const LanHello({
    required this.protocolVersion,
    required this.replicaId,
    required this.deviceName,
    required this.appVersion,
  });

  /// The protocol the other end speaks.
  final int protocolVersion;

  /// Its replica id.
  final String replicaId;

  /// Its device name.
  final String deviceName;

  /// Its app version.
  final String appVersion;
}

/// §11.6.4. The client half of the LAN protocol.
///
/// **Every response this class reads came from a host the user named**, by
/// typing it or by scanning it, and nothing guarantees the host is a Zen
/// desktop. So each response is parsed as strictly as the server parses its
/// requests: fields are type-checked, the device name is validated before it is
/// stored, and an unexpected shape is a [LanSyncFailure] with something the
/// user can read.
final class LanClient {
  /// Creates a client.
  ///
  /// [syncTimeout] exists because §11.6.4 makes the timeout load-bearing —
  /// "NFR-1's rule that no trigger may block the UI depends on this" — and an
  /// untested timeout is not a timeout. Production takes the spec's 30 s; the
  /// test that proves a hung desktop does not hang the pass takes a short one.
  LanClient({
    http.Client? httpClient,
    Duration syncTimeout = LanTimeouts.sync,
    SyncLogger log = discardSyncLog,
  }) : _syncTimeout = syncTimeout,
       _log = log,
       _http =
           httpClient ??
           http_io.IOClient(
             HttpClient()..connectionTimeout = LanTimeouts.connect,
           );

  final http.Client _http;
  final Duration _syncTimeout;
  final SyncLogger _log;

  /// Releases the underlying connections.
  void close() => _http.close();

  Uri _uri(String host, int port, String path) =>
      Uri(scheme: 'http', host: host, port: port, path: path);

  /// §11.6.4. `GET /zen/v1/hello`.
  Future<LanHello> hello(String host, int port) async {
    final http.Response response = await _send(
      http.Request('GET', _uri(host, port, LanPaths.hello)),
      LanTimeouts.short,
    );
    if (response.statusCode != 200) {
      throw LanSyncFailure(_plainProblem(response));
    }
    final Map<String, Object?> body = _jsonObject(response.bodyBytes);
    final Object? version = body[LanFields.protocolVersion];
    final LanPeerIdentity? identity = LanPeerIdentity.parse(
      replicaId: body[LanFields.replicaId],
      deviceName: body[LanFields.deviceName],
    );
    if (version is! int || identity == null) {
      throw const LanSyncFailure('That does not look like a Zen PC.');
    }
    if (version != lanProtocolVersion) {
      throw LanSyncFailure(
        'These copies of Zen speak different sync protocols '
        '(this one v$lanProtocolVersion, the PC v$version). Update both.',
      );
    }
    final Object? appVersion = body[LanFields.appVersion];
    return LanHello(
      protocolVersion: version,
      replicaId: identity.replicaId,
      deviceName: identity.deviceName,
      appVersion: appVersion is String ? appVersion : '',
    );
  }

  /// §11.6.4 step 3. `POST /zen/v1/pair`.
  ///
  /// Returns the peer record to store, with [host] and [port] filled in — "the
  /// client's fields only", since the desktop's own record never dials back.
  Future<LanPeer> pair({
    required String host,
    required int port,
    required String code,
    required String replicaId,
    required String deviceName,
  }) async {
    final http.Request request =
        http.Request('POST', _uri(host, port, LanPaths.pair))
          ..headers['content-type'] = 'application/json'
          ..bodyBytes = utf8.encode(
            jsonEncode(<String, Object?>{
              LanFields.code: code,
              LanFields.replicaId: replicaId,
              LanFields.deviceName: deviceName,
              LanFields.protocolVersion: lanProtocolVersion,
            }),
          );
    final http.Response response = await _send(request, LanTimeouts.short);
    if (response.statusCode != 200) {
      throw LanSyncFailure(_plainProblem(response));
    }

    final Map<String, Object?> body = _jsonObject(response.bodyBytes);
    final Object? psk = body[LanFields.psk];
    final LanPeerIdentity? identity = LanPeerIdentity.parse(
      replicaId: body[LanFields.replicaId],
      deviceName: body[LanFields.deviceName],
    );
    if (psk is! String || identity == null || !_isKey(psk)) {
      throw const LanSyncFailure(
        'The PC sent a pairing reply Zen could not use.',
      );
    }
    return LanPeer(
      replicaId: identity.replicaId,
      deviceName: identity.deviceName,
      host: host,
      port: port,
      psk: psk,
    );
  }

  /// §11.6.4. `POST /zen/v1/sync`: the one round trip.
  ///
  /// Posts [local] and returns the peer's own snapshot, `S`, as it stood when
  /// the request arrived. The caller merges `[C, S]`; nothing here writes
  /// anything.
  Future<SnapshotEnvelope> exchange({
    required LanPeer peer,
    required String host,
    required int port,
    required SnapshotEnvelope local,
    required Clock clock,
  }) async {
    final LanCipher cipher = await LanCipher.forPairingKey(peer.psk);
    final SnapshotCodec codec = SnapshotCodec(log: _log);
    final Uint8List sealed = await cipher.seal(
      LanMessage(
        sentAt: clock.nowUtc(),
        document: codec.toJson(local),
      ).toBytes(),
    );

    final http.Request request =
        http.Request('POST', _uri(host, port, LanPaths.sync))
          ..headers['content-type'] = 'application/octet-stream'
          ..bodyBytes = sealed;
    final http.Response response = await _send(request, _syncTimeout);

    final Uint8List? plaintext = await cipher.openOrNull(response.bodyBytes);
    if (plaintext == null) {
      // Either the PC refused before it could identify us — in which case the
      // body is a plain-text problem — or it is not paired with this phone any
      // more, which is the case worth naming.
      throw LanSyncFailure(
        response.statusCode == 401
            ? 'The PC is no longer paired with this device. Pair it again.'
            : _plainProblem(response),
      );
    }
    if (response.statusCode != 200) {
      throw LanSyncFailure(_sealedProblem(plaintext));
    }

    final LanMessage message = LanMessage.parse(plaintext, clock);
    return switch (codec.fromJson(message.document)) {
      Ok<SnapshotEnvelope, SnapshotFormatFailure>(
        value: final SnapshotEnvelope envelope,
      ) =>
        envelope,
      Err<SnapshotEnvelope, SnapshotFormatFailure>(
        error: final SnapshotFormatFailure failure,
      ) =>
        throw LanSyncFailure(failure.message),
    };
  }

  /// Sends [request], turning every transport-level failure into a
  /// [LanSyncFailure] the status line can show.
  ///
  /// §11.6.4: a timeout "is recorded as an ordinary per-transport failure".
  Future<http.Response> _send(http.Request request, Duration timeout) async {
    try {
      // The timeout covers **sending as well as reading**. Wrapping only the
      // read leaves `send` unbounded, and a desktop that accepts the connection
      // and then says nothing — a sleeping laptop — hangs there forever, inside
      // the single-flight lock, with every later trigger joining the dead
      // future. That is the exact failure §11.6.4 says NFR-1 depends on this
      // timeout to prevent, and it is what the loopback test that never answers
      // reproduces.
      return await _http
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
    } on TimeoutException {
      throw const LanSyncFailure(
        'The PC did not answer in time. It may have gone to sleep.',
      );
    } on SocketException {
      throw const LanSyncFailure(LanSyncFailure.desktopNotRunningMessage);
    } on http.ClientException {
      throw const LanSyncFailure(LanSyncFailure.desktopNotRunningMessage);
    } on HandshakeException {
      throw const LanSyncFailure('That does not look like a Zen PC.');
    }
  }

  /// A plain-text refusal, capped so a hostile host cannot put a novel in the
  /// status line.
  static String _plainProblem(http.Response response) {
    final String body = response.body.trim();
    if (body.isEmpty || body.length > 200) {
      return 'The PC refused the request (${response.statusCode}).';
    }
    return LanPeerIdentity.parseDeviceName(body) == null
        ? 'The PC refused the request (${response.statusCode}).'
        : body;
  }

  /// A refusal the peer sealed, so one this device is entitled to read.
  static String _sealedProblem(Uint8List plaintext) {
    try {
      final Object? parsed = jsonDecode(utf8.decode(plaintext));
      if (parsed is Map<String, Object?> && parsed['problem'] is String) {
        return parsed['problem']! as String;
      }
    } on FormatException {
      // Falls through to the generic message below.
    }
    return 'The PC refused the sync.';
  }

  static Map<String, Object?> _jsonObject(Uint8List body) {
    try {
      final Object? parsed = jsonDecode(utf8.decode(body));
      if (parsed is Map<String, Object?>) {
        return parsed;
      }
    } on FormatException {
      // Falls through.
    }
    throw const LanSyncFailure('That does not look like a Zen PC.');
  }

  /// Whether [value] decodes as a 32-byte key.
  static bool _isKey(String value) {
    try {
      return base64Decode(value).length == 32;
    } on FormatException {
      return false;
    }
  }
}

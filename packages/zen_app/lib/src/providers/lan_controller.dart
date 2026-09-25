/// §11.6.4, §11.8. The LAN server's lifecycle, and the pairing commands.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zen_domain/zen_domain.dart';
import 'package:zen_sync/zen_sync.dart';

import 'app_providers.dart';
import 'sync_providers.dart';

/// §11.8. What the Sync section shows for the LAN transport.
@immutable
final class LanState {
  /// Records the LAN transport's state.
  const LanState({
    this.listening = false,
    this.port,
    this.error,
    this.invitation,
    this.codeExpiresAt,
  });

  /// Desktop only: whether the server is up.
  final bool listening;

  /// Desktop only: the port it bound.
  final int? port;

  /// Why the server is not up, when it is not.
  final String? error;

  /// Desktop only: the pairing window currently open, if any.
  final LanPairingInvitation? invitation;

  /// When that window closes.
  final DateTime? codeExpiresAt;

  /// Whether a pairing window is open right now.
  bool get isPairing => invitation != null;
}

/// §11.6.4, §11.8. Starts and stops the desktop server, and runs pairing.
///
/// The asymmetry §11.6.4 specifies lives here and in `sync_providers.dart`, and
/// nowhere else: on Windows this owns a server and an mDNS registration, on
/// Android it owns neither and the screens that use it show the client half.
final class LanController extends Notifier<LanState> {
  Timer? _windowTimer;

  @override
  LanState build() {
    ref.onDispose(() => _windowTimer?.cancel());
    // SET-2: the server follows the setting, so switching LAN sync off stops
    // listening at once rather than at the next restart.
    ref.listen<AsyncValue<Settings>>(settingsProvider, (
      AsyncValue<Settings>? previous,
      AsyncValue<Settings> next,
    ) {
      final Settings? settings = next.value;
      if (settings != null) {
        unawaited(_applySettings(settings));
      }
    });
    return const LanState();
  }

  /// Brings the server up or down to match [settings].
  Future<void> _applySettings(Settings settings) async {
    final LanSyncServer? server = ref.read(lanSyncServerProvider);
    if (server == null) {
      return;
    }
    if (!settings.syncLanEnabled) {
      await _stop();
      return;
    }
    if (server.isRunning && server.boundPort == settings.syncLanPort) {
      return;
    }
    await start(settings.syncLanPort);
  }

  /// §11.6.4. Starts the desktop server on [port] and advertises it.
  Future<void> start(int port) async {
    final LanSyncServer? server = ref.read(lanSyncServerProvider);
    if (server == null) {
      return;
    }
    await server.start(port: port);
    if (server.isRunning) {
      final ReplicaRepository replicas = ref.read(replicaRepositoryProvider);
      // Advertising is best-effort by design: §11.6.4 makes manual host:port
      // entry mandatory precisely because mDNS cannot be relied on.
      await ref
          .read(lanRegistrationProvider)
          ?.register(
            port: server.boundPort!,
            replicaId: await replicas.replicaId(),
            deviceName: await replicas.deviceName(),
          );
    }
    state = LanState(
      listening: server.isRunning,
      port: server.boundPort,
      error: (await server.state()).error,
    );
  }

  Future<void> _stop() async {
    _windowTimer?.cancel();
    await ref.read(lanRegistrationProvider)?.unregister();
    await ref.read(lanSyncServerProvider)?.stop();
    state = const LanState();
  }

  /// §11.6.4 step 1. Opens a 5-minute pairing window and returns what to show.
  ///
  /// The invitation carries the host the *phone* must dial, which this device
  /// cannot know for certain — a machine has several addresses and only the
  /// phone's route decides which one works. The best local guess goes in the QR
  /// and the address is also shown in text, which is what the manual entry path
  /// is for.
  Future<LanPairingInvitation?> openPairingWindow() async {
    final LanSyncServer? server = ref.read(lanSyncServerProvider);
    if (server == null || !server.isRunning) {
      return null;
    }
    final ReplicaRepository replicas = ref.read(replicaRepositoryProvider);
    final PairingWindow window = server.openPairingWindow();
    final LanPairingInvitation invitation = LanPairingInvitation(
      host: await localAddress() ?? '127.0.0.1',
      port: server.boundPort!,
      code: window.code,
      replicaId: await replicas.replicaId(),
      deviceName: await replicas.deviceName(),
    );

    state = LanState(
      listening: true,
      port: server.boundPort,
      invitation: invitation,
      codeExpiresAt: window.expiresAt,
    );

    // The window closes itself in the model after five minutes; this only
    // stops the screen showing a code that no longer works.
    _windowTimer?.cancel();
    _windowTimer = Timer(LanPairing.window, closePairingWindow);
    return invitation;
  }

  /// Closes the pairing window.
  void closePairingWindow() {
    _windowTimer?.cancel();
    ref.read(lanSyncServerProvider)?.closePairingWindow();
    state = LanState(
      listening: state.listening,
      port: state.port,
      error: state.error,
    );
  }

  /// §11.6.4 step 2–4. The phone's side: confirm, pair, store.
  ///
  /// Returns null on success, or a message for the user. The *confirmation*
  /// §11.6.4 requires — showing the host and device name before the code is
  /// sent — belongs to the screen, because it is a decision the user makes;
  /// by the time this is called they have made it.
  Future<String?> pairWith({
    required String host,
    required int port,
    required String code,
  }) async {
    if (!isValidHost(host) || !isValidPort(port) || !isValidPairingCode(code)) {
      return 'Check the address and the six-digit code.';
    }
    final LanClient client = LanClient(log: ref.read(syncLoggerProvider));
    try {
      final ReplicaRepository replicas = ref.read(replicaRepositoryProvider);
      final LanPeer peer = await client.pair(
        host: host,
        port: port,
        code: code,
        replicaId: await replicas.replicaId(),
        deviceName: await replicas.deviceName(),
      );
      final SettingsRepository settings = ref.read(settingsRepositoryProvider);
      final Settings current = await settings.read();
      await settings.write(
        current.copyWith(
          syncLanEnabled: true,
          syncLanPeers: <LanPeer>[
            for (final LanPeer held in current.syncLanPeers)
              if (held.replicaId != peer.replicaId) held,
            peer,
          ],
        ),
      );
      return null;
    } on LanSyncFailure catch (failure) {
      return failure.message;
    } finally {
      client.close();
    }
  }

  /// §11.6.4. Asks a host whether it is a Zen PC, before any code is sent.
  ///
  /// This is what fills the confirmation the user sees on the manual-entry
  /// path: a device name they can check against the one on the PC's screen.
  Future<({LanHello? hello, String? problem})> greet(
    String host,
    int port,
  ) async {
    if (!isValidHost(host) || !isValidPort(port)) {
      return (hello: null, problem: 'Check the address and port.');
    }
    final LanClient client = LanClient(log: ref.read(syncLoggerProvider));
    try {
      return (hello: await client.hello(host, port), problem: null);
    } on LanSyncFailure catch (failure) {
      return (hello: null, problem: failure.message);
    } finally {
      client.close();
    }
  }

  /// §11.8. Forgets a paired device.
  ///
  /// One-sided by nature: the other device keeps a key that no longer opens
  /// anything, and its own list is where it is removed from. The Settings copy
  /// says so.
  Future<void> unpair(String replicaId) async {
    final SettingsRepository settings = ref.read(settingsRepositoryProvider);
    final Settings current = await settings.read();
    await settings.write(
      current.copyWith(
        syncLanPeers: <LanPeer>[
          for (final LanPeer peer in current.syncLanPeers)
            if (peer.replicaId != replicaId) peer,
        ],
      ),
    );
  }

  /// This machine's LAN address, for the QR and the text the user reads out.
  ///
  /// Loopback and link-local are skipped: neither is an address the phone can
  /// reach. When there are several — a laptop on Wi-Fi and Ethernet at once —
  /// the first is a guess, and the manual entry is the remedy.
  static Future<String?> localAddress() async {
    try {
      final List<NetworkInterface> interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final NetworkInterface interface in interfaces) {
        for (final InternetAddress address in interface.addresses) {
          if (!address.isLoopback && !address.address.startsWith('169.254.')) {
            return address.address;
          }
        }
      }
    } on Object catch (error) {
      debugPrint('[sync] LAN: could not read this PC\'s address ($error).');
    }
    return null;
  }
}

/// §11.8. The LAN transport's state and commands.
final NotifierProvider<LanController, LanState> lanControllerProvider =
    NotifierProvider<LanController, LanState>(LanController.new);

/// §11.6.4. The phone's `SyncTransport`.
// `prefer_initializing_formals` fires on every private field this class is
// constructed with: it suggests `this._settings` and friends, which Dart
// forbids, because a named parameter may not begin with an underscore. The
// orchestrator ignores it once for the same reason.
// ignore_for_file: prefer_initializing_formals
library;

import 'package:zen_domain/zen_domain.dart';

import '../snapshot/snapshot_envelope.dart';
import '../sync_log.dart';
import '../transport/sync_transport.dart';
import 'lan_client.dart';
import 'lan_peer_input.dart';
import 'lan_protocol.dart';
import 'peer_discovery.dart';

/// §11.6.4. Snapshots exchanged directly with a paired desktop.
///
/// **Only the phone registers this** (§11.6.4). The desktop runs `LanSyncServer`
/// and registers no transport, because it never fetches and never publishes over
/// LAN, and a transport that always reported "published" for a write that never
/// happened would be a status line that is falsely green.
///
/// The shape is a plain [SyncTransport] all the same: [fetchPeerSnapshots]
/// performs §11.6.4's one round trip and returns what came back, so §11.6.5
/// needs no special case for it.
final class LanSyncTransport implements SyncTransport {
  /// Creates the transport.
  LanSyncTransport({
    required SettingsRepository settings,
    required Clock clock,
    LanClient? client,
    PeerDiscovery discovery = const NoPeerDiscovery(),
    SyncLogger log = discardSyncLog,
  }) : _settings = settings,
       _clock = clock,
       _client = client ?? LanClient(log: log),
       _discovery = discovery,
       _log = log;

  /// §11.6.2. This transport's stable identifier.
  static const String transportId = 'lan';

  /// How long discovery is given before the pass gives up on it.
  ///
  /// Short, because it only runs when the remembered address has already
  /// failed, and the whole exchange sits inside the single-flight lock.
  static const Duration discoveryTimeout = Duration(seconds: 3);

  final SettingsRepository _settings;
  final Clock _clock;
  final LanClient _client;
  final PeerDiscovery _discovery;
  final SyncLogger _log;

  @override
  String get id => transportId;

  /// §11.6.2. Whether a sync is possible right now.
  ///
  /// Deliberately **does not probe the network**. A probe would cost a round
  /// trip before the round trip that follows it, and would turn one timeout
  /// into two inside the single-flight lock. What it can answer without the
  /// network is the question the user most often has — whether anything is
  /// paired at all — and an unreachable desktop surfaces from the fetch as an
  /// ordinary per-transport failure carrying §11.6.4's copy.
  @override
  Future<TransportAvailability> availability() async {
    final Settings settings = await _settings.read();
    return settings.syncLanPeers.isEmpty
        ? const TransportAvailability.unreachable('No devices paired yet.')
        : const TransportAvailability.reachable();
  }

  /// §11.6.4. The one round trip: post `C`, receive `S`.
  ///
  /// Every paired peer is tried. A peer that cannot be reached contributes
  /// nothing and is logged; the first failure's message is thrown only when
  /// *no* peer could be reached, so that one sleeping desktop does not hide a
  /// successful sync with another.
  @override
  Future<List<SnapshotEnvelope>> fetchPeerSnapshots(
    SnapshotEnvelope local,
  ) async {
    final Settings settings = await _settings.read();
    if (settings.syncLanPeers.isEmpty) {
      return const <SnapshotEnvelope>[];
    }

    // Discovery is resolved at most once per pass, however many peers need
    // it, and only after a remembered address has already failed.
    List<DiscoveredPeer>? discovered;
    final List<SnapshotEnvelope> peers = <SnapshotEnvelope>[];
    final List<LanPeer> reached = <LanPeer>[];
    LanSyncFailure? firstFailure;

    for (final LanPeer peer in settings.syncLanPeers) {
      // "The last successful address is remembered and tried first."
      final _Address? remembered =
          isValidHost(peer.host) && isValidPort(peer.port)
          ? _Address(peer.host, peer.port)
          : null;

      _Attempt attempt = await _tryAddress(peer, remembered, local);

      if (attempt.envelope == null) {
        discovered ??= await _discover();
        final _Address? found = _addressOf(discovered, peer.replicaId);
        if (found != null && found != remembered) {
          attempt = await _tryAddress(peer, found, local);
        }
      }

      final SnapshotEnvelope? envelope = attempt.envelope;
      if (envelope != null) {
        peers.add(envelope);
        reached.add(_remember(peer, attempt.address!));
      } else if (attempt.failure != null) {
        firstFailure ??= attempt.failure;
      }
    }

    await _rememberAddresses(reached);

    if (peers.isEmpty && firstFailure != null) {
      throw firstFailure;
    }
    return peers;
  }

  /// §11.6.5 step 7. A no-op: "the exchange in §11.6.4 already delivered it."
  ///
  /// The pass still records a `published` outcome for this transport, which is
  /// accurate — [fetchPeerSnapshots] posted this device's snapshot to every
  /// peer it reached. Writing again here would post it twice.
  @override
  Future<void> publish(SnapshotEnvelope envelope) async {}

  /// One exchange attempt against one address.
  ///
  /// A null [address] is the case where nothing is remembered yet and discovery
  /// has not run, which is a miss rather than a failure: there is no address to
  /// blame and nothing to tell the user beyond what discovery reports.
  Future<_Attempt> _tryAddress(
    LanPeer peer,
    _Address? address,
    SnapshotEnvelope local,
  ) async {
    if (address == null) {
      return const _Attempt(null, null, null);
    }
    try {
      return _Attempt(
        await _client.exchange(
          peer: peer,
          host: address.host,
          port: address.port,
          local: local,
          clock: _clock,
        ),
        address,
        null,
      );
    } on LanSyncFailure catch (error) {
      _log(
        'LAN sync: ${address.host}:${address.port} '
        '("${peer.deviceName}") — ${error.message}',
      );
      return _Attempt(null, address, error);
    }
  }

  Future<List<DiscoveredPeer>> _discover() async {
    try {
      return await _discovery.discover(discoveryTimeout);
    } on Object catch (error) {
      // "mDNS is unreliable on some networks." Discovery failing is the
      // expected case on plenty of them, and never a reason to fail a pass.
      _log('LAN sync: discovery found nothing ($error).');
      return const <DiscoveredPeer>[];
    }
  }

  static _Address? _addressOf(List<DiscoveredPeer> found, String replicaId) {
    for (final DiscoveredPeer peer in found) {
      if (peer.replicaId == replicaId &&
          isValidHost(peer.host) &&
          isValidPort(peer.port)) {
        return _Address(peer.host, peer.port);
      }
    }
    return null;
  }

  static LanPeer _remember(LanPeer peer, _Address address) => LanPeer(
    replicaId: peer.replicaId,
    deviceName: peer.deviceName,
    host: address.host,
    port: address.port,
    psk: peer.psk,
  );

  /// §11.6.4. "The last successful address is remembered and tried first."
  ///
  /// Written once per pass and only when something actually changed, so that a
  /// sync against an unmoved desktop does not write the settings row every
  /// fifteen minutes.
  Future<void> _rememberAddresses(List<LanPeer> reached) async {
    if (reached.isEmpty) {
      return;
    }
    final Settings current = await _settings.read();
    final Map<String, LanPeer> updates = <String, LanPeer>{
      for (final LanPeer peer in reached) peer.replicaId: peer,
    };
    final List<LanPeer> next = <LanPeer>[
      for (final LanPeer peer in current.syncLanPeers)
        updates[peer.replicaId] ?? peer,
    ];
    if (!_sameAddresses(current.syncLanPeers, next)) {
      await _settings.write(current.copyWith(syncLanPeers: next));
    }
  }

  static bool _sameAddresses(List<LanPeer> a, List<LanPeer> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i].host != b[i].host || a[i].port != b[i].port) {
        return false;
      }
    }
    return true;
  }
}

/// A host and port to try.
final class _Address {
  const _Address(this.host, this.port);

  final String host;
  final int port;

  @override
  bool operator ==(Object other) =>
      other is _Address && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);
}

/// The result of one exchange attempt.
final class _Attempt {
  const _Attempt(this.envelope, this.address, this.failure);

  /// The peer's snapshot, when the exchange succeeded.
  final SnapshotEnvelope? envelope;

  /// The address tried, or null when there was none to try.
  final _Address? address;

  /// Why it failed, when it did.
  final LanSyncFailure? failure;
}

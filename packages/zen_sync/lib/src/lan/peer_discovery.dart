/// §11.6.4. The mDNS port the phone browses through.
library;

import 'package:meta/meta.dart';

/// §11.6.4. One `_zen-sync._tcp` service seen on the network.
@immutable
final class DiscoveredPeer {
  /// Records a service found by discovery.
  const DiscoveredPeer({
    required this.replicaId,
    required this.deviceName,
    required this.host,
    required this.port,
  });

  /// The TXT record's `rid`.
  final String replicaId;

  /// The TXT record's `dn`.
  final String deviceName;

  /// The resolved address.
  final String host;

  /// The resolved port.
  final int port;

  @override
  String toString() => 'DiscoveredPeer($deviceName, $host:$port)';
}

/// §11.6.4. Browsing for `_zen-sync._tcp`.
///
/// A port, for the same reason `SnapshotDirectory` is one (D-M6-1): mDNS needs
/// a Flutter platform channel, which a pure Dart package cannot have, so
/// `zen_app` supplies the `nsd` implementation and everything here stays
/// headlessly testable (§11.13.1).
///
/// Discovery is the *fallback*, not the primary path. §11.6.4: "mDNS is
/// unreliable on some networks, so **a manual host:port entry is mandatory, not
/// optional**, and the last successful address is remembered and tried first."
abstract interface class PeerDiscovery {
  /// Browses for at most [timeout], returning whatever answered.
  ///
  /// Returning an empty list is ordinary — many networks block multicast — and
  /// is never treated as a failure. Throwing is permitted and is handled by the
  /// caller as "discovery found nothing".
  Future<List<DiscoveredPeer>> discover(Duration timeout);
}

/// The discovery used when the platform supplies none.
///
/// The transport works without discovery, because a paired peer's address is
/// remembered and a manual entry is always available. This is what that looks
/// like rather than a null check at every call site.
final class NoPeerDiscovery implements PeerDiscovery {
  /// Creates the no-op discovery.
  const NoPeerDiscovery();

  @override
  Future<List<DiscoveredPeer>> discover(Duration timeout) async =>
      const <DiscoveredPeer>[];
}

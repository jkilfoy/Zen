/// §11.6.4, §11.7. mDNS, behind `zen_sync`'s `PeerDiscovery` port.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:zen_sync/zen_sync.dart';

/// §11.6.4. Browses for `_zen-sync._tcp` with `package:nsd`.
///
/// Platform glue, so it lives here rather than in `zen_sync` — the same reason
/// `SafSnapshotDirectory` does (D-M6-1): mDNS needs a platform channel, which a
/// pure Dart package cannot have, and keeping it out leaves the transport
/// headlessly testable (§11.13.1).
///
/// **This is the fallback, never the only path.** §11.6.4: "mDNS is unreliable
/// on some networks, so **a manual host:port entry is mandatory, not
/// optional**, and the last successful address is remembered and tried first."
/// Everything here can therefore fail without the feature failing.
final class NsdPeerDiscovery implements PeerDiscovery {
  /// Creates the discovery.
  const NsdPeerDiscovery();

  @override
  Future<List<DiscoveredPeer>> discover(Duration timeout) async {
    final nsd.Discovery discovery = await nsd.startDiscovery(
      lanServiceType,
      // Resolving to an address matters: §11.6.4 notes that at `targetSdk` 37
      // `.local` resolution is blocked without `ACCESS_LOCAL_NETWORK`, and an
      // address we already hold needs no resolution.
      ipLookupType: nsd.IpLookupType.v4,
    );
    final List<DiscoveredPeer> found = <DiscoveredPeer>[];

    void onService(nsd.Service service, nsd.ServiceStatus status) {
      if (status != nsd.ServiceStatus.found) {
        return;
      }
      final DiscoveredPeer? peer = _toPeer(service);
      if (peer != null &&
          !found.any((DiscoveredPeer p) => p.replicaId == peer.replicaId)) {
        found.add(peer);
      }
    }

    discovery.addServiceListener(onService);
    try {
      await Future<void>.delayed(timeout);
    } finally {
      discovery.removeServiceListener(onService);
      // Never allowed to fail the browse: the caller has its results already,
      // and a discovery that cannot be stopped is a leak, not a sync failure.
      try {
        await nsd.stopDiscovery(discovery);
      } on Object catch (error) {
        debugPrint('[sync] LAN discovery: could not stop cleanly ($error).');
      }
    }
    return found;
  }

  /// Reads one service into a peer, or `null` if it is not one of ours.
  ///
  /// The TXT records and the address come off the network, so they are checked
  /// here exactly as the endpoints check their input: anything on this Wi-Fi
  /// can publish a `_zen-sync._tcp` service saying whatever it likes.
  static DiscoveredPeer? _toPeer(nsd.Service service) {
    final Map<String, Uint8List?> txt = service.txt ?? <String, Uint8List?>{};
    final String? replicaId = _text(txt[LanTxtKeys.replicaId]);
    final String? deviceName =
        LanPeerIdentity.parseDeviceName(_text(txt[LanTxtKeys.deviceName])) ??
        LanPeerIdentity.parseDeviceName(service.name);
    final int? port = service.port;

    // The resolved address is preferred over the host name: §11.6.4's note
    // about `targetSdk` 37 means a `.local` name may one day not resolve.
    final String? host =
        service.addresses?.firstOrNull?.address ?? service.host;

    if (replicaId == null ||
        deviceName == null ||
        host == null ||
        port == null ||
        !isValidHost(host) ||
        !isValidPort(port) ||
        !_looksLikeReplicaId(replicaId)) {
      return null;
    }
    if (_text(txt[LanTxtKeys.protocolVersion]) != '$lanProtocolVersion') {
      // A peer speaking another protocol is not a peer this build can sync
      // with, and dialling it would only produce a refusal a round trip later.
      return null;
    }

    return DiscoveredPeer(
      replicaId: replicaId,
      deviceName: deviceName,
      host: host,
      port: port,
    );
  }

  static String? _text(Uint8List? value) {
    if (value == null || value.isEmpty || value.length > 128) {
      return null;
    }
    try {
      return utf8.decode(value);
    } on FormatException {
      return null;
    }
  }

  static bool _looksLikeReplicaId(String value) =>
      LanPeerIdentity.parse(replicaId: value, deviceName: 'x') != null;
}

/// §11.6.4. The desktop's mDNS registration: `_zen-sync._tcp` plus TXT records.
///
/// "The desktop registers `_zen-sync._tcp` on the default port **51789**
/// (configurable) with TXT records `rid` (replicaId), `pv` (protocol version),
/// `dn` (device name)."
///
/// Registration failing is not a failure of LAN sync. Plenty of Windows
/// machines have no Bonjour responder, and §11.6.4 makes the manual host:port
/// entry mandatory precisely so that this can fail and the feature still work.
final class NsdServiceRegistration {
  /// Creates an unregistered registration.
  NsdServiceRegistration();

  nsd.Registration? _registration;

  /// Whether the service is currently advertised.
  bool get isAdvertised => _registration != null;

  /// Advertises this device on [port].
  Future<void> register({
    required int port,
    required String replicaId,
    required String deviceName,
  }) async {
    await unregister();
    try {
      _registration = await nsd.register(
        nsd.Service(
          name: deviceName,
          type: lanServiceType,
          port: port,
          txt: <String, Uint8List?>{
            LanTxtKeys.replicaId: Uint8List.fromList(utf8.encode(replicaId)),
            LanTxtKeys.protocolVersion: Uint8List.fromList(
              utf8.encode('$lanProtocolVersion'),
            ),
            LanTxtKeys.deviceName: Uint8List.fromList(utf8.encode(deviceName)),
          },
        ),
      );
    } on Object catch (error) {
      debugPrint(
        '[sync] LAN discovery: this PC could not advertise itself ($error). '
        'Pair with the host and port shown on the pairing screen.',
      );
    }
  }

  /// Stops advertising, if it started.
  Future<void> unregister() async {
    final nsd.Registration? registration = _registration;
    _registration = null;
    if (registration != null) {
      try {
        await nsd.unregister(registration);
      } on Object catch (error) {
        debugPrint('[sync] LAN discovery: could not unregister ($error).');
      }
    }
  }
}

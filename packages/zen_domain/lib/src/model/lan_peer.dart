/// §11.6.4, §11.8. A device this replica has paired with over the LAN.
library;

import 'package:meta/meta.dart';

/// §11.8. One entry of `syncLanPeers`: `{replicaId, deviceName, host, port, psk}`.
///
/// Declared in M6 because §11.8's settings table is M6's, and the settings
/// record cannot be written without a type for this column. **Nothing in M6
/// creates one** — pairing is §11.6.4 and belongs to M7, which is also when the
/// question of where [psk] should live gets decided:
///
/// > *Open for M7:* §11.8 stores `syncLanPeers`, including each `psk`, in the
/// > settings key-value table of an unencrypted SQLite file. M6 defines that
/// > storage but puts nothing secret in it; M7 is the first milestone that
/// > does, and should decide then whether the key belongs in platform secure
/// > storage instead.
@immutable
final class LanPeer {
  /// Records a paired device.
  const LanPeer({
    required this.replicaId,
    required this.deviceName,
    required this.host,
    required this.port,
    required this.psk,
  });

  /// §11.5.1. The peer's replicaId, as its `/hello` reports it.
  final String replicaId;

  /// §11.6.4. The peer's device name, shown in the paired-device list (§11.8).
  final String deviceName;

  /// §11.6.4. The last address that worked. "The last successful address is
  /// remembered and tried first."
  final String host;

  /// §11.6.4. The peer's port; the desktop's default is 51789.
  final int port;

  /// §11.6.4. The 32-byte pre-shared key, base64-encoded.
  ///
  /// Excluded from [toString] on purpose: a secret that reaches a log is a
  /// secret that has leaked, and `toString` is what log lines call.
  final String psk;

  @override
  bool operator ==(Object other) =>
      other is LanPeer &&
      other.replicaId == replicaId &&
      other.deviceName == deviceName &&
      other.host == host &&
      other.port == port &&
      other.psk == psk;

  @override
  int get hashCode => Object.hash(replicaId, deviceName, host, port, psk);

  @override
  String toString() => 'LanPeer($deviceName, $host:$port)';
}

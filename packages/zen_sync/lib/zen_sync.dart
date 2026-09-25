/// Zen's sync layer: the snapshot format of §11.6.1, the transports of §11.6.2
/// and §11.6.3, the pre-merge backups of §11.6.6 and the orchestrator of
/// §11.6.5.
///
/// §11.1. `zen_sync` depends on `zen_domain` and nothing depends on it but
/// `zen_app`. It holds no merge logic of its own: §9.1 puts `ReplicaSnapshot`,
/// `MergeResult` and `MergeStrategy` in `zen_domain`, and this package owns
/// "only the **envelope and the codec**".
///
/// What is worth knowing before reading it:
///
/// * **The merge never sees an envelope.** `SnapshotEnvelope` carries
///   `formatVersion`, `deviceName`, `generatedAt` and `appVersion`; the
///   orchestrator unwraps before merging. Transports deal in envelopes because
///   §11.6.5 step 3 de-duplicates peers on `generatedAt` (§11.6.2).
/// * **Settings never travel** (MERGE-3). They are per replica, and a snapshot
///   carrying them would quietly overwrite the other device's preferences.
///   There is a test for their absence.
/// * **A peer snapshot is all-or-nothing** (§11.6.1). One unreadable record
///   skips the whole file, because a sync that appears to succeed while
///   carrying less than the peer holds is the quieter and therefore worse
///   failure.
/// * **Nothing aborts a pass.** A failing transport, an unwritable backup and
///   an unrecordable `lastSyncAt` are each caught, recorded and logged
///   (§11.6.5, NFR-1).
/// * **The LAN endpoints are hostile input** (§11.6.4). `/hello`, `/pair` and
///   `/sync` accept bytes from anyone on the Wi-Fi: bodies are capped before
///   they are buffered, the pairing code is compared in constant time, every
///   peer-supplied string is validated before it is stored or shown, and the
///   `/sync` payload is §11.6.1's document, so the codec's all-or-nothing
///   parsing guards the merge without this layer knowing the format.
/// * **Only the phone registers a LAN transport** (§11.6.4). The desktop runs
///   `LanSyncServer` and hands inbound snapshots to the *same* entry point
///   `"Import snapshot…"` uses, rather than re-implementing the merge.
/// * **Platform differences live in `SnapshotDirectory`.** Windows gets an
///   atomic rename; Android SAF cannot, and does delete-then-rename instead —
///   §11.6.3 states both and explains what the difference costs.
library;

export 'src/backup/backup_store.dart';
export 'src/lan/lan_client.dart';
export 'src/lan/lan_crypto.dart';
export 'src/lan/lan_peer_input.dart';
export 'src/lan/lan_protocol.dart';
export 'src/lan/lan_server.dart';
export 'src/lan/lan_transport.dart';
export 'src/lan/peer_discovery.dart';
export 'src/orchestrator.dart';
export 'src/snapshot/snapshot_codec.dart';
export 'src/snapshot/snapshot_envelope.dart';
export 'src/snapshot/snapshot_format_failure.dart';
export 'src/sync_log.dart';
export 'src/sync_outcome.dart';
export 'src/transport/file_transport.dart';
export 'src/transport/io_snapshot_directory.dart';
export 'src/transport/snapshot_directory.dart';
export 'src/transport/sync_transport.dart';

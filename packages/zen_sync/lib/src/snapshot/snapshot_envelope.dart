/// §9.1, §11.6.1, §11.6.2. The wire envelope around a [ReplicaSnapshot].
library;

import 'package:meta/meta.dart';
import 'package:zen_domain/zen_domain.dart';

/// §9.1, §11.6.1. A [ReplicaSnapshot] plus the wire metadata §9.1 keeps out of
/// the domain type.
///
/// "`zen_sync` owns only the **envelope and the codec**: `formatVersion`,
/// `deviceName`, `generatedAt`, `appVersion`, and the JSON encoding of the
/// whole thing. It wraps a `ReplicaSnapshot`; it is not one. A merge never sees
/// the envelope, which is why the merge can be tested with no serialization at
/// all."
///
/// §11.6.2 makes this the currency of [SyncTransport] rather than the bare
/// snapshot, because §11.6.5 step 3 de-duplicates peers on [generatedAt] and
/// the orchestrator would otherwise have no way to read it. The orchestrator
/// unwraps before merging, so the merge still sees only domain types.
@immutable
final class SnapshotEnvelope {
  /// Wraps [snapshot] with the metadata of §11.6.1.
  const SnapshotEnvelope({
    required this.replicaId,
    required this.deviceName,
    required this.generatedAt,
    required this.appVersion,
    required this.snapshot,
    this.formatVersion = currentFormatVersion,
  });

  /// §11.6.1. The format this package writes, and the highest it can read.
  ///
  /// "`formatVersion` is checked on read; an unknown higher version is refused
  /// with a clear message rather than parsed optimistically."
  static const int currentFormatVersion = 1;

  /// §11.6.1. The version of the snapshot format this envelope is written in.
  final int formatVersion;

  /// §11.5.1, §11.6.1. The replica that generated the snapshot.
  ///
  /// §11.6.3 makes this — the *body's* value, not the filename's — the
  /// authoritative identity of a snapshot file.
  final String replicaId;

  /// §11.6.1. The generating device's name, for the merge report and the
  /// per-transport status line. Never read by the merge.
  final String deviceName;

  /// §11.6.1. When the snapshot was taken, UTC at millisecond precision (§3).
  ///
  /// §11.6.5 step 3 compares this to discard the staler of two copies of one
  /// replica arriving over different transports.
  final DateTime generatedAt;

  /// §11.6.1. The app version that generated it, for diagnostics.
  final String appVersion;

  /// §9.1. The dataset itself: the only part a merge sees.
  final ReplicaSnapshot snapshot;

  /// Returns a copy with [generatedAt] replaced.
  ///
  /// §11.6.5 step 7 rebuilds an envelope around the post-merge dataset; this is
  /// how a re-stamped copy is made without restating every other field.
  SnapshotEnvelope withGeneratedAt(DateTime instant) => SnapshotEnvelope(
    formatVersion: formatVersion,
    replicaId: replicaId,
    deviceName: deviceName,
    generatedAt: instant,
    appVersion: appVersion,
    snapshot: snapshot,
  );

  @override
  bool operator ==(Object other) =>
      other is SnapshotEnvelope &&
      other.formatVersion == formatVersion &&
      other.replicaId == replicaId &&
      other.deviceName == deviceName &&
      other.generatedAt == generatedAt &&
      other.appVersion == appVersion &&
      other.snapshot == snapshot;

  @override
  int get hashCode => Object.hash(
    formatVersion,
    replicaId,
    deviceName,
    generatedAt,
    appVersion,
    snapshot,
  );

  @override
  String toString() =>
      'SnapshotEnvelope(v$formatVersion, $replicaId "$deviceName", '
      '$generatedAt, $snapshot)';
}

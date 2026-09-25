/// §11.6.5 step 8. What one sync pass did, per transport and overall.
library;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:zen_domain/zen_domain.dart';

import 'backup/backup_store.dart';

const ListEquality<Object?> _listEquality = ListEquality<Object?>();

/// §11.6.5 step 3. How a transport's fetch went.
enum SyncFetchStatus {
  /// `availability()` reported unreachable, so no fetch was attempted
  /// (§11.6.5 step 3). Ordinary, not a failure: the folder is on a drive that
  /// is not mounted, or the SAF grant was revoked.
  unavailable,

  /// Peers were fetched — possibly none, which is the ordinary first-run state.
  fetched,

  /// The fetch threw. §11.6.5 step 3: the transport "contributes nothing and is
  /// recorded as a per-transport status. **It MUST NOT abort the pass**".
  failed,
}

/// §11.6.5 step 7. How a transport's publish went.
enum SyncPublishStatus {
  /// The snapshot was written.
  published,

  /// Skipped because the content was unchanged (§11.6.5 step 7).
  unchanged,

  /// The publish threw, and was recorded rather than aborting the pass.
  failed,
}

/// §11.6.5 step 8. One transport's part of a pass.
@immutable
final class TransportOutcome {
  /// Records what [transportId] did.
  const TransportOutcome({
    required this.transportId,
    required this.fetch,
    required this.publish,
    this.peersFetched = 0,
    this.reason = '',
  });

  /// The [SyncTransport.id] this describes.
  final String transportId;

  /// How the fetch went (§11.6.5 step 3).
  final SyncFetchStatus fetch;

  /// How the publish went (§11.6.5 step 7).
  final SyncPublishStatus publish;

  /// How many peer snapshots this transport contributed, **before**
  /// cross-transport de-duplication.
  final int peersFetched;

  /// Why, when something went wrong or was skipped. Shown in the Settings
  /// status line; empty when there is nothing to explain.
  final String reason;

  /// Whether anything about this transport is worth telling the user.
  bool get isHealthy =>
      fetch != SyncFetchStatus.failed && publish != SyncPublishStatus.failed;

  @override
  bool operator ==(Object other) =>
      other is TransportOutcome &&
      other.transportId == transportId &&
      other.fetch == fetch &&
      other.publish == publish &&
      other.peersFetched == peersFetched &&
      other.reason == reason;

  @override
  int get hashCode =>
      Object.hash(transportId, fetch, publish, peersFetched, reason);

  @override
  String toString() =>
      'TransportOutcome($transportId, fetch: ${fetch.name}, '
      'publish: ${publish.name}, peers: $peersFetched)';
}

/// §11.6.5 step 8. The result of one sync pass.
///
/// Recorded alongside `lastSyncAt` and rendered in the Settings `"Sync"`
/// section (§11.8). A pass "fails" only in the sense that individual transports
/// may have failed — the pass itself always completes, because §11.6.5 forbids
/// any single transport from aborting it and NFR-1 forbids a sync failure from
/// getting in the user's way.
@immutable
final class SyncOutcome {
  /// Records a completed pass.
  SyncOutcome({
    required this.finishedAt,
    required List<TransportOutcome> transports,
    this.report,
    this.backup,
    this.peersMerged = 0,
    this.mergeFailure,
  }) : transports = List<TransportOutcome>.unmodifiable(transports);

  /// When the pass finished, UTC. This is what `lastSyncAt` records (§11.8).
  final DateTime finishedAt;

  /// One entry per enabled transport, in the order they were tried.
  final List<TransportOutcome> transports;

  /// §9.3 step 7. The merge report, or `null` when no merge ran because no
  /// peers were found — the ordinary first-run case, which §11.6.5 step 3
  /// requires to proceed to the publish anyway.
  final MergeReport? report;

  /// §11.6.6. The pre-merge backup written, or `null` when none was — either
  /// because no merge ran, or because the content duplicated the newest
  /// existing backup.
  final BackupEntry? backup;

  /// How many distinct peer replicas went into the merge, after
  /// cross-transport de-duplication (§11.6.5 step 3).
  final int peersMerged;

  /// Why the merge could not be applied, or `null` if it was.
  ///
  /// `replaceAll` is one transaction (STORE-3), so a merge that fails here
  /// leaves the device holding exactly what it held before — which is why the
  /// pass still publishes, and publishes the *pre-merge* dataset. Non-null
  /// means the merge produced something the schema refused, which is a defect
  /// in the merge rather than a condition to live with.
  final String? mergeFailure;

  /// Whether a merge ran at all.
  bool get merged => report != null;

  /// Whether every enabled transport did its job and the merge applied.
  bool get isHealthy =>
      mergeFailure == null &&
      transports.every((TransportOutcome t) => t.isHealthy);

  /// Whether this device is now visible to its peers over at least one
  /// transport.
  ///
  /// The distinction §11.6.5 step 3 turns on: a pass that merges nothing is
  /// still a success if it published, because "publishing is the only thing
  /// that makes this device visible to the others".
  bool get published => transports.any(
    (TransportOutcome t) => t.publish != SyncPublishStatus.failed,
  );

  @override
  bool operator ==(Object other) =>
      other is SyncOutcome &&
      other.finishedAt == finishedAt &&
      _listEquality.equals(other.transports, transports) &&
      other.report == report &&
      other.backup == backup &&
      other.peersMerged == peersMerged &&
      other.mergeFailure == mergeFailure;

  @override
  int get hashCode => Object.hash(
    finishedAt,
    _listEquality.hash(transports),
    report,
    backup,
    peersMerged,
    mergeFailure,
  );

  @override
  String toString() =>
      'SyncOutcome($finishedAt, ${transports.length} transports, '
      '$peersMerged peers, merged: $merged)';
}

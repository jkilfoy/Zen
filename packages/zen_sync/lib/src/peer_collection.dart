/// §11.6.5 step 3. Gathering peer snapshots from every enabled transport.
///
/// Split out of `orchestrator.dart` for §11.11's "files stay under roughly 400
/// lines". Step 3 is the one step of the pass with substantial logic of its own
/// — availability, per-transport failure isolation, and cross-transport
/// de-duplication — so it is also the natural seam.
library;

import 'snapshot/snapshot_envelope.dart';
import 'sync_log.dart';
import 'sync_outcome.dart';
import 'transport/sync_transport.dart';

/// §11.6.5 step 3. One transport's fetch result.
///
/// Carried from step 3 to step 7 so that a single `TransportOutcome` can
/// describe both halves of what a transport did.
final class TransportFetch {
  /// Records that a transport finished with [status], contributing [peers].
  const TransportFetch(this.status, this.peers, this.reason);

  /// How the fetch went.
  final SyncFetchStatus status;

  /// How many peer snapshots it contributed, before de-duplication.
  final int peers;

  /// Why, when something went wrong or was skipped. Empty when there is
  /// nothing to explain.
  final String reason;
}

/// §11.6.5 step 3's output: the de-duplicated peers, and what each transport
/// did on the way.
final class PeerCollection {
  /// Wraps [peers] and the per-transport [fetches] that produced them.
  const PeerCollection(this.peers, this.fetches);

  /// Every distinct peer replica, one envelope each, ordered by `replicaId`.
  final List<SnapshotEnvelope> peers;

  /// What each transport did, keyed by [SyncTransport.id].
  final Map<String, TransportFetch> fetches;
}

/// §11.6.5 step 3. Fetches from every enabled, reachable transport.
///
/// [extraPeers] are treated as peers alongside whatever the transports return,
/// which is how `"Import snapshot…"` joins the ordinary pass (§11.8). They are
/// deliberately **not** filtered by [replicaId]: a snapshot this device exported
/// earlier is a legitimate thing to import (D-M6-9).
Future<PeerCollection> collectPeers({
  required List<SyncTransport> transports,
  required String replicaId,
  required List<SnapshotEnvelope> extraPeers,
  required SyncLogger log,
}) async {
  final Map<String, TransportFetch> fetches = <String, TransportFetch>{};
  final List<SnapshotEnvelope> all = <SnapshotEnvelope>[...extraPeers];

  for (final SyncTransport transport in transports) {
    final TransportAvailability availability;
    try {
      availability = await transport.availability();
    } on Object catch (error) {
      fetches[transport.id] = TransportFetch(
        SyncFetchStatus.failed,
        0,
        '$error',
      );
      log('Sync (${transport.id}): availability check failed — $error.');
      continue;
    }
    if (!availability.reachable) {
      fetches[transport.id] = TransportFetch(
        SyncFetchStatus.unavailable,
        0,
        availability.reason,
      );
      continue;
    }
    try {
      final List<SnapshotEnvelope> peers = await transport.fetchPeerSnapshots();
      // A transport that hands back our own snapshot would put this device in
      // its own merge report as a peer. Harmless to merge — the merge is
      // idempotent — but misleading, and cheap to exclude here so that no
      // future transport has to remember.
      final List<SnapshotEnvelope> foreign = peers
          .where((SnapshotEnvelope e) => e.replicaId != replicaId)
          .toList(growable: false);
      fetches[transport.id] = TransportFetch(
        SyncFetchStatus.fetched,
        foreign.length,
        '',
      );
      all.addAll(foreign);
    } on Object catch (error) {
      // "A transport that fails — folder revoked, desktop not running, Wi-Fi
      // elsewhere — contributes nothing and is recorded as a per-transport
      // status. **It MUST NOT abort the pass**; the other transport's peers are
      // still merged."
      fetches[transport.id] = TransportFetch(
        SyncFetchStatus.failed,
        0,
        '$error',
      );
      log('Sync (${transport.id}): could not fetch peers — $error.');
    }
  }

  return PeerCollection(deduplicatePeers(all), fetches);
}

/// §11.6.5 step 3. "If two transports return snapshots for the **same**
/// `replicaId`, keep only the one with the later `generatedAt`."
///
/// "The merge would reconcile duplicates correctly anyway, but discarding the
/// stale copy keeps the merge report readable." Sorted by `replicaId` at the
/// end so the merge's inputs are in a reproducible order — which the merge
/// itself does not need (MERGE-2), but a failing seed in the convergence
/// simulation very much does.
List<SnapshotEnvelope> deduplicatePeers(List<SnapshotEnvelope> peers) {
  final Map<String, SnapshotEnvelope> newest = <String, SnapshotEnvelope>{};
  for (final SnapshotEnvelope peer in peers) {
    final SnapshotEnvelope? held = newest[peer.replicaId];
    if (held == null || peer.generatedAt.isAfter(held.generatedAt)) {
      newest[peer.replicaId] = peer;
    }
  }
  return newest.values.toList(growable: false)..sort(
    (SnapshotEnvelope a, SnapshotEnvelope b) =>
        a.replicaId.compareTo(b.replicaId),
  );
}

/// §11.6.2. The seam every sync transport implements.
library;

import 'package:meta/meta.dart';

import '../snapshot/snapshot_envelope.dart';

/// §11.6.2. One way snapshots travel between replicas.
///
/// Two implementations exist: `FileSnapshotTransport` (§11.6.3, M6) and
/// `LanSyncTransport` (§11.6.4, M7). §11.6.5 runs **all enabled transports
/// together in a single pass** — the merge is n-ary (MERGE-1), so peers from
/// different transports are simply more inputs to one merge. Nothing in the
/// orchestrator may special-case a transport by [id].
///
/// **Transports deal in envelopes, the merge deals in snapshots** (§11.6.2).
/// [fetchPeerSnapshots] returns [SnapshotEnvelope]s because §11.6.5 step 3
/// de-duplicates peers on `generatedAt`, which §9.1 deliberately keeps out of
/// `ReplicaSnapshot`; the orchestrator unwraps before merging.
abstract interface class SyncTransport {
  /// §11.6.2. A stable identifier — `'file'` or `'lan'`.
  ///
  /// Used to key the per-transport outcomes of §11.6.5 step 8 and to name the
  /// transport in the Settings status line, never to branch on.
  String get id;

  /// §11.6.2. Whether a sync is possible right now.
  ///
  /// §11.6.5 step 3 skips a transport that reports unreachable when *fetching*.
  /// Step 7 publishes regardless, because attempting the write is how a
  /// transport discovers it is usable.
  Future<TransportAvailability> availability();

  /// §11.6.2. Every peer snapshot this transport can currently see.
  ///
  /// Excludes this replica's own (§11.6.3). May return an empty list, which is
  /// the ordinary first-run state and not a failure. Throwing is permitted and
  /// is handled by §11.6.5 step 3: the transport contributes nothing and is
  /// recorded as a per-transport status, and **the pass continues**.
  ///
  /// [local] is this replica's snapshot as step 2 captured it. "A pull-only
  /// transport ignores it; the LAN transport must send it to receive the peer's
  /// in one round trip (§11.6.4). Passing it in rather than letting a transport
  /// build its own keeps a single capture per pass — two captures would let an
  /// edit between them make the two ends merge different inputs."
  ///
  /// `FileSnapshotTransport` is the pull-only case and ignores it; nothing in a
  /// directory needs to be told what this device holds.
  Future<List<SnapshotEnvelope>> fetchPeerSnapshots(SnapshotEnvelope local);

  /// §11.6.2, §11.6.5 step 7. Makes [envelope] visible to peers.
  ///
  /// Implementations SHOULD skip the write when the content is unchanged
  /// (§11.6.5 step 7) — comparing the `ReplicaSnapshot`, not the envelope,
  /// whose `generatedAt` differs on every pass.
  Future<void> publish(SnapshotEnvelope envelope);
}

/// §11.6.2. Whether a sync is possible right now, for the UI and the
/// per-transport status line.
///
/// "Two fields and no other states." A transport is reachable or it is not, and
/// when it is not the user is told why in words they can act on.
@immutable
final class TransportAvailability {
  /// Constructs an availability with an explicit [reachable] and [reason].
  const TransportAvailability({required this.reachable, required this.reason});

  /// The transport is usable. [reason] is empty.
  const TransportAvailability.reachable() : reachable = true, reason = '';

  /// The transport is not usable, because of [reason].
  const TransportAvailability.unreachable(this.reason) : reachable = false;

  /// Whether a sync can proceed over this transport.
  final bool reachable;

  /// Human-readable, shown to the user when [reachable] is false — §11.6.3's
  /// `"sync folder not available"`, for instance. Empty when reachable.
  final String reason;

  @override
  bool operator ==(Object other) =>
      other is TransportAvailability &&
      other.reachable == reachable &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(reachable, reason);

  @override
  String toString() =>
      reachable ? 'TransportAvailability(reachable)' : 'unreachable: $reason';
}

/// §9.1, MERGE-1. The seam that lets the merge rule be replaced.
library;

import 'replica_snapshot.dart';

/// §9.1, MERGE-1. Combines the datasets of two or more replicas into one.
///
/// Implementations MUST be **pure and side-effect-free**: no IO, no clock, no
/// event log. They MUST also be **deterministic** (MERGE-2) — the same inputs
/// in any order produce the same output, which is what lets two replicas run
/// the merge independently and reach identical results.
///
/// Determinism means the result is a function of *content alone*. In
/// particular an implementation must not read [ReplicaSnapshot.replicaId], and
/// must not let the order of `inputs`, or of the lists inside a snapshot,
/// reach the output (MERGE-3A).
///
/// The strategy is chosen through dependency injection (§11.1). The MVP ships
/// `NameUnionMergeStrategy` (§9.3); the event log HIST-2 keeps exists so that a
/// better strategy can be written later without changing this interface.
abstract interface class MergeStrategy {
  /// Merges [inputs] into one dataset.
  ///
  /// [inputs] may be empty, which yields an empty result, and may hold a
  /// single snapshot, which normalizes it: tombstoned Ideas are dropped and the
  /// output is canonically ordered.
  MergeResult merge(List<ReplicaSnapshot> inputs);
}

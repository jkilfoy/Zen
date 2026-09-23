/// §9.1, MERGE-1. The input and output types of a merge.
///
/// §11.1: both are `zen_domain` types. They hold domain entities and nothing
/// else — no wire metadata, no JSON. `zen_sync` owns the envelope and the codec
/// (§11.6.1); it *wraps* a [ReplicaSnapshot] rather than being one, which is
/// why the merge can be tested with no serialization at all.
library;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../model/idea.dart';
import '../model/task.dart';
import '../model/tombstone.dart';
import 'merge_report.dart';

const ListEquality<Object?> _listEquality = ListEquality<Object?>();

/// §9.1, MERGE-1. One replica's dataset as a merge sees it.
///
/// Settings are absent by design: they are per replica and never merged
/// (MERGE-3).
///
/// [ideas], [tasks] and [tombstones] are **sets**, not sequences (MERGE-3A).
/// The order they are given in carries no meaning and a merge must not depend
/// on it.
@immutable
final class ReplicaSnapshot {
  /// Wraps one replica's Ideas, Tasks and Idea tombstones.
  ReplicaSnapshot({
    required this.replicaId,
    List<Idea> ideas = const <Idea>[],
    List<Task> tasks = const <Task>[],
    List<IdeaTombstone> tombstones = const <IdeaTombstone>[],
  }) : ideas = List<Idea>.unmodifiable(ideas),
       tasks = List<Task>.unmodifiable(tasks),
       tombstones = List<IdeaTombstone>.unmodifiable(tombstones);

  /// §11.5.1. The originating replica's id.
  ///
  /// Carried for diagnostics and for `zen_sync`'s bookkeeping. **The merge
  /// never reads it**: MERGE-2 requires the result to be a function of content
  /// alone, so a rule that consulted the replica an Item arrived from would
  /// make two replicas merging the same inputs disagree.
  final String replicaId;

  /// §3.2. This replica's live Ideas. Every one of them is active (§2).
  final List<Idea> ideas;

  /// §3.3. This replica's Tasks, including archived and soft-deleted ones.
  final List<Task> tasks;

  /// DEL-3. This replica's Idea tombstones.
  final List<IdeaTombstone> tombstones;

  @override
  bool operator ==(Object other) =>
      other is ReplicaSnapshot &&
      other.replicaId == replicaId &&
      _listEquality.equals(other.ideas, ideas) &&
      _listEquality.equals(other.tasks, tasks) &&
      _listEquality.equals(other.tombstones, tombstones);

  @override
  int get hashCode => Object.hash(
    replicaId,
    _listEquality.hash(ideas),
    _listEquality.hash(tasks),
    _listEquality.hash(tombstones),
  );

  @override
  String toString() =>
      'ReplicaSnapshot($replicaId, ${ideas.length} ideas, '
      '${tasks.length} tasks, ${tombstones.length} tombstones)';
}

/// §9.1, MERGE-1. The result of merging a set of [ReplicaSnapshot]s.
///
/// §9.3 step 8: [ideas], [tasks] and [tombstones] are emitted **sorted
/// ascending by `id`**. They are sets (MERGE-3A), so sorting gives the result a
/// canonical form — which is what lets AC-19 compare two merges field for
/// field. A Task's subtasks and an Item's tags are sequences and keep the order
/// steps 4 and 5 give them.
@immutable
final class MergeResult {
  /// Wraps the merged dataset and the report describing how it was reached.
  MergeResult({
    required List<Idea> ideas,
    required List<Task> tasks,
    required List<IdeaTombstone> tombstones,
    required this.report,
  }) : ideas = List<Idea>.unmodifiable(ideas),
       tasks = List<Task>.unmodifiable(tasks),
       tombstones = List<IdeaTombstone>.unmodifiable(tombstones);

  /// The merged Ideas, sorted by `id` (§9.3 step 8).
  final List<Idea> ideas;

  /// The merged Tasks, sorted by `id` (§9.3 step 8).
  final List<Task> tasks;

  /// The reduced tombstone set, sorted by `id` (§9.3 steps 1 and 8).
  final List<IdeaTombstone> tombstones;

  /// §9.3 step 7. What was merged and what had to be repaired.
  final MergeReport report;

  /// Returns this result as a snapshot, so that a merged dataset can be fed
  /// back into a merge.
  ///
  /// This is how §11.12's idempotence property is expressed:
  /// `merge([result.asSnapshot(id)]) == result`. [replicaId] is arbitrary,
  /// because the merge never reads it.
  ReplicaSnapshot asSnapshot(String replicaId) => ReplicaSnapshot(
    replicaId: replicaId,
    ideas: ideas,
    tasks: tasks,
    tombstones: tombstones,
  );

  @override
  bool operator ==(Object other) =>
      other is MergeResult &&
      _listEquality.equals(other.ideas, ideas) &&
      _listEquality.equals(other.tasks, tasks) &&
      _listEquality.equals(other.tombstones, tombstones) &&
      other.report == report;

  @override
  int get hashCode => Object.hash(
    _listEquality.hash(ideas),
    _listEquality.hash(tasks),
    _listEquality.hash(tombstones),
    report,
  );

  @override
  String toString() =>
      'MergeResult(${ideas.length} ideas, ${tasks.length} tasks, '
      '${tombstones.length} tombstones, $report)';
}

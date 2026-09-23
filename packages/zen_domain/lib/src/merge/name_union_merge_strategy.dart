/// §9.3. The MVP merge rule.
library;

import 'package:collection/collection.dart';

import '../model/enums.dart';
import '../model/idea.dart';
import '../model/subtask.dart';
import '../model/task.dart';
import '../model/tombstone.dart';
import 'conflict_components.dart';
import 'field_resolution.dart';
import 'merge_report.dart';
import 'merge_strategy.dart';
import 'record_order.dart';
import 'replica_snapshot.dart';
import 'subtask_merge.dart';

/// §9.3, §11.4.5. The MVP merge: union everything, resolve conflicts field by
/// field, then repair whatever that broke.
///
/// Pure, with no IO and no clock — every instant in the output is one that came
/// in. Deterministic (MERGE-2): the result is a function of content alone, so
/// two replicas merging the same snapshots reach byte-identical datasets. That
/// is what makes sync converge instead of oscillating.
///
/// The steps below are numbered as §9.3 numbers them, and each private method
/// names the step it implements. Its accepted limitations are §9.4's; the one
/// that bites hardest is that `Done`, `isDeleted` and `isArchived` are sticky,
/// so an undo is reverted by a peer that has not seen it.
final class NameUnionMergeStrategy implements MergeStrategy {
  /// The strategy is stateless, so one instance serves the whole app.
  const NameUnionMergeStrategy();

  @override
  MergeResult merge(List<ReplicaSnapshot> inputs) {
    // Step 1. Tombstones first.
    final List<IdeaTombstone> tombstones = _reduceTombstones(inputs);
    final Set<String> tombstonedIds = tombstones
        .map((IdeaTombstone t) => t.id)
        .toSet();

    // Step 2. Union, less the Ideas the tombstones bury.
    final List<Idea> ideas = <Idea>[
      for (final ReplicaSnapshot input in inputs)
        for (final Idea idea in input.ideas)
          if (!tombstonedIds.contains(idea.id)) idea,
    ];
    final List<Task> tasks = <Task>[
      for (final ReplicaSnapshot input in inputs) ...input.tasks,
    ];

    final List<MergedComponent> report = <MergedComponent>[];

    // Steps 3 to 6.
    final List<Idea> mergedIdeas = _mergeIdeas(ideas, report);
    final List<Task> mergedTasks = _mergeTasks(tasks, report);

    // Step 8. Canonical output order (MERGE-3A).
    mergedIdeas.sort((Idea a, Idea b) => a.id.compareTo(b.id));
    mergedTasks.sort((Task a, Task b) => a.id.compareTo(b.id));
    report.sort(_byKindThenPassThenOutputId);

    return MergeResult(
      ideas: mergedIdeas,
      tasks: mergedTasks,
      tombstones: tombstones,
      report: MergeReport(report),
    );
  }

  // ---------------------------------------------------------------- step 1

  /// §9.3 step 1. Reduces every input's tombstones to one per Idea `id`.
  ///
  /// Earliest `deletedAt` wins; on a tie `converted` beats `deleted`, since a
  /// conversion leaves behind a Task pointing at that id. A plain set union
  /// keeps two tombstones for one Idea when one replica deleted it and another
  /// converted it — a meaningless output, and a landmine for M3's tombstone
  /// table, which keys on `id`. `reason` is informational; nothing in this
  /// algorithm reads it.
  ///
  /// Returned sorted by `id` (step 8).
  List<IdeaTombstone> _reduceTombstones(List<ReplicaSnapshot> inputs) {
    final Map<String, IdeaTombstone> byId = <String, IdeaTombstone>{};
    for (final ReplicaSnapshot input in inputs) {
      for (final IdeaTombstone tombstone in input.tombstones) {
        final IdeaTombstone? incumbent = byId[tombstone.id];
        if (incumbent == null || _outranks(tombstone, incumbent)) {
          byId[tombstone.id] = tombstone;
        }
      }
    }
    return byId.values.toList()..sort(compareTombstonesById);
  }

  /// §9.3 step 1. Whether [candidate] should replace [incumbent].
  bool _outranks(IdeaTombstone candidate, IdeaTombstone incumbent) {
    final int byDeletedAt = candidate.deletedAt.compareTo(incumbent.deletedAt);
    if (byDeletedAt != 0) return byDeletedAt < 0;
    if (candidate.reason != incumbent.reason) {
      return candidate.reason == TombstoneReason.converted;
    }
    return false;
  }

  // --------------------------------------------------------- steps 3 to 6

  /// §9.3 steps 3 to 6, for Ideas.
  ///
  /// The step-6 name re-pass **provably never fires here**: every Idea is
  /// active (§2), so two components resolving to the same name would have
  /// shared a MERGE-5 name edge in step 3 and been one component to begin
  /// with. The loop runs all the same, because a branch that is unreachable by
  /// argument rather than by construction is worth leaving in place — and
  /// `merge_property_test.dart` asserts the report never shows an Idea pass
  /// above 0, so the claim is checked rather than trusted.
  List<Idea> _mergeIdeas(List<Idea> ideas, List<MergedComponent> report) {
    List<Idea> current = <Idea>[
      for (final List<Idea> component in conflictComponents<Idea>(
        ideas,
        idOf: (Idea i) => i.id,
        normalizedNameOf: (Idea i) => i.name.normalized,
        isActive: (Idea i) => i.isActive,
      ))
        if (component.length == 1)
          component.single
        else
          _resolveIdeas(component, pass: 0, report: report),
    ];

    for (int pass = 1; ; pass++) {
      final List<List<Idea>> groups = _activeNameGroups<Idea>(
        current,
        normalizedNameOf: (Idea i) => i.name.normalized,
        isActive: (Idea i) => i.isActive,
      );
      if (groups.every((List<Idea> g) => g.length == 1)) return current;

      current = <Idea>[
        for (final Idea idea in current)
          if (!idea.isActive) idea,
        for (final List<Idea> group in groups)
          if (group.length == 1)
            group.single
          else
            _resolveIdeas(group, pass: pass, report: report),
      ];
    }
  }

  /// §9.3 steps 3 to 6, for Tasks.
  ///
  /// Unlike Ideas, the step-6 re-pass is genuinely reachable: MERGE-5 matches
  /// names only among *active* records, so an archived record can enter a
  /// component by `id`, become the primary, and carry its name into an output
  /// Task that the resolved status makes active again — landing on a name
  /// another component already resolved to.
  List<Task> _mergeTasks(List<Task> tasks, List<MergedComponent> report) {
    List<Task> current = <Task>[
      for (final List<Task> component in conflictComponents<Task>(
        tasks,
        idOf: (Task t) => t.id,
        normalizedNameOf: (Task t) => t.name.normalized,
        isActive: (Task t) => t.isActive,
      ))
        if (component.length == 1)
          component.single
        else
          _resolveTasks(component, pass: 0, report: report),
    ];

    // Termination: the first pass can *increase* the active count, because the
    // INV-2 repair un-archives. Every later pass sees only already-active
    // Tasks, where nothing can be un-archived again, and merging strictly
    // reduces their number — so this ends.
    for (int pass = 1; ; pass++) {
      final List<List<Task>> groups = _activeNameGroups<Task>(
        current,
        normalizedNameOf: (Task t) => t.name.normalized,
        isActive: (Task t) => t.isActive,
      );
      if (groups.every((List<Task> g) => g.length == 1)) return current;

      current = <Task>[
        for (final Task task in current)
          if (!task.isActive) task,
        for (final List<Task> group in groups)
          if (group.length == 1)
            group.single
          else
            _resolveTasks(group, pass: pass, report: report),
      ];
    }
  }

  /// §9.3 step 6, second bullet. Groups the active records by normalized name.
  ///
  /// Inactive records are left out: they reserve no name (NAME-7), so they
  /// cannot break NAME-6. The caller carries them through untouched.
  List<List<T>> _activeNameGroups<T>(
    List<T> records, {
    required String Function(T record) normalizedNameOf,
    required bool Function(T record) isActive,
  }) {
    final Map<String, List<T>> byName = <String, List<T>>{};
    for (final T record in records) {
      if (!isActive(record)) continue;
      byName.putIfAbsent(normalizedNameOf(record), () => <T>[]).add(record);
    }
    return byName.values.toList(growable: false);
  }

  // ---------------------------------------------------------------- step 4

  /// §9.3 step 4. Resolves one Idea component of size > 1 into one Idea.
  Idea _resolveIdeas(
    List<Idea> component, {
    required int pass,
    required List<MergedComponent> report,
  }) {
    final List<Idea> records = component.toList()..sort(compareIdeaRecords);
    final String id = smallestId(records.map((Idea i) => i.id));
    final int primaryIndex = primaryRecordIndex<Idea>(
      records,
      id: id,
      idOf: (Idea i) => i.id,
      updatedAtOf: (Idea i) => i.updatedAt,
      normalizedNameOf: (Idea i) => i.name.normalized,
    );

    final Idea resolved = Idea(
      id: id,
      name: records[primaryIndex].name,
      tags: unionTags(
        records.map((Idea i) => i.tags).toList(growable: false),
        primaryIndex,
      ),
      context: longestText(
        records.map((Idea i) => i.context).toList(growable: false),
        records.map((Idea i) => i.updatedAt).toList(growable: false),
        primaryIndex,
      ),
      timeframe: mostUrgentTimeframe(records.map((Idea i) => i.timeframe)),
      createdAt: earliestInstant(records.map((Idea i) => i.createdAt)),
      updatedAt: latestInstant(records.map((Idea i) => i.updatedAt)),
    );

    report.add(
      MergedComponent(
        kind: ItemKind.idea,
        pass: pass,
        outputId: id,
        inputIds: _distinctIdsAscending(records.map((Idea i) => i.id)),
      ),
    );
    return resolved;
  }

  /// §9.3 steps 4, 5 and 6's first bullet. Resolves one Task component of
  /// size > 1 into one Task.
  Task _resolveTasks(
    List<Task> component, {
    required int pass,
    required List<MergedComponent> report,
  }) {
    final List<Task> records = component.toList()..sort(compareTaskRecords);
    final String id = smallestId(records.map((Task t) => t.id));
    final int primaryIndex = primaryRecordIndex<Task>(
      records,
      id: id,
      idOf: (Task t) => t.id,
      updatedAtOf: (Task t) => t.updatedAt,
      normalizedNameOf: (Task t) => t.name.normalized,
    );

    // Step 5.
    final List<Subtask> subtasks = mergeSubtasks(
      recordsInRecordOrder: records,
      primaryIndex: primaryIndex,
    );

    TaskStatus status = highestPrecedenceStatus(
      records.map((Task t) => t.status),
    );
    bool isArchived =
        records.any((Task t) => t.isArchived) && status == TaskStatus.done;

    // Step 6, first bullet. INV-2: a Done Task cannot hold an open subtask.
    // Reached when one replica completed a Task while another added a subtask
    // to it. STATUS-3's only exception, and it is always reported.
    final List<MergeRepair> repairs = <MergeRepair>[];
    if (status == TaskStatus.done &&
        subtasks.any((Subtask s) => s.status != TaskStatus.done)) {
      status = TaskStatus.todo;
      isArchived = false;
      repairs.add(
        MergeRepair(
          kind: MergeRepairKind.reopenedForIncompleteSubtasks,
          itemId: id,
        ),
      );
    }

    final bool isDeleted = records.any((Task t) => t.isDeleted);
    // §3.3, §9.3 step 4: one fact about one Idea, so never resolved field by
    // field.
    final Task? source = records[primaryIndex].sourceIdeaId != null
        ? records[primaryIndex]
        : records.firstWhereOrNull((Task t) => t.sourceIdeaId != null);

    final Task resolved = Task(
      id: id,
      name: records[primaryIndex].name,
      tags: unionTags(
        records.map((Task t) => t.tags).toList(growable: false),
        primaryIndex,
      ),
      description: longestText(
        records.map((Task t) => t.description).toList(growable: false),
        records.map((Task t) => t.updatedAt).toList(growable: false),
        primaryIndex,
      ),
      status: status,
      subtasks: subtasks,
      createdAt: earliestInstant(records.map((Task t) => t.createdAt)),
      updatedAt: latestInstant(records.map((Task t) => t.updatedAt)),
      // INV-1. A `Done` record carries a `completedAt`, so resolving to `Done`
      // always finds one.
      completedAt: status == TaskStatus.done
          ? earliestNonNull(
              records
                  .where((Task t) => t.status == TaskStatus.done)
                  .map((Task t) => t.completedAt),
            )
          : null,
      // INV-4. Both timestamps are conditional on their flag, which is what
      // keeps an `archivedAt` from surviving a status that is no longer `Done`.
      isArchived: isArchived,
      archivedAt: isArchived
          ? earliestNonNull(records.map((Task t) => t.archivedAt))
          : null,
      isDeleted: isDeleted,
      deletedAt: isDeleted
          ? earliestNonNull(records.map((Task t) => t.deletedAt))
          : null,
      sourceIdeaId: source?.sourceIdeaId,
      sourceIdeaCreatedAt: source?.sourceIdeaCreatedAt,
    );

    report.add(
      MergedComponent(
        kind: ItemKind.task,
        pass: pass,
        outputId: id,
        inputIds: _distinctIdsAscending(records.map((Task t) => t.id)),
        repairs: repairs,
      ),
    );
    return resolved;
  }

  /// §9.3 step 7. The component's distinct input ids, ascending.
  List<String> _distinctIdsAscending(Iterable<String> ids) =>
      ids.toSet().toList()..sort();

  /// §9.3 step 7. Canonical report order; see [MergedComponent.pass] for why
  /// this is a strict total order.
  int _byKindThenPassThenOutputId(MergedComponent a, MergedComponent b) {
    final int byKind = a.kind.index.compareTo(b.kind.index);
    if (byKind != 0) return byKind;
    final int byPass = a.pass.compareTo(b.pass);
    if (byPass != 0) return byPass;
    return a.outputId.compareTo(b.outputId);
  }
}

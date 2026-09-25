/// §11.4.6, §11.6.5 step 6, §11.6.6. The Drift-backed [DatasetRepository].
library;

import 'package:drift/drift.dart';
import 'package:zen_domain/zen_domain.dart';

import '../database.dart';
import '../mapping/entity_mapping.dart';

/// §11.4.6. Replaces this replica's whole dataset in one transaction.
///
/// The two callers are §11.6.5 step 6, which applies a merge, and §11.6.6's
/// `"Restore from backup…"`. Both replace rather than reconcile, and §11.6.5
/// says why an upsert will not do: "SQLite evaluates unique indexes per
/// statement and has no deferrable constraints, so a row-by-row application
/// transiently collides whenever two Tasks swap names, and the INV-2 trigger
/// (§11.5.2) can abort on a half-applied task."
final class DriftDatasetRepository implements DatasetRepository {
  /// Creates a repository over [db].
  DriftDatasetRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> replaceAll(ReplicaSnapshot snapshot) =>
      // STORE-3. One transaction, so a half-applied dataset is never
      // observable — and so a constraint that does fire rolls the whole thing
      // back rather than leaving the replica between two states.
      _db.transaction(() async {
        await _deleteEverything();
        await _insertTombstones(snapshot.tombstones);
        await _insertIdeas(snapshot.ideas);
        await _insertTasks(snapshot.tasks);
      });

  /// STORE-4 step 1: `idea_tombstones`, then `ideas`, then `tasks`.
  ///
  /// Tags and subtasks follow through `ON DELETE CASCADE` (§11.5.1), which is
  /// why they are absent here. `events` is deliberately untouched: it carries
  /// no foreign key (§11.5.1) precisely so that the history of how the data got
  /// here survives the data being replaced. `settings` likewise — they are per
  /// replica and never merged (MERGE-3).
  Future<void> _deleteEverything() async {
    // Tombstones first. `inv7_tombstone_insert` aborts when a tombstoned Idea's
    // row is still present, so clearing the tombstones before the Ideas keeps
    // the table empty for the inserts below rather than depending on the order
    // the old rows happened to be in.
    await _db.delete(_db.ideaTombstones).go();
    await _db.delete(_db.ideas).go();
    await _db.delete(_db.tasks).go();
  }

  /// STORE-4 step 2, first. Before the Ideas, so that `inv7_tombstone_insert`
  /// never sees a tombstoned Idea's row — nothing is in `ideas` at this point.
  Future<void> _insertTombstones(List<IdeaTombstone> tombstones) async {
    if (tombstones.isEmpty) {
      return;
    }
    await _db.batch(
      (Batch batch) => batch.insertAll(
        _db.ideaTombstones,
        tombstones.map(tombstoneToRow).toList(growable: false),
      ),
    );
  }

  /// STORE-4 step 2. Ideas, then their tags.
  ///
  /// `inv7_idea_insert` aborts if any of these ids is tombstoned. It cannot be:
  /// §9.3 step 1 drops every Idea whose id appears in the reduced tombstone set
  /// before the merge returns, and a backup was written from a dataset that had
  /// already satisfied INV-7. If the trigger does fire, the transaction rolls
  /// back and the caller sees the failure — which is the right outcome, because
  /// it would mean the merge broke INV-7.
  Future<void> _insertIdeas(List<Idea> ideas) async {
    if (ideas.isEmpty) {
      return;
    }
    await _db.batch(
      (Batch batch) => batch.insertAll(
        _db.ideas,
        ideas.map(ideaToRow).toList(growable: false),
      ),
    );
    final List<IdeaTagsCompanion> tags = <IdeaTagsCompanion>[
      for (final Idea idea in ideas) ...ideaTagsToRows(idea),
    ];
    if (tags.isNotEmpty) {
      await _db.batch((Batch batch) => batch.insertAll(_db.ideaTags, tags));
    }
  }

  /// STORE-4 step 2, last. Tasks, then subtasks, then tags.
  ///
  /// The order inside this method is compulsory twice over: the foreign keys
  /// need the owning `tasks` row to exist, and `inv2_subtask_insert` aborts on
  /// an open subtask under a Done Task. The merge cannot produce that pair —
  /// §9.3 step 6 reopens such a Task — so a failure here means the merge broke
  /// INV-2 and the rollback is the point.
  ///
  /// Subtask order is the array order (§11.6.1) and is user-controlled and
  /// visible (MERGE-3A), so `sortIndex` is the list position, not anything
  /// derived from the subtask itself.
  Future<void> _insertTasks(List<Task> tasks) async {
    if (tasks.isEmpty) {
      return;
    }
    await _db.batch(
      (Batch batch) => batch.insertAll(
        _db.tasks,
        tasks.map(taskToRow).toList(growable: false),
      ),
    );
    final List<SubtasksCompanion> subtasks = <SubtasksCompanion>[
      for (final Task task in tasks)
        for (int i = 0; i < task.subtasks.length; i++)
          subtaskToRow(task.subtasks[i], task.id, i),
    ];
    if (subtasks.isNotEmpty) {
      await _db.batch((Batch batch) => batch.insertAll(_db.subtasks, subtasks));
    }
    final List<TaskTagsCompanion> tags = <TaskTagsCompanion>[
      for (final Task task in tasks) ...taskTagsToRows(task),
    ];
    if (tags.isNotEmpty) {
      await _db.batch((Batch batch) => batch.insertAll(_db.taskTags, tags));
    }
  }
}

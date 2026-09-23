/// §4.4, CONVERT-4, §11.4.6. Converting an Idea into a Task, atomically.
library;

import 'package:drift/drift.dart';
import 'package:zen_domain/zen_domain.dart';

import '../database.dart';
import '../mapping/entity_mapping.dart';
import 'constraint_failures.dart';
import 'drift_event_log.dart';
import 'events.dart';

/// §11.4.6, CONVERT-4. Creates the Task, removes the Idea and writes the
/// tombstone in one transaction.
///
/// "Declared as a single method so that atomicity cannot be lost by a caller"
/// (§11.4.6). STORE-3 and AC-11 both require it: after a crash mid-conversion
/// there must be either an Idea or a Task, never both and never neither.
final class DriftConversionService implements ConversionService {
  /// Creates a service over [db], minting event ids with [ids].
  DriftConversionService(this._db, {required IdGenerator ids})
    : _events = EventRecorder(DriftEventLog(_db), ids);

  final AppDatabase _db;
  final EventRecorder _events;

  @override
  Future<Result<Task, RuleViolation>> convert(
    Idea idea,
    Task draft,
    DateTime now,
  ) => translatingTaskNameCollision<Task>(
    () => _db.transaction(() async {
      // CONVERT-3: "If the name collides with an active Task, confirmation is
      // blocked … The Idea is not touched." The Task goes in first, so a
      // collision aborts the transaction before the Idea is removed. The
      // partial index is what detects it (§11.5.2); the UI's own check runs
      // earlier and produces the same message sooner.
      await _db.into(_db.tasks).insert(taskToRow(draft));
      final List<SubtasksCompanion> subtasks = <SubtasksCompanion>[
        for (int i = 0; i < draft.subtasks.length; i++)
          subtaskToRow(draft.subtasks[i], draft.id, i),
      ];
      if (subtasks.isNotEmpty) {
        await _db.batch(
          (Batch batch) => batch.insertAll(_db.subtasks, subtasks),
        );
      }
      final List<TaskTagsCompanion> tags = taskTagsToRows(draft);
      if (tags.isNotEmpty) {
        await _db.batch((Batch batch) => batch.insertAll(_db.taskTags, tags));
      }

      // CONVERT-4: the Idea is removed and tombstoned with `reason =
      // converted`. Idea before tombstone, because `inv7_tombstone_insert`
      // refuses a tombstone for an Idea that is still present (INV-7). Its
      // tags follow through `ON DELETE CASCADE`.
      await (_db.delete(
        _db.ideas,
      )..where((Ideas i) => i.id.equals(idea.id))).go();
      await _db
          .into(_db.ideaTombstones)
          .insert(tombstoneToRow(tombstoneForConversion(idea, now)));

      await _events.record(
        itemId: idea.id,
        kind: ItemKind.idea,
        type: ItemEventType.convertedToTask,
        at: now,
        payload: <String, Object?>{'taskId': draft.id},
      );
      await _events.record(
        itemId: draft.id,
        kind: ItemKind.task,
        type: ItemEventType.created,
        at: now,
        payload: <String, Object?>{'fromIdeaId': idea.id},
      );

      return draft;
    }),
    onCollision: const TaskNameCollision(),
  );
}

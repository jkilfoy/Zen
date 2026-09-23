/// §11.4.6, §11.5. The Drift-backed [TaskRepository].
library;

import 'package:drift/drift.dart';
import 'package:zen_domain/zen_domain.dart';

import '../database.dart';
import '../mapping/entity_mapping.dart';
import '../mapping/instants.dart';
import 'constraint_failures.dart';
import 'drift_event_log.dart';
import 'events.dart';

/// §11.4.6. Storage for Tasks.
///
/// NAME-6 for Tasks is the *partial* index `idx_tasks_active_name`, whose
/// `WHERE is_deleted = 0 AND is_archived = 0` is exactly NAME-7. As with Ideas,
/// this class does not pre-check it (§11.5.2): it attempts the write and
/// translates the failure, choosing [TaskNameCollision] when saving and
/// [ActiveTaskHoldsName] when restoring or unarchiving, because the index
/// cannot tell NAME-8 from NAME-9 and the operation can.
final class DriftTaskRepository implements TaskRepository {
  /// Creates a repository over [db], minting event ids with [ids].
  DriftTaskRepository(
    this._db, {
    required IdGenerator ids,
    required TimeZoneRules zone,
    // `prefer_initializing_formals` suggests `this._zone`, which Dart forbids:
    // a named parameter may not begin with an underscore.
    // ignore: prefer_initializing_formals
  }) : _zone = zone,
       _events = EventRecorder(DriftEventLog(_db), ids);

  final AppDatabase _db;
  final TimeZoneRules _zone;
  final EventRecorder _events;

  @override
  Stream<List<Task>> watchActive() => _watch(
    where: (Tasks t) => t.isDeleted.equals(0) & t.isArchived.equals(0),
    // TODO-2: by `createdAt` ascending, oldest first. "Status changes do not
    // move or regroup a task", which is why nothing here orders by status.
    order: <OrderingTerm>[
      OrderingTerm.asc(_db.tasks.createdAt),
      OrderingTerm.asc(_db.tasks.id),
    ],
  );

  @override
  Stream<List<Task>> watchArchived() => _watch(
    where: (Tasks t) => t.isDeleted.equals(0) & t.isArchived.equals(1),
    // ARCH-1: "grouped by the logical day they were completed, newest first".
    // The grouping is the screen's job; the order is this one's.
    order: <OrderingTerm>[
      OrderingTerm.desc(_db.tasks.completedAt),
      OrderingTerm.desc(_db.tasks.id),
    ],
  );

  @override
  Future<Task?> findById(String id) async {
    final TaskRow? row = await (_db.select(
      _db.tasks,
    )..where((Tasks t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _hydrate(row);
  }

  @override
  Future<Task?> findActiveByNormalizedName(String normalized) async {
    final TaskRow? row =
        await (_db.select(_db.tasks)..where(
              (Tasks t) =>
                  t.nameNormalized.equals(normalized) &
                  t.isDeleted.equals(0) &
                  t.isArchived.equals(0),
            ))
            .getSingleOrNull();
    return row == null ? null : _hydrate(row);
  }

  @override
  Future<Set<String>> activeNormalizedNames() async {
    final List<TaskRow> rows =
        await (_db.select(_db.tasks)..where(
              (Tasks t) => t.isDeleted.equals(0) & t.isArchived.equals(0),
            ))
            .get();
    return rows.map((TaskRow r) => r.nameNormalized).toSet();
  }

  @override
  Future<Result<Task, RuleViolation>> create(Task task) =>
      translatingTaskNameCollision<Task>(
        () => _db.transaction(() async {
          await _insert(task);
          await _events.record(
            itemId: task.id,
            kind: ItemKind.task,
            type: ItemEventType.created,
            at: task.createdAt,
          );
          return task;
        }),
        onCollision: const TaskNameCollision(),
      );

  @override
  Future<Result<Task, RuleViolation>> update(Task task) =>
      translatingTaskNameCollision<Task>(
        () => _db.transaction(() async {
          final Task? before = await findById(task.id);
          if (before == null) {
            throw StateError(
              'Task ${task.id} does not exist. `update` edits an existing '
              'Task; `create` is what adds one.',
            );
          }

          // Deleted and re-inserted rather than updated in place, because the
          // INV-2 triggers make an in-place update order-dependent in a way
          // that has no correct answer. Writing the task row first breaks when
          // the Task becomes `Done` while its old subtask rows are still open;
          // writing the subtasks first breaks when a `Done` Task is reopened,
          // since the new open subtasks land under a parent that is still
          // `Done`. Removing the old rows first leaves nothing for either
          // trigger to object to. It is the same wholesale-replacement
          // argument §11.6.5 makes for applying a merge, and it is safe here
          // because `update` rewrites every one of this Task's rows anyway.
          await _deleteRow(task.id);
          await _insert(task);

          await _events.recordTaskEdit(
            before: before,
            after: task,
            at: task.updatedAt,
          );
          return task;
        }),
        onCollision: const TaskNameCollision(),
      );

  @override
  Future<Result<Task, RuleViolation>> softDelete(String id, DateTime now) =>
      _applyRule(
        id,
        (Task task) => softDeleteTask(task, now),
        at: now,
        event: ItemEventType.deleted,
        onCollision: const TaskNameCollision(),
      );

  @override
  Future<Result<Task, RuleViolation>> restore(String id, DateTime now) =>
      _applyRule(
        id,
        (Task task) => restoreTask(task, now),
        at: now,
        event: ItemEventType.restored,
        // NAME-9, AC-10: restoring into a name an active Task holds is
        // prohibited, and the partial index is what prohibits it.
        onCollision: const ActiveTaskHoldsName(),
      );

  @override
  Future<Result<Task, RuleViolation>> unarchive(String id, DateTime now) =>
      _applyRule(
        id,
        (Task task) => unarchiveTask(task, now),
        at: now,
        event: ItemEventType.unarchived,
        // ARCH-4, AC-10: the same prohibition, reached from the archive.
        onCollision: const ActiveTaskHoldsName(),
      );

  @override
  Future<List<Task>> runArchiveSweep({
    required DateTime nowUtc,
    required LocalTime endOfDay,
    required String zoneId,
  }) => _db.transaction(() async {
    // EOD-2: only Done, unarchived, undeleted Tasks can archive (INV-3).
    final List<TaskRow> candidates =
        await (_db.select(_db.tasks)..where(
              (Tasks t) =>
                  t.status.equals(TaskStatus.done.name) &
                  t.isArchived.equals(0) &
                  t.isDeleted.equals(0),
            ))
            .get();

    final List<Task> archived = <Task>[];
    for (final TaskRow row in candidates) {
      final Task task = await _hydrate(row);
      if (!isDueForArchive(task, nowUtc, endOfDay, zoneId, _zone)) {
        continue;
      }
      // EOD-2: the boundary the Task crossed, not the instant the sweep ran,
      // so a replica closed across several boundaries records the right one
      // with no catch-up loop (AC-6).
      final DateTime boundary = archiveBoundaryAfter(
        task.completedAt!,
        endOfDay,
        zoneId,
        _zone,
      );
      final Task result = archiveTask(task, boundary);

      // EOD-2A: archiving is a system action, so `updated_at` is deliberately
      // absent from this write.
      await (_db.update(
        _db.tasks,
      )..where((Tasks t) => t.id.equals(task.id))).write(
        TasksCompanion(
          isArchived: const Value<int>(1),
          archivedAt: Value<String>(encodeInstant(boundary)),
        ),
      );
      await _events.record(
        itemId: task.id,
        kind: ItemKind.task,
        type: ItemEventType.archived,
        at: boundary,
      );
      archived.add(result);
    }
    return archived;
  });

  /// TAG-6. Every distinct tag on an **active** Task, for autocomplete.
  ///
  /// "All tags that exist on any active Item" (TAG-6), so archived and deleted
  /// Tasks are excluded exactly as NAME-7 excludes them from uniqueness.
  Future<List<Tag>> activeTagValues() async {
    final List<TypedResult> rows =
        await (_db.select(_db.taskTags).join(<Join<HasResultSet, Object?>>[
                innerJoin(
                  _db.tasks,
                  _db.tasks.id.equalsExp(_db.taskTags.ownerId),
                ),
              ])
              ..where(
                _db.tasks.isDeleted.equals(0) & _db.tasks.isArchived.equals(0),
              )
              ..orderBy(<OrderingTerm>[
                OrderingTerm.asc(_db.taskTags.valueNormalized),
              ]))
            .get();
    return dedupeTags(
      rows.map(
        (TypedResult r) => Tag.parse(r.readTable(_db.taskTags).value).unwrap(),
      ),
    );
  }

  /// Applies a domain rule to the stored Task and writes the result back.
  ///
  /// The rule is called with **no** active-name set, deliberately. §11.5.2 puts
  /// NAME-6 enforcement in the index rather than in a pre-check, so the rule
  /// here supplies the state transition (DEL-1, DEL-2, ARCH-3) and the index
  /// supplies the refusal; [onCollision] names which refusal it is.
  Future<Result<Task, RuleViolation>> _applyRule(
    String id,
    Result<Task, RuleViolation> Function(Task task) rule, {
    required DateTime at,
    required ItemEventType event,
    required RuleViolation onCollision,
  }) =>
      translatingTaskNameCollision<Task>(
        () => _db.transaction(() async {
          final Task? task = await findById(id);
          if (task == null) {
            throw StateError('Task $id does not exist.');
          }
          final Result<Task, RuleViolation> outcome = rule(task);
          if (outcome case Err<Task, RuleViolation>(
            :final RuleViolation error,
          )) {
            // A rule refusing before the database sees anything: the transaction
            // has written nothing, so returning the violation leaves no trace.
            throw _RuleRefused(error);
          }
          final Task result = outcome.unwrap();
          if (result == task) {
            // D-M1-9: a rule asked to do what has already been done returns the
            // record unchanged, and there is nothing to write or to log.
            return result;
          }

          await (_db.update(
            _db.tasks,
          )..where((Tasks t) => t.id.equals(id))).write(
            TasksCompanion(
              status: Value<String>(result.status.name),
              updatedAt: Value<String>(encodeInstant(result.updatedAt)),
              completedAt: Value<String?>(
                encodeInstantOrNull(result.completedAt),
              ),
              isArchived: Value<int>(result.isArchived ? 1 : 0),
              archivedAt: Value<String?>(
                encodeInstantOrNull(result.archivedAt),
              ),
              isDeleted: Value<int>(result.isDeleted ? 1 : 0),
              deletedAt: Value<String?>(encodeInstantOrNull(result.deletedAt)),
            ),
          );
          await _events.record(
            itemId: id,
            kind: ItemKind.task,
            type: event,
            at: at,
          );
          return result;
        }),
        onCollision: onCollision,
      ).catchError(
        (Object error) =>
            Err<Task, RuleViolation>((error as _RuleRefused).error),
        test: (Object error) => error is _RuleRefused,
      );

  Future<void> _insert(Task task) async {
    await _db.into(_db.tasks).insert(taskToRow(task));
    final List<SubtasksCompanion> subtasks = <SubtasksCompanion>[
      for (int i = 0; i < task.subtasks.length; i++)
        subtaskToRow(task.subtasks[i], task.id, i),
    ];
    if (subtasks.isNotEmpty) {
      await _db.batch((Batch batch) => batch.insertAll(_db.subtasks, subtasks));
    }
    final List<TaskTagsCompanion> tags = taskTagsToRows(task);
    if (tags.isNotEmpty) {
      await _db.batch((Batch batch) => batch.insertAll(_db.taskTags, tags));
    }
  }

  /// Removes a Task's row; its subtasks and tags follow through
  /// `ON DELETE CASCADE` (§11.5.1, §11.5.5).
  ///
  /// Not a delete in the product's sense — DEL-1 is a soft delete and Tasks are
  /// never hard-deleted (principle 1.2.4). This is [update]'s internal
  /// replace-in-place.
  Future<void> _deleteRow(String id) =>
      (_db.delete(_db.tasks)..where((Tasks t) => t.id.equals(id))).go();

  Future<Task> _hydrate(TaskRow row) async {
    final List<SubtaskRow> subtasks = await (_db.select(
      _db.subtasks,
    )..where((Subtasks s) => s.taskId.equals(row.id))).get();
    final List<TaskTagRow> tags = await (_db.select(
      _db.taskTags,
    )..where((TaskTags t) => t.ownerId.equals(row.id))).get();
    return taskFromRow(row, subtasks, tags);
  }

  /// One query over three tables, so that an edit to a subtask or a tag updates
  /// the list as surely as an edit to the Task itself.
  Stream<List<Task>> _watch({
    required Expression<bool> Function(Tasks t) where,
    required List<OrderingTerm> order,
  }) {
    final JoinedSelectStatement<HasResultSet, Object?> query =
        _db.select(_db.tasks).join(<Join<HasResultSet, Object?>>[
            leftOuterJoin(
              _db.subtasks,
              _db.subtasks.taskId.equalsExp(_db.tasks.id),
            ),
            leftOuterJoin(
              _db.taskTags,
              _db.taskTags.ownerId.equalsExp(_db.tasks.id),
            ),
          ])
          ..where(where(_db.tasks))
          ..orderBy(order);

    return query.watch().map(_assemble);
  }

  /// Collapses the join's row-per-(subtask × tag) shape back into one Task
  /// each, keeping the query's order.
  List<Task> _assemble(List<TypedResult> results) {
    final List<TaskRow> order = <TaskRow>[];
    final Map<String, Map<String, SubtaskRow>> subtasks =
        <String, Map<String, SubtaskRow>>{};
    final Map<String, Map<String, TaskTagRow>> tags =
        <String, Map<String, TaskTagRow>>{};

    for (final TypedResult result in results) {
      final TaskRow row = result.readTable(_db.tasks);
      if (!subtasks.containsKey(row.id)) {
        order.add(row);
        subtasks[row.id] = <String, SubtaskRow>{};
        tags[row.id] = <String, TaskTagRow>{};
      }
      final SubtaskRow? subtask = result.readTableOrNull(_db.subtasks);
      if (subtask != null) {
        subtasks[row.id]![subtask.id] = subtask;
      }
      final TaskTagRow? tag = result.readTableOrNull(_db.taskTags);
      if (tag != null) {
        tags[row.id]![tag.valueNormalized] = tag;
      }
    }

    return <Task>[
      for (final TaskRow row in order)
        taskFromRow(row, subtasks[row.id]!.values, tags[row.id]!.values),
    ];
  }
}

/// Carries a rule's refusal out of a transaction so the transaction rolls back.
///
/// Returning an [Err] from inside `transaction` would commit it. Nothing has
/// been written at the point this is thrown, but rolling back rather than
/// committing an empty transaction is the honest thing to do, and it keeps the
/// refusal and the constraint translation on the same path.
final class _RuleRefused implements Exception {
  const _RuleRefused(this.error);

  final RuleViolation error;
}

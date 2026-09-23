/// §11.5.2. The single place rows become entities and entities become rows.
///
/// "SQL cannot assert `name_normalized = normalizeName(name)`. A stale
/// normalized value would leave the unique index guarding the wrong string,
/// silently. … The mitigation is that exactly one mapper writes both columns,
/// and a test drives every write path and re-derives `normalizeName(name)` for
/// every row." This file is that mapper.
library;

import 'package:drift/drift.dart';
import 'package:zen_domain/zen_domain.dart';

import '../database.dart';
import 'instants.dart';

/// §3.2. Builds the row for [idea]. The only writer of `ideas`.
IdeasCompanion ideaToRow(Idea idea) => IdeasCompanion(
  id: Value<String>(idea.id),
  name: Value<String>(idea.name.value),
  // §2, NAME-5. Taken from the value object, which derived it with the one
  // normalization function, rather than recomputed from the raw string here.
  nameNormalized: Value<String>(idea.name.normalized),
  context: Value<String>(idea.context.value),
  timeframe: Value<String>(idea.timeframe.name),
  createdAt: Value<String>(encodeInstant(idea.createdAt)),
  updatedAt: Value<String>(encodeInstant(idea.updatedAt)),
);

/// §3.2. Rebuilds an Idea from its row and its tags.
Idea ideaFromRow(IdeaRow row, Iterable<IdeaTagRow> tagRows) => Idea(
  id: row.id,
  name: _itemName(row.name, 'ideas.name', row.id),
  tags: _tags(
    tagRows.map((IdeaTagRow t) => (t.sortIndex, t.value)),
    'idea_tags',
    row.id,
  ),
  context: _context(row.context, row.id),
  timeframe: _enumByName(Timeframe.values, row.timeframe, 'ideas.timeframe'),
  createdAt: decodeInstant(row.createdAt),
  updatedAt: decodeInstant(row.updatedAt),
);

/// §3.3. Builds the row for [task]. The only writer of `tasks`.
TasksCompanion taskToRow(Task task) => TasksCompanion(
  id: Value<String>(task.id),
  name: Value<String>(task.name.value),
  nameNormalized: Value<String>(task.name.normalized),
  description: Value<String>(task.description.value),
  status: Value<String>(task.status.name),
  createdAt: Value<String>(encodeInstant(task.createdAt)),
  updatedAt: Value<String>(encodeInstant(task.updatedAt)),
  completedAt: Value<String?>(encodeInstantOrNull(task.completedAt)),
  isArchived: Value<int>(_boolToInt(task.isArchived)),
  archivedAt: Value<String?>(encodeInstantOrNull(task.archivedAt)),
  isDeleted: Value<int>(_boolToInt(task.isDeleted)),
  deletedAt: Value<String?>(encodeInstantOrNull(task.deletedAt)),
  sourceIdeaId: Value<String?>(task.sourceIdeaId),
  sourceIdeaCreatedAt: Value<String?>(
    encodeInstantOrNull(task.sourceIdeaCreatedAt),
  ),
);

/// §3.3. Rebuilds a Task from its row, its subtasks and its tags.
///
/// §3.3 makes both the subtask order and the tag order user-visible, and
/// MERGE-3A is explicit that they are sequences rather than sets, so both are
/// sorted back into `sort_index` order here rather than left to the query.
Task taskFromRow(
  TaskRow row,
  Iterable<SubtaskRow> subtaskRows,
  Iterable<TaskTagRow> tagRows,
) => Task(
  id: row.id,
  name: _itemName(row.name, 'tasks.name', row.id),
  tags: _tags(
    tagRows.map((TaskTagRow t) => (t.sortIndex, t.value)),
    'task_tags',
    row.id,
  ),
  description: _description(row.description, row.id),
  status: _enumByName(TaskStatus.values, row.status, 'tasks.status'),
  subtasks: _subtasks(subtaskRows),
  createdAt: decodeInstant(row.createdAt),
  updatedAt: decodeInstant(row.updatedAt),
  completedAt: decodeInstantOrNull(row.completedAt),
  isArchived: _intToBool(row.isArchived),
  archivedAt: decodeInstantOrNull(row.archivedAt),
  isDeleted: _intToBool(row.isDeleted),
  deletedAt: decodeInstantOrNull(row.deletedAt),
  sourceIdeaId: row.sourceIdeaId,
  sourceIdeaCreatedAt: decodeInstantOrNull(row.sourceIdeaCreatedAt),
);

/// §3.4. Builds the row for [subtask] at [sortIndex] under [taskId].
///
/// §11.5.1: the list order "MUST NOT depend on insertion order or id", so the
/// position is written explicitly rather than inferred.
SubtasksCompanion subtaskToRow(Subtask subtask, String taskId, int sortIndex) =>
    SubtasksCompanion(
      id: Value<String>(subtask.id),
      taskId: Value<String>(taskId),
      name: Value<String>(subtask.name.value),
      status: Value<String>(subtask.status.name),
      sortIndex: Value<int>(sortIndex),
      createdAt: Value<String>(encodeInstant(subtask.createdAt)),
      updatedAt: Value<String>(encodeInstant(subtask.updatedAt)),
      completedAt: Value<String?>(encodeInstantOrNull(subtask.completedAt)),
    );

/// §3.4. Rebuilds a Subtask from its row.
Subtask subtaskFromRow(SubtaskRow row) => Subtask(
  id: row.id,
  name: _subtaskName(row.name, row.id),
  status: _enumByName(TaskStatus.values, row.status, 'subtasks.status'),
  createdAt: decodeInstant(row.createdAt),
  updatedAt: decodeInstant(row.updatedAt),
  completedAt: decodeInstantOrNull(row.completedAt),
);

/// §3.5, §3.2. Builds an Idea's tag rows, in the Item's own order.
List<IdeaTagsCompanion> ideaTagsToRows(Idea idea) => <IdeaTagsCompanion>[
  for (int i = 0; i < idea.tags.length; i++)
    IdeaTagsCompanion(
      ownerId: Value<String>(idea.id),
      value: Value<String>(idea.tags[i].value),
      valueNormalized: Value<String>(idea.tags[i].normalized),
      sortIndex: Value<int>(i),
    ),
];

/// §3.5, §3.3. Builds a Task's tag rows, in the Item's own order.
List<TaskTagsCompanion> taskTagsToRows(Task task) => <TaskTagsCompanion>[
  for (int i = 0; i < task.tags.length; i++)
    TaskTagsCompanion(
      ownerId: Value<String>(task.id),
      value: Value<String>(task.tags[i].value),
      valueNormalized: Value<String>(task.tags[i].normalized),
      sortIndex: Value<int>(i),
    ),
];

/// §2, DEL-3. Builds the row for [tombstone].
IdeaTombstonesCompanion tombstoneToRow(IdeaTombstone tombstone) =>
    IdeaTombstonesCompanion(
      id: Value<String>(tombstone.id),
      deletedAt: Value<String>(encodeInstant(tombstone.deletedAt)),
      reason: Value<String>(tombstone.reason.name),
    );

/// §2, DEL-3. Rebuilds a tombstone from its row.
IdeaTombstone tombstoneFromRow(IdeaTombstoneRow row) => IdeaTombstone(
  id: row.id,
  deletedAt: decodeInstant(row.deletedAt),
  reason: _enumByName(
    TombstoneReason.values,
    row.reason,
    'idea_tombstones.reason',
  ),
);

/// §11.5.1. SQLite has no boolean type, and a `STRICT` table may only declare
/// `INT`, `INTEGER`, `REAL`, `TEXT`, `BLOB` or `ANY` — so `is_archived` and
/// `is_deleted` are integers, guarded by their `IN (0, 1)` checks, and
/// converted here rather than anywhere else.
int _boolToInt(bool value) => value ? 1 : 0;

bool _intToBool(int value) => value != 0;

List<Subtask> _subtasks(Iterable<SubtaskRow> rows) {
  final List<SubtaskRow> ordered = rows.toList()
    ..sort((SubtaskRow a, SubtaskRow b) => a.sortIndex.compareTo(b.sortIndex));
  return ordered.map(subtaskFromRow).toList(growable: false);
}

List<Tag> _tags(Iterable<(int, String)> rows, String table, String ownerId) {
  final List<(int, String)> ordered = rows.toList()
    ..sort(((int, String) a, (int, String) b) => a.$1.compareTo(b.$1));
  return <Tag>[
    for (final (int, String) row in ordered)
      Tag.parse(row.$2).valueOrNull ?? _corrupt(table, ownerId, row.$2),
  ];
}

ItemName _itemName(String stored, String column, String id) =>
    ItemName.parse(stored).valueOrNull ?? _corrupt(column, id, stored);

SubtaskName _subtaskName(String stored, String id) =>
    SubtaskName.parse(stored).valueOrNull ??
    _corrupt('subtasks.name', id, stored);

ItemText _context(String stored, String id) =>
    ItemText.parseContext(stored).valueOrNull ??
    _corrupt('ideas.context', id, stored);

ItemText _description(String stored, String id) =>
    ItemText.parseDescription(stored).valueOrNull ??
    _corrupt('tasks.description', id, stored);

T _enumByName<T extends Enum>(List<T> values, String stored, String column) {
  for (final T value in values) {
    if (value.name == stored) {
      return value;
    }
  }
  return _corrupt(column, '-', stored);
}

/// A stored value the domain refuses to parse.
///
/// Unreachable through this package: §11.5.2's `CHECK` constraints and this
/// file's own writers between them make every stored value well-formed. It is
/// therefore corruption rather than user input, which §11.4.1 reserves
/// exceptions for. §11.5.5's "cannot open, or the file is corrupt" screen is
/// what catches it in the app.
Never _corrupt(String column, String id, String stored) => throw StateError(
  'Corrupt database: $column holds "$stored" for row "$id", which the domain '
  'refuses to parse. See §11.5.5.',
);

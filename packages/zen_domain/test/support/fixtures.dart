/// Builders that keep the rule tests to the two lines §11.4.1 promises.
///
/// Every builder defaults to a well-formed record, so a test states only the
/// field it is about.
library;

import 'package:zen_domain/zen_domain.dart';

/// An arbitrary fixed instant. Tests that care about time offset from it with
/// [at] rather than inventing dates.
final DateTime base = DateTime.utc(2026, 9, 22, 12);

/// [base] plus [minutes], for ordering timestamps within a test.
DateTime at(int minutes) => base.add(Duration(minutes: minutes));

/// Parses [raw] as an [ItemName], failing the test if it is invalid.
ItemName name(String raw) => ItemName.parse(raw).unwrap();

/// Parses [raw] as a [SubtaskName], failing the test if it is invalid.
SubtaskName subtaskName(String raw) => SubtaskName.parse(raw).unwrap();

/// Parses [raw] as a [Tag], failing the test if it is invalid.
Tag tag(String raw) => Tag.parse(raw).unwrap();

/// Parses [raw] as a Task description, failing the test if it is invalid.
ItemText description(String raw) => ItemText.parseDescription(raw).unwrap();

/// Parses [raw] as an Idea context, failing the test if it is invalid.
ItemText context(String raw) => ItemText.parseContext(raw).unwrap();

/// A well-formed [Subtask], `Todo` unless told otherwise.
///
/// Passing [status] of [TaskStatus.done] sets `completedAt` too, so the result
/// satisfies INV-1 without the caller thinking about it.
Subtask aSubtask({
  String id = 'sub-1',
  String named = 'A subtask',
  TaskStatus status = TaskStatus.todo,
  DateTime? createdAt,
  DateTime? updatedAt,
}) => Subtask(
  id: id,
  name: subtaskName(named),
  status: status,
  createdAt: createdAt ?? base,
  updatedAt: updatedAt ?? createdAt ?? base,
  completedAt: status == TaskStatus.done ? (updatedAt ?? base) : null,
);

/// A well-formed [Task], `Todo` with no subtasks unless told otherwise.
///
/// As with [aSubtask], `completedAt` follows [status] so INV-1 holds by
/// construction. [archivedAt] and [deletedAt] follow their flags (INV-4).
Task aTask({
  String id = 'task-1',
  String named = 'A task',
  TaskStatus status = TaskStatus.todo,
  List<Subtask> subtasks = const <Subtask>[],
  List<Tag> tags = const <Tag>[],
  ItemText? describedAs,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? completedAt,
  bool isArchived = false,
  DateTime? archivedAt,
  bool isDeleted = false,
  DateTime? deletedAt,
  String? sourceIdeaId,
  DateTime? sourceIdeaCreatedAt,
}) {
  final DateTime created = createdAt ?? base;
  final DateTime updated = updatedAt ?? created;
  return Task(
    id: id,
    name: name(named),
    tags: tags,
    description: describedAs ?? ItemText.empty,
    status: status,
    subtasks: subtasks,
    createdAt: created,
    updatedAt: updated,
    completedAt: status == TaskStatus.done ? (completedAt ?? updated) : null,
    isArchived: isArchived,
    archivedAt: isArchived ? (archivedAt ?? updated) : null,
    isDeleted: isDeleted,
    deletedAt: isDeleted ? (deletedAt ?? updated) : null,
    sourceIdeaId: sourceIdeaId,
    sourceIdeaCreatedAt: sourceIdeaCreatedAt,
  );
}

/// A well-formed [Idea] in the [Timeframe.now] group unless told otherwise.
Idea anIdea({
  String id = 'idea-1',
  String named = 'An idea',
  Timeframe timeframe = Timeframe.now,
  List<Tag> tags = const <Tag>[],
  ItemText? contextText,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final DateTime created = createdAt ?? base;
  return Idea(
    id: id,
    name: name(named),
    tags: tags,
    context: contextText ?? ItemText.empty,
    timeframe: timeframe,
    createdAt: created,
    updatedAt: updatedAt ?? created,
  );
}

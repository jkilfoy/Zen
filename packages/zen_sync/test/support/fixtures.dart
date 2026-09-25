/// Builders for the domain entities these tests exchange.
///
/// `zen_domain`'s own fixtures live in its `test/` directory, which a sibling
/// package cannot import (D-M1-8), so the few shapes needed here are rebuilt
/// rather than promoted into `lib/` for one consumer.
library;

import 'package:zen_domain/zen_domain.dart';

/// A fixed instant every fixture hangs off, so a test that cares about time
/// says so explicitly.
final DateTime t0 = DateTime.utc(2026, 9, 24, 18, 30);

/// Returns [t0] plus [minutes], at millisecond precision (INV-9).
DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

/// Builds an Idea, defaulting everything the caller does not care about.
Idea idea(
  String id,
  String name, {
  Timeframe timeframe = Timeframe.now,
  List<String> tags = const <String>[],
  String context = '',
  DateTime? createdAt,
  DateTime? updatedAt,
}) => Idea(
  id: id,
  name: ItemName.parse(name).unwrap(),
  timeframe: timeframe,
  tags: tags.map((String t) => Tag.parse(t).unwrap()).toList(),
  context: ItemText.parseContext(context).unwrap(),
  createdAt: createdAt ?? t0,
  updatedAt: updatedAt ?? createdAt ?? t0,
);

/// Builds a Task. [status] and [completedAt] are kept consistent by default so
/// INV-1 holds without every call site restating it.
Task task(
  String id,
  String name, {
  TaskStatus status = TaskStatus.todo,
  List<String> tags = const <String>[],
  String description = '',
  List<Subtask> subtasks = const <Subtask>[],
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? completedAt,
  bool isArchived = false,
  DateTime? archivedAt,
  bool isDeleted = false,
  DateTime? deletedAt,
  String? sourceIdeaId,
  DateTime? sourceIdeaCreatedAt,
}) => Task(
  id: id,
  name: ItemName.parse(name).unwrap(),
  status: status,
  tags: tags.map((String t) => Tag.parse(t).unwrap()).toList(),
  description: ItemText.parseDescription(description).unwrap(),
  subtasks: subtasks,
  createdAt: createdAt ?? t0,
  updatedAt: updatedAt ?? createdAt ?? t0,
  completedAt: status == TaskStatus.done ? (completedAt ?? t0) : null,
  isArchived: isArchived,
  archivedAt: isArchived ? (archivedAt ?? t0) : null,
  isDeleted: isDeleted,
  deletedAt: isDeleted ? (deletedAt ?? t0) : null,
  sourceIdeaId: sourceIdeaId,
  sourceIdeaCreatedAt: sourceIdeaId == null
      ? null
      : (sourceIdeaCreatedAt ?? t0),
);

/// Builds a Subtask.
Subtask subtask(
  String id,
  String name, {
  TaskStatus status = TaskStatus.todo,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? completedAt,
}) => Subtask(
  id: id,
  name: SubtaskName.parse(name).unwrap(),
  status: status,
  createdAt: createdAt ?? t0,
  updatedAt: updatedAt ?? createdAt ?? t0,
  completedAt: status == TaskStatus.done ? (completedAt ?? t0) : null,
);

/// Builds an Idea tombstone (DEL-3).
IdeaTombstone tombstone(
  String id, {
  TombstoneReason reason = TombstoneReason.deleted,
  DateTime? deletedAt,
}) => IdeaTombstone(id: id, deletedAt: deletedAt ?? t0, reason: reason);

/// Builds a snapshot.
ReplicaSnapshot snapshot(
  String replicaId, {
  List<Idea> ideas = const <Idea>[],
  List<Task> tasks = const <Task>[],
  List<IdeaTombstone> tombstones = const <IdeaTombstone>[],
}) => ReplicaSnapshot(
  replicaId: replicaId,
  ideas: ideas,
  tasks: tasks,
  tombstones: tombstones,
);

/// §3.3. Something the user intends to complete.
library;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../time/instant_precision.dart';
import 'enums.dart';
import 'item_name.dart';
import 'item_text.dart';
import 'subtask.dart';
import 'tag.dart';

const ListEquality<Object?> _listEquality = ListEquality<Object?>();

/// §3.3. A Task.
///
/// Tasks are never hard-deleted (principle 1.2.4): [isDeleted] hides one
/// (DEL-1) and [isArchived] retires a completed one after End of Day (EOD-2).
///
/// Immutable: every change produces a new instance (§11.11). The lifecycle
/// timestamps are not settable through [copyWith], because INV-1 and INV-4 make
/// each of them a function of a flag; they are set by [withStatus], [archived],
/// [unarchived], [softDeleted] and [restored], which cannot break the pairing.
@immutable
final class Task {
  /// Constructs a Task and asserts §3.7's invariants.
  ///
  /// The assert catches programmer error only (§11.4.1); user-facing refusals
  /// are [Result]s returned by the rules in `rules/task_rules.dart`.
  Task({
    required this.id,
    required this.name,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    List<Tag> tags = const <Tag>[],
    this.description = ItemText.empty,
    List<Subtask> subtasks = const <Subtask>[],
    this.completedAt,
    this.isArchived = false,
    this.archivedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.sourceIdeaId,
    this.sourceIdeaCreatedAt,
  }) : tags = List<Tag>.unmodifiable(tags),
       subtasks = List<Subtask>.unmodifiable(subtasks) {
    assert(
      invariantFailures.isEmpty,
      'Task $id violates §3.7: ${invariantFailures.join('; ')}',
    );
  }

  /// §3, §3.3. UUIDv7, assigned at creation and never changed.
  final String id;

  /// §3.3, §3.1. The task's name, unique among active Tasks (NAME-6).
  final ItemName name;

  /// §3.3, §3.5. Tags in insertion order, de-duplicated case-insensitively.
  final List<Tag> tags;

  /// §3.3. Free multi-line plain text.
  final ItemText description;

  /// §3.3, §4.2. `Todo`, `Blocked` or `Done`.
  final TaskStatus status;

  /// §3.3, §3.4. Subtasks in user-controlled order (TODO-2, SUB-9).
  final List<Subtask> subtasks;

  /// §3.3. Creation instant, UTC. For a Task converted from an Idea this is the
  /// conversion time (CONVERT-4).
  final DateTime createdAt;

  /// §3.3. Instant of the last edit, UTC, including subtask changes.
  final DateTime updatedAt;

  /// §3.3, INV-1. Set when [status] becomes [TaskStatus.done], cleared when it
  /// leaves.
  final DateTime? completedAt;

  /// §3.3, §4.5. Whether End of Day has retired this completed Task.
  final bool isArchived;

  /// §3.3, INV-4, EOD-2. The boundary instant at which it archived.
  final DateTime? archivedAt;

  /// §3.3, DEL-1. Whether this Task is soft-deleted. Never hard-deleted.
  final bool isDeleted;

  /// §3.3, INV-4. When it was soft-deleted.
  final DateTime? deletedAt;

  /// §3.3, CONVERT-1. The Idea this Task was converted from, if any.
  final String? sourceIdeaId;

  /// §3.3, CONVERT-1. That Idea's `createdAt`, preserving how long the item has
  /// existed.
  final DateTime? sourceIdeaCreatedAt;

  /// §2. Whether this Task reserves its name and appears in the To Do list.
  ///
  /// "A Task with `isDeleted == false` **and** `isArchived == false`". Name
  /// uniqueness (NAME-6) and name-based merge matching (§9.2) apply only to
  /// active Items.
  bool get isActive => !isDeleted && !isArchived;

  /// §4.2, INV-2. Whether every subtask is `Done`, which is the guard on
  /// completing this Task. Vacuously true when there are no subtasks.
  bool get allSubtasksDone =>
      subtasks.every((Subtask s) => s.status == TaskStatus.done);

  /// SUB-1. Whether subtask *statuses* are locked.
  ///
  /// Only `Done` locks them (SUB-6). The subtask list itself stays editable —
  /// renaming, deleting and reordering remain available (SUB-1, TASKFORM-5).
  bool get subtaskStatusesLocked => status == TaskStatus.done;

  /// Returns the subtask with [subtaskId], or `null` if this Task has none.
  Subtask? subtaskById(String subtaskId) =>
      subtasks.firstWhereOrNull((Subtask s) => s.id == subtaskId);

  /// §3.7. The invariants this Task breaks, empty when it is well-formed.
  ///
  /// Covers INV-1 through INV-5 and INV-8, INV-9, including its subtasks' own
  /// failures. INV-6 (uniqueness) and INV-7 (tombstones) span the whole dataset
  /// and live in `invariants.dart`.
  List<String> get invariantFailures => <String>[
    if ((status == TaskStatus.done) != (completedAt != null))
      'INV-1: status is $status but completedAt is $completedAt',
    if (status == TaskStatus.done && !allSubtasksDone)
      'INV-2: status is Done but a subtask is not',
    if (isArchived && status != TaskStatus.done)
      'INV-3: archived but status is $status',
    if (isArchived != (archivedAt != null))
      'INV-4: isArchived is $isArchived but archivedAt is $archivedAt',
    if (isDeleted != (deletedAt != null))
      'INV-4: isDeleted is $isDeleted but deletedAt is $deletedAt',
    if (createdAt.isAfter(updatedAt))
      'INV-5: createdAt $createdAt is after updatedAt $updatedAt',
    if ((sourceIdeaId == null) != (sourceIdeaCreatedAt == null))
      'INV-8: sourceIdeaId is $sourceIdeaId but sourceIdeaCreatedAt is '
          '$sourceIdeaCreatedAt',
    ...timestampPrecisionFailures(<String, DateTime?>{
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'completedAt': completedAt,
      'archivedAt': archivedAt,
      'deletedAt': deletedAt,
      'sourceIdeaCreatedAt': sourceIdeaCreatedAt,
    }),
    for (final Subtask subtask in subtasks)
      ...subtask.invariantFailures.map(
        (String f) => 'subtask ${subtask.id}: $f',
      ),
  ];

  /// §4.2, INV-1. Returns this Task with [target] as its status, setting or
  /// clearing [completedAt] so INV-1 cannot be broken.
  ///
  /// Enforces no guard of its own: the guards are in `rules/task_rules.dart`,
  /// which is the only thing that should call this.
  Task withStatus(TaskStatus target, DateTime now) => _copy(
    status: target,
    updatedAt: now,
    completedAt: target == TaskStatus.done ? now : null,
  );

  /// EOD-2, EOD-2A, INV-3, INV-4. Returns this Task archived at [boundary].
  ///
  /// [boundary] is the End-of-Day instant the Task crossed, not the instant the
  /// sweep ran, so a device closed across several boundaries still records the
  /// right one (§11.5.4).
  ///
  /// EOD-2A: archiving is a system action, not a user edit, so [updatedAt] does
  /// **not** move; [archivedAt] is the audit trail. Moving it would let a sweep
  /// firing after a late edit push [updatedAt] *backwards* to the boundary
  /// instant, and §9.3 step 4 resolves by latest [updatedAt] — a peer holding
  /// pre-edit content would then win and the edit would be lost.
  /// [unarchived] *is* a user action and does move it.
  Task archived(DateTime boundary) =>
      _copy(isArchived: true, archivedAt: boundary);

  /// ARCH-3. Returns this Task unarchived: back to `Todo`, [completedAt]
  /// cleared, ready to reappear in the To Do list with its subtask statuses
  /// unlocked.
  Task unarchived(DateTime now) => _copy(
    isArchived: false,
    archivedAt: null,
    status: TaskStatus.todo,
    completedAt: null,
    updatedAt: now,
  );

  /// DEL-1, INV-4. Returns this Task soft-deleted at [now].
  Task softDeleted(DateTime now) =>
      _copy(isDeleted: true, deletedAt: now, updatedAt: now);

  /// DEL-2, INV-4. Returns this Task restored, leaving [status] as it was.
  ///
  /// "If the status was `Done`, the next archive sweep will archive it."
  Task restored(DateTime now) =>
      _copy(isDeleted: false, deletedAt: null, updatedAt: now);

  /// Returns a copy with the given fields replaced.
  ///
  /// The lifecycle timestamps are absent by design — see the class doc.
  Task copyWith({
    ItemName? name,
    List<Tag>? tags,
    ItemText? description,
    List<Subtask>? subtasks,
    DateTime? updatedAt,
  }) => _copy(
    name: name,
    tags: tags,
    description: description,
    subtasks: subtasks,
    updatedAt: updatedAt,
  );

  /// The single place a Task is rebuilt. Private so that the nullable lifecycle
  /// fields can only be cleared through the intention-revealing methods above.
  Task _copy({
    ItemName? name,
    List<Tag>? tags,
    ItemText? description,
    TaskStatus? status,
    List<Subtask>? subtasks,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool? isArchived,
    DateTime? archivedAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) => Task(
    id: id,
    name: name ?? this.name,
    tags: tags ?? this.tags,
    description: description ?? this.description,
    status: status ?? this.status,
    subtasks: subtasks ?? this.subtasks,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: (status ?? this.status) == TaskStatus.done
        ? (completedAt ?? this.completedAt)
        : null,
    isArchived: isArchived ?? this.isArchived,
    archivedAt: (isArchived ?? this.isArchived)
        ? (archivedAt ?? this.archivedAt)
        : null,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: (isDeleted ?? this.isDeleted)
        ? (deletedAt ?? this.deletedAt)
        : null,
    sourceIdeaId: sourceIdeaId,
    sourceIdeaCreatedAt: sourceIdeaCreatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Task &&
      other.id == id &&
      other.name == name &&
      _listEquality.equals(other.tags, tags) &&
      other.description == description &&
      other.status == status &&
      _listEquality.equals(other.subtasks, subtasks) &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.completedAt == completedAt &&
      other.isArchived == isArchived &&
      other.archivedAt == archivedAt &&
      other.isDeleted == isDeleted &&
      other.deletedAt == deletedAt &&
      other.sourceIdeaId == sourceIdeaId &&
      other.sourceIdeaCreatedAt == sourceIdeaCreatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    _listEquality.hash(tags),
    description,
    status,
    _listEquality.hash(subtasks),
    createdAt,
    updatedAt,
    completedAt,
    isArchived,
    archivedAt,
    isDeleted,
    deletedAt,
    sourceIdeaId,
    sourceIdeaCreatedAt,
  );

  @override
  String toString() =>
      'Task($id, "$name", ${status.name}, ${subtasks.length} subtasks'
      '${isArchived ? ', archived' : ''}${isDeleted ? ', deleted' : ''})';
}

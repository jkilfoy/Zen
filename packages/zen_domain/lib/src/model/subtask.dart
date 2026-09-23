/// §3.4. A checklist entry belonging to exactly one Task.
library;

import 'package:meta/meta.dart';

import '../time/instant_precision.dart';
import 'enums.dart';
import 'subtask_name.dart';

/// §3.4. A Subtask.
///
/// Subtasks exist only inside their parent Task and are created, renamed,
/// deleted and reordered only on the Create/Edit Task screen (SUB-9). They have
/// no tags, context, timeframe, archive flag or delete flag, and deleting one
/// is a hard delete (SUB-7).
///
/// Immutable: every change produces a new instance (§11.11).
@immutable
final class Subtask {
  /// Constructs a Subtask and asserts §3.7's per-entity invariants.
  ///
  /// The assert catches programmer error only (§11.4.1); user-facing refusals
  /// are [Result]s returned by the rules in `rules/subtask_rules.dart`.
  Subtask({
    required this.id,
    required this.name,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  }) {
    assert(
      invariantFailures.isEmpty,
      'Subtask $id violates §3.7: ${invariantFailures.join('; ')}',
    );
  }

  /// §3, §3.4. UUIDv7, assigned at creation and never changed.
  final String id;

  /// §3.4. The subtask's name. Not subject to uniqueness (NAME-11).
  final SubtaskName name;

  /// §3.4. `Todo`, `Blocked` or `Done`.
  final TaskStatus status;

  /// §3.4. Creation instant, UTC.
  final DateTime createdAt;

  /// §3.4. Instant of the last edit, UTC.
  final DateTime updatedAt;

  /// §3.4, INV-1. Set when [status] becomes [TaskStatus.done], cleared when it
  /// leaves.
  final DateTime? completedAt;

  /// §3.7. The invariants this subtask breaks, empty when it is well-formed.
  ///
  /// INV-1 (`completedAt != null` ⇔ `status == Done`), INV-5
  /// (`createdAt <= updatedAt`) and INV-9 (millisecond precision). INV-2 spans
  /// a Task and its subtasks, so it is checked on [Task] instead.
  List<String> get invariantFailures => <String>[
    if ((status == TaskStatus.done) != (completedAt != null))
      'INV-1: status is $status but completedAt is $completedAt',
    if (createdAt.isAfter(updatedAt))
      'INV-5: createdAt $createdAt is after updatedAt $updatedAt',
    ...timestampPrecisionFailures(<String, DateTime?>{
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'completedAt': completedAt,
    }),
  ];

  /// §4.3, INV-1. Returns this subtask with [target] as its status, setting or
  /// clearing [completedAt] so INV-1 cannot be broken.
  ///
  /// [now] becomes [updatedAt], and [completedAt] when [target] is
  /// [TaskStatus.done].
  Subtask withStatus(TaskStatus target, DateTime now) => Subtask(
    id: id,
    name: name,
    status: target,
    createdAt: createdAt,
    updatedAt: now,
    completedAt: target == TaskStatus.done ? now : null,
  );

  /// Returns a copy with the given fields replaced.
  ///
  /// [completedAt] is deliberately absent: INV-1 makes it a function of
  /// [status], so it is set only through [withStatus].
  Subtask copyWith({SubtaskName? name, DateTime? updatedAt}) => Subtask(
    id: id,
    name: name ?? this.name,
    status: status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Subtask &&
      other.id == id &&
      other.name == name &&
      other.status == status &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.completedAt == completedAt;

  @override
  int get hashCode =>
      Object.hash(id, name, status, createdAt, updatedAt, completedAt);

  @override
  String toString() => 'Subtask($id, "$name", ${status.name})';
}

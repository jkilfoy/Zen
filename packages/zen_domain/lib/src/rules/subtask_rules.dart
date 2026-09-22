/// §4.3. Every rule that acts on a Task's subtasks.
///
/// SUB-1 and SUB-8 together mean INV-2 can never be broken by a subtask edit:
/// statuses cannot change while the parent is `Done`, and no new subtask can
/// appear. The only way to make a `Done` Task incomplete is to change the
/// Task's own status first.
///
/// Every function here returns the whole parent [Task], because §3.3 requires
/// its `updatedAt` to move on every subtask change.
library;

import '../ids/id_generator.dart';
import '../model/enums.dart';
import '../model/subtask.dart';
import '../model/subtask_name.dart';
import '../model/task.dart';
import '../result.dart';
import 'task_rules.dart';

/// SUB-1, SUB-5, SUB-6, TASKFORM-5. Sets one subtask's status.
///
/// SUB-1: "While a Task's status is `Done`, its subtasks' **statuses** are
/// locked: they cannot be changed, anywhere." Only `Done` locks them — the
/// subtasks of a `Blocked` Task can be toggled freely (SUB-6).
///
/// SUB-5: on the Edit Task screen an unlocked subtask's status can be set to
/// any of the three values, which is why [target] is not restricted here.
///
/// STATUS-2: completing the last open subtask does not auto-complete the
/// parent.
Result<Task, RuleViolation> setSubtaskStatus(
  Task task,
  String subtaskId,
  TaskStatus target,
  DateTime now,
) {
  final RuleViolation? blocked = editabilityViolation(task);
  if (blocked != null) {
    return Err<Task, RuleViolation>(blocked);
  }
  if (task.subtaskStatusesLocked) {
    return const Err<Task, RuleViolation>(SubtasksLocked());
  }

  final Subtask? subtask = task.subtaskById(subtaskId);
  if (subtask == null) {
    throw ArgumentError.value(
      subtaskId,
      'subtaskId',
      'Task ${task.id} has no such subtask',
    );
  }
  if (subtask.status == target) {
    return Ok<Task, RuleViolation>(task);
  }

  return Ok<Task, RuleViolation>(
    _withSubtasks(
      task,
      task.subtasks
          .map((Subtask s) => s.id == subtaskId ? s.withStatus(target, now) : s)
          .toList(),
      now,
    ),
  );
}

/// SUB-2, SUB-4, TODO-5, AC-3. The completion circle on a subtask in the To Do
/// list.
///
/// SUB-4: "When a Task is **not** `Done`, tapping a subtask's completion circle
/// in the To Do list toggles `Todo` ⇄ `Done`. A `Blocked` subtask does not
/// toggle."
///
/// SUB-2: tapping a locked subtask's circle does nothing, and the refusal
/// carries the one-line hint. [SubtaskBlocked] is silent, like [TaskBlocked].
Result<Task, RuleViolation> toggleSubtaskCompletion(
  Task task,
  String subtaskId,
  DateTime now,
) {
  final RuleViolation? blocked = editabilityViolation(task);
  if (blocked != null) {
    return Err<Task, RuleViolation>(blocked);
  }
  if (task.subtaskStatusesLocked) {
    return const Err<Task, RuleViolation>(SubtasksLocked());
  }

  final Subtask? subtask = task.subtaskById(subtaskId);
  if (subtask == null) {
    throw ArgumentError.value(
      subtaskId,
      'subtaskId',
      'Task ${task.id} has no such subtask',
    );
  }

  return switch (subtask.status) {
    TaskStatus.blocked => const Err<Task, RuleViolation>(SubtaskBlocked()),
    TaskStatus.todo => setSubtaskStatus(task, subtaskId, TaskStatus.done, now),
    TaskStatus.done => setSubtaskStatus(task, subtaskId, TaskStatus.todo, now),
  };
}

/// SUB-8, SUB-9, TASKFORM-2, AC-5. Appends a new `Todo` subtask.
///
/// SUB-8: "Adding a subtask to a `Done` Task is **forbidden**." The UI hides
/// the affordance (TASKFORM-5); this is the rule that makes the state
/// unreachable rather than merely unrendered.
///
/// New subtasks are appended at the end of the list (TASKFORM-2) and are always
/// `Todo` (§3.4).
///
/// §11.4.1 gives this the signature `addSubtask(Task, String name, DateTime
/// now)`, but §3.4 requires a generated UUIDv7, so [ids] is a parameter here
/// and [name] is a validated [SubtaskName]. Recorded in `DECISIONS.md`
/// (D-M1-6).
Result<Task, RuleViolation> addSubtask(
  Task task,
  SubtaskName name,
  DateTime now,
  IdGenerator ids,
) {
  final RuleViolation? blocked = editabilityViolation(task);
  if (blocked != null) {
    return Err<Task, RuleViolation>(blocked);
  }
  if (task.status == TaskStatus.done) {
    return const Err<Task, RuleViolation>(SubtaskAddForbiddenWhileDone());
  }

  return Ok<Task, RuleViolation>(
    _withSubtasks(task, <Subtask>[
      ...task.subtasks,
      Subtask(
        id: ids.newId(),
        name: name,
        status: TaskStatus.todo,
        createdAt: now,
        updatedAt: now,
      ),
    ], now),
  );
}

/// SUB-1, TASKFORM-5, AC-4. Renames a subtask.
///
/// Available in every parent state: SUB-1 locks statuses only, and TASKFORM-5
/// keeps "subtask name fields, delete buttons and drag handles" enabled while
/// the Task is `Done`.
Result<Task, RuleViolation> renameSubtask(
  Task task,
  String subtaskId,
  SubtaskName name,
  DateTime now,
) {
  final RuleViolation? blocked = editabilityViolation(task);
  if (blocked != null) {
    return Err<Task, RuleViolation>(blocked);
  }
  if (task.subtaskById(subtaskId) == null) {
    throw ArgumentError.value(
      subtaskId,
      'subtaskId',
      'Task ${task.id} has no such subtask',
    );
  }

  return Ok<Task, RuleViolation>(
    _withSubtasks(
      task,
      task.subtasks
          .map(
            (Subtask s) =>
                s.id == subtaskId ? s.copyWith(name: name, updatedAt: now) : s,
          )
          .toList(),
      now,
    ),
  );
}

/// SUB-7, TASKFORM-5, AC-4. Hard-deletes a subtask.
///
/// "Deleting a subtask is a hard delete; subtasks have no soft-delete flag and
/// are not recoverable." Available in every parent state (TASKFORM-5).
///
/// Removing the last not-`Done` subtask does not complete the parent —
/// STATUS-3 forbids a status changing as a side effect of another action.
Result<Task, RuleViolation> removeSubtask(
  Task task,
  String subtaskId,
  DateTime now,
) {
  final RuleViolation? blocked = editabilityViolation(task);
  if (blocked != null) {
    return Err<Task, RuleViolation>(blocked);
  }
  if (task.subtaskById(subtaskId) == null) {
    throw ArgumentError.value(
      subtaskId,
      'subtaskId',
      'Task ${task.id} has no such subtask',
    );
  }

  return Ok<Task, RuleViolation>(
    _withSubtasks(
      task,
      task.subtasks.where((Subtask s) => s.id != subtaskId).toList(),
      now,
    ),
  );
}

/// TASKFORM-2, TASKFORM-5. Moves the subtask at [from] to index [to].
///
/// "Order is user-visible and user-controlled" (§3.3), and §11.5.1 stores it in
/// an explicit `sort_index` rather than deriving it from insertion order or id.
///
/// Reordering moves the parent's `updatedAt` but leaves the subtasks' own
/// timestamps alone: nothing about any individual subtask changed. Recorded in
/// `DECISIONS.md` (D-M1-7).
Result<Task, RuleViolation> reorderSubtasks(
  Task task,
  int from,
  int to,
  DateTime now,
) {
  final RuleViolation? blocked = editabilityViolation(task);
  if (blocked != null) {
    return Err<Task, RuleViolation>(blocked);
  }

  RangeError.checkValidIndex(from, task.subtasks, 'from');
  RangeError.checkValidIndex(to, task.subtasks, 'to');
  if (from == to) {
    return Ok<Task, RuleViolation>(task);
  }

  final List<Subtask> reordered = List<Subtask>.of(task.subtasks);
  reordered.insert(to, reordered.removeAt(from));
  return Ok<Task, RuleViolation>(_withSubtasks(task, reordered, now));
}

/// §3.3. Rebuilds [task] with [subtasks], moving its `updatedAt` to [now].
Task _withSubtasks(Task task, List<Subtask> subtasks, DateTime now) =>
    task.copyWith(subtasks: subtasks, updatedAt: now);

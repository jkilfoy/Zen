/// §4.1, §4.2, §4.5, §4.6. Every rule that acts on a whole Task.
///
/// §11.4.1: each row of the §4.2 transition table is a function returning
/// [Result], and therefore a two-line test. None of them touches the clock —
/// the instant arrives as a parameter (§11.11).
library;

import '../ids/id_generator.dart';
import '../model/enums.dart';
import '../model/item_name.dart';
import '../model/item_text.dart';
import '../model/subtask.dart';
import '../model/tag.dart';
import '../model/task.dart';
import '../result.dart';
import 'name_rules.dart';

/// STATUS-4, DEL-1. The refusal for editing a Task that is archived or deleted,
/// or `null` when it may be edited.
///
/// STATUS-4: "An archived Task cannot change status. To reopen it, the user
/// first un-archives it." SEARCH-3 opens a deleted Task read-only with only a
/// `"Restore"` action, so the same holds there.
RuleViolation? editabilityViolation(Task task) {
  if (task.isDeleted) {
    return const DeletedTaskImmutable();
  }
  if (task.isArchived) {
    return const ArchivedTaskImmutable();
  }
  return null;
}

/// §4.1, CREATE-2, CREATE-3. Creates a Task from a valid name.
///
/// "A Task is created from a valid `name` alone. `tags`, `description` and
/// `subtasks` are optional. `status` defaults to `Todo`." Creation is blocked
/// if the name collides with an active Task (NAME-8).
///
/// CREATE-4 — durable persistence before the UI reports success — is the
/// repository's job (§11.4.6), not this function's.
Result<Task, RuleViolation> createTask({
  required ItemName name,
  required DateTime now,
  required IdGenerator ids,
  Iterable<Tag> tags = const <Tag>[],
  ItemText description = ItemText.empty,
  List<Subtask> subtasks = const <Subtask>[],
  Set<String> activeTaskNormalizedNames = const <String>{},
}) {
  final Result<ItemName, RuleViolation> available = checkNameAvailable(
    name: name,
    kind: ItemKind.task,
    activeNormalizedNames: activeTaskNormalizedNames,
  );
  if (available case Err<ItemName, RuleViolation>(:final RuleViolation error)) {
    return Err<Task, RuleViolation>(error);
  }

  return Ok<Task, RuleViolation>(
    Task(
      id: ids.newId(),
      name: name,
      tags: dedupeTags(tags),
      description: description,
      status: TaskStatus.todo,
      subtasks: subtasks,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

/// §4.2, row 1. The completion circle on a `Todo` Task.
///
/// Guard: all subtasks `Done`, or no subtasks. Otherwise the task does not
/// change and [IncompleteSubtasks] carries the popup copy (AC-1).
///
/// STATUS-2: completing the last open subtask does **not** auto-complete the
/// parent — this is the only thing that does, and the user invokes it.
Result<Task, RuleViolation> completeTask(Task task, DateTime now) {
  final RuleViolation? blocked = editabilityViolation(task);
  if (blocked != null) {
    return Err<Task, RuleViolation>(blocked);
  }
  if (task.status == TaskStatus.blocked) {
    return const Err<Task, RuleViolation>(TaskBlocked());
  }
  if (task.status == TaskStatus.done) {
    return Ok<Task, RuleViolation>(task);
  }
  if (!task.allSubtasksDone) {
    return const Err<Task, RuleViolation>(IncompleteSubtasks());
  }
  return Ok<Task, RuleViolation>(task.withStatus(TaskStatus.done, now));
}

/// §4.2, row 3. The completion circle on a `Done` Task.
///
/// Clears `completedAt` and unlocks the subtask statuses (SUB-3), which keep
/// the values they had.
///
/// §11.4.1 gives this the signature `reopenTask(Task task)`, but §3.3 requires
/// `updatedAt` to move on every user edit, so [now] is a parameter here.
/// Recorded in `DECISIONS.md` (D-M1-6).
Result<Task, RuleViolation> reopenTask(Task task, DateTime now) {
  final RuleViolation? blocked = editabilityViolation(task);
  if (blocked != null) {
    return Err<Task, RuleViolation>(blocked);
  }
  if (task.status == TaskStatus.blocked) {
    return const Err<Task, RuleViolation>(TaskBlocked());
  }
  if (task.status == TaskStatus.todo) {
    return Ok<Task, RuleViolation>(task);
  }
  return Ok<Task, RuleViolation>(task.withStatus(TaskStatus.todo, now));
}

/// §4.2, TODO-5, STATUS-1. The whole completion-circle column of the §4.2
/// table, as one function.
///
/// The circle toggles only between `Todo` and `Done`; `Blocked` is never
/// reachable from it (STATUS-1), and tapping a `Blocked` Task's circle changes
/// nothing (AC-7). [TaskBlocked] is silent — §4.2 allows a subtle nudge
/// animation and no copy.
Result<Task, RuleViolation> toggleTaskCompletion(Task task, DateTime now) =>
    switch (task.status) {
      TaskStatus.todo => completeTask(task, now),
      TaskStatus.done => reopenTask(task, now),
      TaskStatus.blocked => const Err<Task, RuleViolation>(TaskBlocked()),
    };

/// §4.2, last row, TASKFORM-4, TASKFORM-6. The status control on the Edit Task
/// screen, which may set any of the three values.
///
/// "Target `Done` requires all subtasks `Done`. If not, show the same popup and
/// leave the status unchanged." INV-1 is maintained by [Task.withStatus].
///
/// STATUS-3: nothing else changes as a side effect.
Result<Task, RuleViolation> setTaskStatus(
  Task task,
  TaskStatus target,
  DateTime now,
) {
  final RuleViolation? blocked = editabilityViolation(task);
  if (blocked != null) {
    return Err<Task, RuleViolation>(blocked);
  }
  if (task.status == target) {
    return Ok<Task, RuleViolation>(task);
  }
  if (target == TaskStatus.done && !task.allSubtasksDone) {
    return const Err<Task, RuleViolation>(IncompleteSubtasks());
  }
  return Ok<Task, RuleViolation>(task.withStatus(target, now));
}

/// EOD-2, EOD-6. Archives [task] at [boundary].
///
/// [boundary] is the End-of-Day instant the Task crossed, from
/// `archiveBoundaryAfter`, not the instant the sweep ran (AC-6).
///
/// Only a `Done`, unarchived Task can archive (INV-3). The sweeper selects on
/// exactly that, so anything else is programmer error and asserts rather than
/// returning a [Result] (§11.4.1).
Task archiveTask(Task task, DateTime boundary) {
  assert(
    task.status == TaskStatus.done,
    'INV-3: only a Done task can be archived, not ${task.status}',
  );
  assert(!task.isArchived, 'Task ${task.id} is already archived');
  return task.archived(boundary);
}

/// ARCH-3, ARCH-4, NAME-9, AC-10. Returns an archived Task to the To Do list.
///
/// "Unarchiving sets `isArchived = false`, clears `archivedAt`, sets status to
/// `Todo` and clears `completedAt`. The Task then reappears in the To Do list
/// with its subtask statuses unlocked."
///
/// Blocked when an active Task already holds the name (ARCH-4). The check runs
/// only when the result would actually be active — a Task that is both archived
/// and deleted stays hidden either way, so it reserves no name.
Result<Task, RuleViolation> unarchiveTask(
  Task task,
  DateTime now, {
  Set<String> activeTaskNormalizedNames = const <String>{},
}) {
  if (!task.isArchived) {
    return Ok<Task, RuleViolation>(task);
  }
  final Task candidate = task.unarchived(now);
  return _guardReactivation(candidate, activeTaskNormalizedNames);
}

/// DEL-1, DEL-4. Soft-deletes [task].
///
/// "Deleting a Task is a **soft delete**. It sets `isDeleted = true` and
/// `deletedAt = now`." Tasks are never hard-deleted (principle 1.2.4).
/// Confirmation is `settings.confirmDestructive`'s business, in the UI.
Result<Task, RuleViolation> softDeleteTask(Task task, DateTime now) {
  if (task.isDeleted) {
    return Ok<Task, RuleViolation>(task);
  }
  return Ok<Task, RuleViolation>(task.softDeleted(now));
}

/// DEL-2, NAME-9, AC-10. Restores a soft-deleted Task from Search.
///
/// "Restoring clears `isDeleted` and `deletedAt` and leaves the status as it
/// was. If the status was `Done`, the next archive sweep will archive it. If an
/// active Task already holds the name, restoring is prohibited per NAME-9."
///
/// As with [unarchiveTask], the name check runs only when the result would be
/// active: restoring a Task that is also archived returns it to the archive,
/// where it reserves no name (NAME-7).
Result<Task, RuleViolation> restoreTask(
  Task task,
  DateTime now, {
  Set<String> activeTaskNormalizedNames = const <String>{},
}) {
  if (!task.isDeleted) {
    return Ok<Task, RuleViolation>(task);
  }
  final Task candidate = task.restored(now);
  return _guardReactivation(candidate, activeTaskNormalizedNames);
}

/// NAME-9. Lets [candidate] through unless it would join the active set under a
/// name an active Task already holds.
Result<Task, RuleViolation> _guardReactivation(
  Task candidate,
  Set<String> activeTaskNormalizedNames,
) {
  if (!candidate.isActive) {
    return Ok<Task, RuleViolation>(candidate);
  }
  final Result<ItemName, RuleViolation> allowed = checkReactivationAllowed(
    name: candidate.name,
    activeTaskNormalizedNames: activeTaskNormalizedNames,
  );
  if (allowed case Err<ItemName, RuleViolation>(:final RuleViolation error)) {
    return Err<Task, RuleViolation>(error);
  }
  return Ok<Task, RuleViolation>(candidate);
}

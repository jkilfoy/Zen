/// §11.4.1. Rules return values; exceptions are reserved for programmer error.
///
/// Every row of the §4.2 transition table, and every validation in §3.1 and
/// §3.5, is a function returning [Result]. The UI renders
/// [RuleViolation.message]; it never composes its own copy.
library;

import 'package:meta/meta.dart';

/// The outcome of a rule: either an [Ok] value or an [Err] violation.
@immutable
sealed class Result<T, E> {
  /// Const superclass constructor for the two variants.
  const Result();

  /// Whether this is an [Ok].
  bool get isOk => this is Ok<T, E>;

  /// Whether this is an [Err].
  bool get isErr => this is Err<T, E>;

  /// The value if this is an [Ok], otherwise `null`.
  T? get valueOrNull => switch (this) {
    Ok<T, E>(:final T value) => value,
    Err<T, E>() => null,
  };

  /// The error if this is an [Err], otherwise `null`.
  E? get errorOrNull => switch (this) {
    Ok<T, E>() => null,
    Err<T, E>(:final E error) => error,
  };

  /// The value if this is an [Ok]; throws [StateError] otherwise.
  ///
  /// Intended for tests and for call sites that have already established
  /// success. Production code should pattern-match instead.
  T unwrap() => switch (this) {
    Ok<T, E>(:final T value) => value,
    Err<T, E>(:final E error) => throw StateError('Unwrapped an Err: $error'),
  };

  /// Applies [onOk] or [onErr] depending on the variant.
  R fold<R>(R Function(T value) onOk, R Function(E error) onErr) =>
      switch (this) {
        Ok<T, E>(:final T value) => onOk(value),
        Err<T, E>(:final E error) => onErr(error),
      };
}

/// A successful [Result] carrying a [value].
@immutable
final class Ok<T, E> extends Result<T, E> {
  /// Wraps [value] as a success.
  const Ok(this.value);

  /// The produced value.
  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T, E> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok<T, E>, value);

  @override
  String toString() => 'Ok($value)';
}

/// A failed [Result] carrying an [error].
@immutable
final class Err<T, E> extends Result<T, E> {
  /// Wraps [error] as a failure.
  const Err(this.error);

  /// The reason the rule refused.
  final E error;

  @override
  bool operator ==(Object other) => other is Err<T, E> && other.error == error;

  @override
  int get hashCode => Object.hash(Err<T, E>, error);

  @override
  String toString() => 'Err($error)';
}

/// §11.4.1. A rule's refusal, carrying the exact user-facing copy.
///
/// Where the specification gives copy verbatim (§3.1, §4.2, §5.9), [message]
/// reproduces it exactly (§0.5). Where the specification is silent, the copy
/// was supplied by the owner and is recorded in `DECISIONS.md` (D-M1-3).
///
/// Some violations are deliberately silent: §4.2 says tapping a `Blocked`
/// task's circle produces no change and at most a nudge animation, and SUB-4
/// says the same for a `Blocked` subtask. Those carry an empty [message], and
/// [hasMessage] is how the UI tells the two cases apart.
@immutable
sealed class RuleViolation {
  /// Const superclass constructor.
  const RuleViolation();

  /// The exact copy to show the user, or `''` for a silent violation.
  String get message;

  /// Whether this violation has copy to render. See [message].
  bool get hasMessage => message.isNotEmpty;

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => '$runtimeType(${message.isEmpty ? 'silent' : message})';
}

// ---------------------------------------------------------------------------
// §4.2 and §4.3 — task and subtask status
// ---------------------------------------------------------------------------

/// §4.2, TASKFORM-4, TASKFORM-6. Completing a task whose subtasks are not all
/// `Done`.
final class IncompleteSubtasks extends RuleViolation {
  /// Const constructor.
  const IncompleteSubtasks();

  @override
  String get message =>
      'This task has incomplete subtasks. Complete the subtasks before '
      'finishing this task.';
}

/// SUB-1, SUB-2, TASKFORM-5. Changing a subtask's status while its parent task
/// is `Done`.
final class SubtasksLocked extends RuleViolation {
  /// Const constructor.
  const SubtasksLocked();

  @override
  String get message =>
      "Set the task back to Todo to change its subtasks' status.";
}

/// SUB-8. Adding a subtask to a `Done` task.
///
/// Unreachable through the MVP UI, which hides the `"Add subtask"` row while
/// the status control reads `Done` (TASKFORM-5). The copy exists because
/// §11.4.1 requires every violation to carry a message; it is not from the
/// specification (D-M1-3).
final class SubtaskAddForbiddenWhileDone extends RuleViolation {
  /// Const constructor.
  const SubtaskAddForbiddenWhileDone();

  @override
  String get message => 'Set the task back to Todo to add a subtask.';
}

/// §4.2, STATUS-1, AC-7. The completion circle was tapped on a `Blocked` task.
///
/// Silent: §4.2 specifies "No change" and at most a subtle nudge animation, so
/// there is no copy to render. See [RuleViolation.hasMessage].
final class TaskBlocked extends RuleViolation {
  /// Const constructor.
  const TaskBlocked();

  @override
  String get message => '';
}

/// SUB-4. The completion circle was tapped on a `Blocked` subtask.
///
/// Silent, for the same reason as [TaskBlocked].
final class SubtaskBlocked extends RuleViolation {
  /// Const constructor.
  const SubtaskBlocked();

  @override
  String get message => '';
}

/// STATUS-4. An archived task cannot change status, or be otherwise edited,
/// until it is unarchived (ARCH-3).
///
/// Unreachable through the MVP UI, which opens archived tasks read-only.
/// Copy supplied by the owner (D-M1-3).
final class ArchivedTaskImmutable extends RuleViolation {
  /// Const constructor.
  const ArchivedTaskImmutable();

  @override
  String get message => 'Unarchive this task before changing its status.';
}

/// DEL-1, SEARCH-3. A soft-deleted task cannot be edited until it is restored.
///
/// Unreachable through the MVP UI, which opens deleted tasks read-only with a
/// `"Restore"` action. Copy supplied by the owner (D-M1-3).
final class DeletedTaskImmutable extends RuleViolation {
  /// Const constructor.
  const DeletedTaskImmutable();

  @override
  String get message => 'Restore this task before changing its status.';
}

// ---------------------------------------------------------------------------
// §3.1 — names
// ---------------------------------------------------------------------------

/// NAME-2. A name shorter than three grapheme clusters after trimming.
final class NameTooShort extends RuleViolation {
  /// Const constructor.
  const NameTooShort();

  @override
  String get message => 'Name must be at least 3 characters.';
}

/// NAME-3. A name longer than 1000 grapheme clusters.
final class NameTooLong extends RuleViolation {
  /// Const constructor.
  const NameTooLong();

  @override
  String get message => 'Name must be 1000 characters or fewer.';
}

/// NAME-4. A name containing a line break.
///
/// The Add and Edit screens make Enter submit the form rather than insert a
/// newline, so this is reachable only by pasting. Copy supplied by the owner
/// (D-M1-3).
final class NameContainsLineBreak extends RuleViolation {
  /// Const constructor.
  const NameContainsLineBreak();

  @override
  String get message => 'Name cannot contain line breaks.';
}

/// NAME-6, NAME-8. An active Idea already holds this name.
final class IdeaNameCollision extends RuleViolation {
  /// Const constructor.
  const IdeaNameCollision();

  @override
  String get message => 'An idea with this name already exists.';
}

/// NAME-6, NAME-8. An active Task already holds this name.
final class TaskNameCollision extends RuleViolation {
  /// Const constructor.
  const TaskNameCollision();

  @override
  String get message => 'A task with this name already exists.';
}

/// NAME-9, ARCH-4, AC-10. Restoring or unarchiving a Task whose name is held by
/// an active Task.
///
/// The user is not offered a rename as a way around this (NAME-9); they must
/// deal with the active Task first.
final class ActiveTaskHoldsName extends RuleViolation {
  /// Const constructor.
  const ActiveTaskHoldsName();

  @override
  String get message =>
      'There is already an active task with this name in your To Do list. '
      'Complete and archive the active task in order to restore this one to '
      'your To Do list.';
}

// ---------------------------------------------------------------------------
// §3.4 — subtask names
// ---------------------------------------------------------------------------

/// §3.4. A subtask name that is empty after trimming.
///
/// Copy supplied by the owner (D-M1-3).
final class SubtaskNameEmpty extends RuleViolation {
  /// Const constructor.
  const SubtaskNameEmpty();

  @override
  String get message => 'Subtask name cannot be empty.';
}

/// §3.4. A subtask name longer than 1000 grapheme clusters.
///
/// Copy supplied by the owner (D-M1-3).
final class SubtaskNameTooLong extends RuleViolation {
  /// Const constructor.
  const SubtaskNameTooLong();

  @override
  String get message => 'Subtask name must be 1000 characters or fewer.';
}

/// §3.4. A subtask name containing a line break.
///
/// Copy supplied by the owner (D-M1-3).
final class SubtaskNameContainsLineBreak extends RuleViolation {
  /// Const constructor.
  const SubtaskNameContainsLineBreak();

  @override
  String get message => 'Subtask name cannot contain line breaks.';
}

// ---------------------------------------------------------------------------
// §3.5 — tags
// ---------------------------------------------------------------------------

/// TAG-2. A tag containing whitespace.
///
/// Copy supplied by the owner (D-M1-3).
final class TagContainsWhitespace extends RuleViolation {
  /// Const constructor.
  const TagContainsWhitespace();

  @override
  String get message => 'Tags cannot contain spaces.';
}

/// TAG-3. A tag longer than 32 grapheme clusters.
///
/// Copy supplied by the owner (D-M1-3).
final class TagTooLong extends RuleViolation {
  /// Const constructor.
  const TagTooLong();

  @override
  String get message => 'Tags must be 32 characters or fewer.';
}

/// TAG-3. A tag that is empty after trimming and stripping a leading `@`.
///
/// Silent: the chip input simply does not add a chip, which is the simplest
/// behaviour consistent with §3.5 (D-M1-4).
final class TagEmpty extends RuleViolation {
  /// Const constructor.
  const TagEmpty();

  @override
  String get message => '';
}

// ---------------------------------------------------------------------------
// §3.2, §3.3 — free text
// ---------------------------------------------------------------------------

/// §3.2. An Idea's context longer than 10,000 grapheme clusters.
///
/// Copy supplied by the owner (D-M1-3).
final class ContextTooLong extends RuleViolation {
  /// Const constructor.
  const ContextTooLong();

  @override
  String get message => 'Context must be 10,000 characters or fewer.';
}

/// §3.3. A Task's description longer than 10,000 grapheme clusters.
///
/// Copy supplied by the owner (D-M1-3).
final class DescriptionTooLong extends RuleViolation {
  /// Const constructor.
  const DescriptionTooLong();

  @override
  String get message => 'Description must be 10,000 characters or fewer.';
}

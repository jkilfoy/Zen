/// §11.7. The Task commands the screens invoke.
///
/// As with `IdeaActions`, each method reads what a rule in `zen_domain` needs,
/// calls it, and persists what it returns. Every refusal is a [RuleViolation] a
/// rule produced; none is decided here.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zen_domain/zen_domain.dart';

import 'app_providers.dart';

/// §11.7. The Task half of the composition root's command surface.
final class TaskActions {
  /// Wraps the repositories, the clock and the id generator the rules need.
  const TaskActions({
    required TaskRepository tasks,
    required ConversionService conversions,
    required Clock clock,
    required IdGenerator ids,
    // A named parameter may not begin with an underscore, so
    // `prefer_initializing_formals` is not available here or below.
    // ignore: prefer_initializing_formals
  }) : _tasks = tasks,
       // ignore: prefer_initializing_formals
       _conversions = conversions,
       // ignore: prefer_initializing_formals
       _clock = clock,
       // ignore: prefer_initializing_formals
       _ids = ids;

  final TaskRepository _tasks;
  final ConversionService _conversions;
  final Clock _clock;
  final IdGenerator _ids;

  /// §3. The instant a form uses for the timestamps it materializes.
  DateTime now() => _clock.nowUtc();

  /// §3. The id generator a form uses for subtasks it has just added.
  IdGenerator get ids => _ids;

  /// CREATE-2, CREATE-3, CREATE-4, TASKFORM-3.
  Future<Result<Task, RuleViolation>> create({
    required ItemName name,
    required List<Tag> tags,
    required ItemText description,
    required List<Subtask> subtasks,
  }) async {
    final Result<Task, RuleViolation> drafted = createTask(
      name: name,
      now: _clock.nowUtc(),
      ids: _ids,
      tags: tags,
      description: description,
      subtasks: subtasks,
      activeTaskNormalizedNames: await _tasks.activeNormalizedNames(),
    );
    return switch (drafted) {
      Err<Task, RuleViolation>() => drafted,
      Ok<Task, RuleViolation>(:final Task value) => _tasks.create(value),
    };
  }

  /// TASKFORM-3, TASKFORM-6, NAME-8. Saves an edit made on the Edit Task
  /// screen, including the whole subtask list.
  Future<Result<Task, RuleViolation>> save(
    Task task, {
    required ItemName name,
    required TaskStatus status,
    required List<Tag> tags,
    required ItemText description,
    required List<Subtask> subtasks,
  }) async {
    final Result<Task, RuleViolation> edited = updateTask(
      task,
      now: _clock.nowUtc(),
      name: name,
      status: status,
      tags: tags,
      description: description,
      subtasks: subtasks,
      activeTaskNormalizedNames: await _tasks.activeNormalizedNames(),
    );
    return switch (edited) {
      Err<Task, RuleViolation>() => edited,
      Ok<Task, RuleViolation>(:final Task value) => _tasks.update(value),
    };
  }

  /// §4.2, TODO-5, STATUS-1. The completion circle on a Task row.
  Future<Result<Task, RuleViolation>> toggleCompletion(Task task) =>
      _persist(toggleTaskCompletion(task, _clock.nowUtc()));

  /// SUB-2, SUB-4, TODO-5. The completion circle on a subtask row.
  Future<Result<Task, RuleViolation>> toggleSubtask(
    Task task,
    String subtaskId,
  ) => _persist(toggleSubtaskCompletion(task, subtaskId, _clock.nowUtc()));

  /// DEL-1, DEL-4, TASKFORM-7.
  Future<Result<Task, RuleViolation>> softDelete(Task task) =>
      _tasks.softDelete(task.id, _clock.nowUtc());

  /// ARCH-3, ARCH-4, NAME-9.
  Future<Result<Task, RuleViolation>> unarchive(Task task) =>
      _tasks.unarchive(task.id, _clock.nowUtc());

  /// DEL-2, SEARCH-3, NAME-9.
  Future<Result<Task, RuleViolation>> restore(Task task) =>
      _tasks.restore(task.id, _clock.nowUtc());

  /// CONVERT-1. The Create Task screen's pre-filled draft.
  ///
  /// CONVERT-4 writes nothing until the user confirms, so this only builds the
  /// values the form starts from.
  Task draftFrom(Idea idea) => draftTaskFromIdea(idea, _clock.nowUtc(), _ids);

  /// CONVERT-3, CONVERT-4, AC-11. Commits a conversion in one transaction.
  ///
  /// The draft is rebuilt at the confirm instant, because §3.3 makes a
  /// converted Task's `createdAt` "the conversion time" and CONVERT-4 says
  /// nothing is written before this press.
  Future<Result<Task, RuleViolation>> convert(
    Idea idea, {
    required ItemName name,
    required List<Tag> tags,
    required ItemText description,
    required List<Subtask> subtasks,
  }) async {
    final DateTime now = _clock.nowUtc();
    final Task draft = draftTaskFromIdea(idea, now, _ids).copyWith(
      name: name,
      tags: tags,
      description: description,
      subtasks: subtasks,
    );
    final Result<Task, RuleViolation> checked = checkConversionDraft(
      draft,
      activeTaskNormalizedNames: await _tasks.activeNormalizedNames(),
    );
    return switch (checked) {
      Err<Task, RuleViolation>() => checked,
      Ok<Task, RuleViolation>(:final Task value) => _conversions.convert(
        idea,
        value,
        now,
      ),
    };
  }

  /// NAME-8's `"Open it"` link: the active Task holding [name], if any.
  Future<Task?> findColliding(ItemName name) =>
      _tasks.findActiveByNormalizedName(name.normalized);

  Future<Result<Task, RuleViolation>> _persist(
    Result<Task, RuleViolation> ruled,
  ) async => switch (ruled) {
    Err<Task, RuleViolation>() => ruled,
    Ok<Task, RuleViolation>(:final Task value) => _tasks.update(value),
  };
}

/// §11.7. The Task commands, wired to the repositories.
final Provider<TaskActions> taskActionsProvider = Provider<TaskActions>(
  (Ref ref) => TaskActions(
    tasks: ref.watch(taskRepositoryProvider),
    conversions: ref.watch(conversionServiceProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
  ),
);

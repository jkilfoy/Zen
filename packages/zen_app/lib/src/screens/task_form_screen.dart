/// §5.4. `SCR-TASK-FORM`: Add Task, Edit Task and Create Task from Idea.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zen_domain/zen_domain.dart';

import '../providers/app_providers.dart';
import '../providers/task_actions.dart';
import '../router.dart';
import '../widgets/advanced_details.dart';
import '../widgets/confirmations.dart';
import '../widgets/name_field.dart';
import '../widgets/subtask_editor.dart';
import '../widgets/tag_input.dart';

/// §5.4. The three modes. "The screen has three modes with the same layout:
/// Add, Edit, and Convert (pre-filled per §4.4)."
enum TaskFormMode {
  /// A new Task from blank.
  add,

  /// An existing Task.
  edit,

  /// §4.4. A new Task pre-filled from an Idea, which the save consumes.
  convert;

  /// TASKFORM-3. "The primary button is `"Add Task"` (Add), `"Save"` (Edit) or
  /// `"Create Task"` (Convert)."
  String get primaryLabel => switch (this) {
    TaskFormMode.add => 'Add Task',
    TaskFormMode.edit => 'Save',
    TaskFormMode.convert => 'Create Task',
  };

  /// The screen's title.
  String get title => switch (this) {
    TaskFormMode.add => 'Add Task',
    TaskFormMode.edit => 'Edit Task',
    TaskFormMode.convert => 'Create Task',
  };
}

/// §5.4. "It is the **only** place subtasks are created or edited" (SUB-9).
class TaskFormScreen extends ConsumerStatefulWidget {
  /// §5.4, Add mode.
  const TaskFormScreen.add({super.key})
    : mode = TaskFormMode.add,
      taskId = null,
      ideaId = null;

  /// §5.4, Edit mode, for the Task [taskId].
  ///
  /// ARCH-3 and SEARCH-3 open an archived or deleted Task through the same
  /// route; the screen reads its state and renders read-only.
  const TaskFormScreen.edit({required String this.taskId, super.key})
    : mode = TaskFormMode.edit,
      ideaId = null;

  /// §4.4, Convert mode, pre-filled from the Idea [ideaId].
  const TaskFormScreen.convert({required String this.ideaId, super.key})
    : mode = TaskFormMode.convert,
      taskId = null;

  /// Which of the three modes this is.
  final TaskFormMode mode;

  /// The Task being edited, in Edit mode.
  final String? taskId;

  /// The Idea being converted, in Convert mode.
  final String? ideaId;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final List<SubtaskDraft> _subtasks = <SubtaskDraft>[];
  List<Tag> _tags = const <Tag>[];
  TaskStatus _status = TaskStatus.todo;
  Task? _loaded;
  Idea? _source;
  bool _dirty = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    for (final SubtaskDraft draft in _subtasks) {
      draft.dispose();
    }
    super.dispose();
  }

  /// TASKFORM-5, SUB-1. The lock follows the *form's* status control, not the
  /// saved Task's: "Changing the status control to `Todo` or `Blocked` unlocks
  /// the status controls and restores the `"Add subtask"` row immediately,
  /// before saving."
  bool get _locked => _status == TaskStatus.done;

  /// ARCH-3, SEARCH-3. Archived and deleted Tasks open read-only.
  bool get _readOnly => _loaded != null && !_loaded!.isActive;

  void _adoptTask(Task task) {
    if (_loaded != null) {
      return;
    }
    _loaded = task;
    _name.text = task.name.value;
    _description.text = task.description.value;
    _tags = task.tags;
    _status = task.status;
    _subtasks.addAll(task.subtasks.map(SubtaskDraft.of));
  }

  /// CONVERT-1. Pre-fills from the Idea. "The Idea's `timeframe` is discarded."
  void _adoptIdea(Idea idea) {
    if (_source != null) {
      return;
    }
    _source = idea;
    _name.text = idea.name.value;
    _description.text = idea.context.value;
    _tags = idea.tags;
    _status = TaskStatus.todo;
  }

  /// NAME-6, NAME-8, CONVERT-3. The names this Task must not collide with.
  ///
  /// NAME-7: only active Tasks reserve a name, which is exactly what
  /// [activeTasksProvider] streams.
  Set<String> _otherNames(List<Task> active) => <String>{
    for (final Task task in active)
      if (task.id != _loaded?.id) task.name.normalized,
  };

  /// TASKFORM-3. The violation blocking the primary button, or `null`.
  RuleViolation? _nameViolation(List<Task> active, String raw) {
    final Result<ItemName, RuleViolation> parsed = ItemName.parse(raw);
    return switch (parsed) {
      Err<ItemName, RuleViolation>(:final RuleViolation error) => error,
      Ok<ItemName, RuleViolation>(:final ItemName value) =>
        _otherNames(active).contains(value.normalized)
            ? const TaskNameCollision()
            : null,
    };
  }

  void _addSubtask() => setState(() {
    _subtasks.add(SubtaskDraft.blank());
    _dirty = true;
  });

  /// §3.4, SUB-7. The drafts as [Subtask]s, or the first violation refusing
  /// one.
  ///
  /// A row the user opened and never typed in is dropped rather than refused
  /// (D-M4-6): an empty row is a subtask not yet begun, and SUB-7's hard delete
  /// makes discarding it the same thing the delete button would do.
  Result<List<Subtask>, RuleViolation> _materializeSubtasks() {
    final TaskActions actions = ref.read(taskActionsProvider);
    final DateTime now = actions.now();
    final List<Subtask> materialized = <Subtask>[];
    for (final SubtaskDraft draft in _subtasks) {
      if (draft.isBlank) {
        continue;
      }
      switch (draft.name) {
        case Err<SubtaskName, RuleViolation>(:final RuleViolation error):
          return Err<List<Subtask>, RuleViolation>(error);
        case Ok<SubtaskName, RuleViolation>(:final SubtaskName value):
          materialized.add(draft.materialize(value, now, actions.ids));
      }
    }
    return Ok<List<Subtask>, RuleViolation>(materialized);
  }

  Future<void> _submit() async {
    final Result<ItemName, RuleViolation> name = ItemName.parse(_name.text);
    if (name case Err<ItemName, RuleViolation>(:final RuleViolation error)) {
      await showViolation(context, error);
      return;
    }
    final Result<ItemText, RuleViolation> description =
        ItemText.parseDescription(_description.text);
    if (description case Err<ItemText, RuleViolation>(
      :final RuleViolation error,
    )) {
      await showViolation(context, error);
      return;
    }
    final Result<List<Subtask>, RuleViolation> subtasks =
        _materializeSubtasks();
    if (subtasks case Err<List<Subtask>, RuleViolation>(
      :final RuleViolation error,
    )) {
      await showViolation(context, error);
      return;
    }

    setState(() => _saving = true);
    final TaskActions actions = ref.read(taskActionsProvider);
    final Result<Task, RuleViolation> saved = switch (widget.mode) {
      TaskFormMode.add => await actions.create(
        name: name.unwrap(),
        tags: _tags,
        description: description.unwrap(),
        subtasks: subtasks.unwrap(),
      ),
      // CONVERT-4. Nothing was written before this press.
      TaskFormMode.convert => await actions.convert(
        _source!,
        name: name.unwrap(),
        tags: _tags,
        description: description.unwrap(),
        subtasks: subtasks.unwrap(),
      ),
      // TASKFORM-6. `updateTask` re-checks INV-2 as a defensive measure, so a
      // `Done` status with an incomplete subtask cannot be persisted by any
      // path, even one TASKFORM-4 and TASKFORM-5 should have made unreachable.
      TaskFormMode.edit => await actions.save(
        _loaded!,
        name: name.unwrap(),
        status: _status,
        tags: _tags,
        description: description.unwrap(),
        subtasks: subtasks.unwrap(),
      ),
    };
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);

    switch (saved) {
      // §11.5.5. The typed text stays on screen.
      case Err<Task, RuleViolation>(:final RuleViolation error):
        await showViolation(context, error);
      // TASKFORM-8. "After Add, Save, Convert or Delete, navigate to Review on
      // the To Do tab. After Add or Convert, scroll the new Task into view."
      case Ok<Task, RuleViolation>(:final Task value):
        _dirty = false;
        if (mounted) {
          context.go(
            Routes.reviewTab(
              ReviewTab.todo,
              highlight: widget.mode == TaskFormMode.edit ? null : value.id,
            ),
          );
        }
    }
  }

  /// TASKFORM-4. "Setting Status to Done while any subtask is not Done shows
  /// the incomplete-subtasks popup and leaves the status unchanged."
  Future<void> _setStatus(TaskStatus target) async {
    if (target == TaskStatus.done &&
        _subtasks.any(
          (SubtaskDraft draft) =>
              !draft.isBlank && draft.status != TaskStatus.done,
        )) {
      await showViolation(context, const IncompleteSubtasks());
      return;
    }
    setState(() {
      _status = target;
      _dirty = true;
    });
  }

  Future<void> _delete(Task task) async {
    final bool go = await confirmDelete(
      context,
      kind: ItemKind.task,
      confirmDestructive: ref.read(currentSettingsProvider).confirmDestructive,
    );
    if (!go || !mounted) {
      return;
    }
    final Result<Task, RuleViolation> deleted = await ref
        .read(taskActionsProvider)
        .softDelete(task);
    if (!mounted) {
      return;
    }
    switch (deleted) {
      case Err<Task, RuleViolation>(:final RuleViolation error):
        await showViolation(context, error);
      case Ok<Task, RuleViolation>():
        _dirty = false;
        if (mounted) {
          context.go(Routes.reviewTab(ReviewTab.todo));
        }
    }
  }

  /// ARCH-3, ARCH-4, SEARCH-3, NAME-9, AC-10.
  Future<void> _reactivate(Task task) async {
    final TaskActions actions = ref.read(taskActionsProvider);
    final Result<Task, RuleViolation> result = task.isDeleted
        ? await actions.restore(task)
        : await actions.unarchive(task);
    if (!mounted) {
      return;
    }
    switch (result) {
      case Err<Task, RuleViolation>(:final RuleViolation error):
        await showViolation(context, error);
      case Ok<Task, RuleViolation>():
        if (mounted) {
          context.go(Routes.reviewTab(ReviewTab.todo));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Task> active =
        ref.watch(activeTasksProvider).value ?? const <Task>[];

    if (widget.mode == TaskFormMode.edit) {
      // SEARCH-3 and ARCH-3 reach Tasks that are not in the To Do list, so the
      // lookup is over every Task this replica holds.
      final Task? found = (ref.watch(allTasksProvider).value ?? const <Task>[])
          .where((Task task) => task.id == widget.taskId)
          .firstOrNull;
      if (found == null) {
        return const _Missing(
          title: 'Edit Task',
          message: 'This task no longer exists.',
        );
      }
      _adoptTask(found);
    }
    if (widget.mode == TaskFormMode.convert) {
      final Idea? found = (ref.watch(ideasProvider).value ?? const <Idea>[])
          .where((Idea idea) => idea.id == widget.ideaId)
          .firstOrNull;
      if (found == null) {
        return const _Missing(
          title: 'Create Task',
          message: 'This idea no longer exists.',
        );
      }
      _adoptIdea(found);
    }

    final Task? loaded = _loaded;
    final RuleViolation? violation = _nameViolation(active, _name.text);
    // ARCH-4, NAME-9. Unarchive and Restore are blocked while an active Task
    // holds the name; the message is the one the rule produces.
    final bool nameHeld =
        loaded != null && _otherNames(active).contains(loaded.name.normalized);

    return PopScope<Object?>(
      // NAV-1, CONVERT-5. Leaving with unsaved changes asks; on Convert the
      // Idea is untouched either way, because nothing was written.
      canPop: !_dirty,
      onPopInvokedWithResult: (bool didPop, Object? _) async {
        if (didPop || !_dirty) {
          return;
        }
        final bool discard = await confirmDiscard(context);
        if (discard && context.mounted) {
          _dirty = false;
          _leave(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.mode.title)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              if (_readOnly)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    loaded!.isDeleted
                        ? 'This task is deleted. Restore it to edit it.'
                        : 'This task is archived. Unarchive it to edit it.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              // TASKFORM-1. Name, Status, Tags, Description, Subtasks.
              NameField(
                controller: _name,
                validate: (String raw) => _nameViolation(active, raw),
                readOnly: _readOnly,
                autofocus: widget.mode == TaskFormMode.add,
                onChanged: () => setState(() => _dirty = true),
                onSubmit: violation == null && !_readOnly ? _submit : null,
                collisionAction: violation is TaskNameCollision
                    ? TextButton(
                        onPressed: () => _openColliding(active),
                        child: const Text('Open it'),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              // TASKFORM-1. "Status (Edit mode only …)". In Add and Convert the
              // Task is always `Todo` (TASKFORM-2).
              if (widget.mode == TaskFormMode.edit) ...<Widget>[
                _StatusPicker(
                  value: _status,
                  enabled: !_readOnly,
                  onChanged: _setStatus,
                ),
                const SizedBox(height: 16),
              ],
              if (_readOnly)
                _ReadOnlyTags(tags: _tags)
              else
                TagInput(
                  tags: _tags,
                  onChanged: (List<Tag> next) => setState(() {
                    _tags = next;
                    _dirty = true;
                  }),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _description,
                readOnly: _readOnly,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                ),
                onChanged: (String _) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 24),
              SubtaskEditor(
                drafts: _subtasks,
                locked: _locked,
                // TASKFORM-2. The control is hidden in Add and Convert.
                showStatusControls: widget.mode == TaskFormMode.edit,
                readOnly: _readOnly,
                onAdd: _addSubtask,
                onRemove: (int index) => setState(() {
                  _subtasks.removeAt(index).dispose();
                  _dirty = true;
                }),
                onReorder: (int from, int to) => setState(() {
                  _subtasks.insert(to, _subtasks.removeAt(from));
                  _dirty = true;
                }),
                onChanged: () => setState(() => _dirty = true),
              ),
              const SizedBox(height: 24),
              if (_readOnly) ...<Widget>[
                // ARCH-3, SEARCH-3. One action, and NAME-9 may block it.
                FilledButton(
                  onPressed: nameHeld ? null : () => _reactivate(loaded!),
                  child: Text(loaded!.isDeleted ? 'Restore' : 'Unarchive'),
                ),
                if (nameHeld)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      const ActiveTaskHoldsName().message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ] else
                // TASKFORM-3. Disabled while the name is invalid, including on
                // a uniqueness collision.
                FilledButton(
                  onPressed: violation == null && !_saving ? _submit : null,
                  child: Text(widget.mode.primaryLabel),
                ),
              if (loaded != null) ...<Widget>[
                if (!_readOnly) ...<Widget>[
                  const SizedBox(height: 8),
                  // TASKFORM-7.
                  TextButton(
                    onPressed: () => _delete(loaded),
                    child: const Text('Delete'),
                  ),
                ],
                const SizedBox(height: 16),
                // TASKFORM-9.
                AdvancedDetails(rows: _advancedRows(loaded)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// TASKFORM-9. "Displays: `id`, `createdAt`, `updatedAt`, `completedAt`,
  /// `archivedAt`, `deletedAt`, and — when `sourceIdeaId` is set — a row
  /// `"Converted from idea"`."
  List<DetailRow> _advancedRows(Task task) => <DetailRow>[
    DetailRow('id', task.id, copyable: true),
    DetailRow.instant('createdAt', task.createdAt),
    DetailRow.instant('updatedAt', task.updatedAt),
    DetailRow.instant('completedAt', task.completedAt),
    DetailRow.instant('archivedAt', task.archivedAt),
    DetailRow.instant('deletedAt', task.deletedAt),
    if (task.sourceIdeaId case final String sourceId) ...<DetailRow>[
      const DetailRow('Converted from idea', ''),
      DetailRow('sourceIdeaId', sourceId, copyable: true),
      DetailRow.instant('sourceIdeaCreatedAt', task.sourceIdeaCreatedAt),
    ],
  ];

  /// NAME-8's `"Open it"` link.
  void _openColliding(List<Task> active) {
    final String? normalized = ItemName.parse(_name.text)
        .valueOrNull
        ?.normalized;
    final Task? other = active
        .where((Task task) => task.name.normalized == normalized)
        .firstOrNull;
    if (other != null) {
      _dirty = false;
      context.pushReplacement(Routes.editTask(other.id));
    }
  }

  /// CONVERT-5. "On cancel, or on Back … The app returns to the **Ideas tab**,
  /// from either entry point." Every other mode simply pops.
  void _leave(BuildContext context) {
    if (widget.mode == TaskFormMode.convert) {
      context.go(Routes.reviewTab(ReviewTab.ideas));
    } else {
      context.pop();
    }
  }
}

/// TASKFORM-1. "Status (Edit mode only: segmented control Todo / Blocked /
/// Done)."
class _StatusPicker extends StatelessWidget {
  const _StatusPicker({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final TaskStatus value;
  final bool enabled;
  final ValueChanged<TaskStatus> onChanged;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: SegmentedButton<TaskStatus>(
      segments: <ButtonSegment<TaskStatus>>[
        for (final MapEntry<TaskStatus, String> entry in statusLabels.entries)
          ButtonSegment<TaskStatus>(
            value: entry.key,
            label: Text(entry.value),
            enabled: enabled,
          ),
      ],
      selected: <TaskStatus>{value},
      showSelectedIcon: false,
      onSelectionChanged: (Set<TaskStatus> next) => onChanged(next.single),
    ),
  );
}

/// ARCH-3. The tags of a read-only Task, which has no chip input.
class _ReadOnlyTags extends StatelessWidget {
  const _ReadOnlyTags({required this.tags});

  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      children: <Widget>[
        for (final Tag tag in tags) Chip(label: Text(tag.display)),
      ],
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(child: Text(message)),
  );
}

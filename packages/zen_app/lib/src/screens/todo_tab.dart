/// §5.7. `SCR-TODO`: the To Do tab.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zen_domain/zen_domain.dart';

import '../providers/app_providers.dart';
import '../providers/task_actions.dart';
import '../router.dart';
import '../widgets/completion_circle.dart';
import '../widgets/confirmations.dart';
import '../widgets/highlight.dart';
import '../widgets/item_row.dart';

/// §5.7. TODO-1's visible Tasks, in TODO-2's order, with TODO-3's circles.
///
/// The list watches a Drift stream (§11.7), so a completion-circle tap updates
/// it without a manual refresh.
class TodoTab extends ConsumerStatefulWidget {
  /// Builds the tab, scrolling [highlight] into view if it is present.
  const TodoTab({this.highlight, super.key});

  /// TASKFORM-8. The id of a Task just added or converted.
  final String? highlight;

  @override
  ConsumerState<TodoTab> createState() => _TodoTabState();
}

class _TodoTabState extends ConsumerState<TodoTab> {
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};
  bool _scrolled = false;

  /// TASKFORM-8. "After Add or Convert, scroll the new Task into view."
  void _scrollToHighlight() {
    final String? id = widget.highlight;
    if (_scrolled || id == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      final BuildContext? target = _rowKeys[id]?.currentContext;
      if (target != null && mounted) {
        _scrolled = true;
        unawaited(Scrollable.ensureVisible(target, alignment: 0.3));
      }
    });
  }

  Future<void> _toggleTask(Task task) async {
    final Result<Task, RuleViolation> result = await ref
        .read(taskActionsProvider)
        .toggleCompletion(task);
    if (result case Err<Task, RuleViolation>(:final RuleViolation error)
        when mounted) {
      // AC-1's popup for incomplete subtasks; AC-7's Blocked tap is silent.
      await showViolation(context, error);
    }
  }

  Future<void> _toggleSubtask(Task task, Subtask subtask) async {
    final Result<Task, RuleViolation> result = await ref
        .read(taskActionsProvider)
        .toggleSubtask(task, subtask.id);
    if (result case Err<Task, RuleViolation>(:final RuleViolation error)
        when mounted) {
      // SUB-2, AC-3. A one-line hint rather than a dialog.
      showHint(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Task>> tasks = ref.watch(activeTasksProvider);
    final Settings settings = ref.watch(currentSettingsProvider);

    return tasks.when(
      loading: () => const SizedBox.shrink(),
      error: (Object error, StackTrace _) =>
          Center(child: Text('Could not read your tasks: $error')),
      data: (List<Task> visible) {
        _scrollToHighlight();
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          // TODO-6. The `"Archived tasks"` link sits below the last Task, so it
          // is one extra item rather than a footer widget.
          itemCount: visible.length + 1,
          separatorBuilder: (BuildContext context, int index) =>
              // ROW-4. A thin divider between items, and none before the link.
              index < visible.length - 1
              ? const Divider(height: 1)
              : const SizedBox(height: 16),
          itemBuilder: (BuildContext context, int index) {
            if (index == visible.length) {
              // REVIEW-3. "An empty To Do tab shows …"
              if (visible.isEmpty) {
                return const _Empty(
                  message: 'Nothing to do. Add a task from the home screen.',
                );
              }
              return const _ArchiveLink();
            }
            final Task task = visible[index];
            return BriefHighlight(
              active: task.id == widget.highlight,
              child: _TaskRow(
                key: _rowKeys.putIfAbsent(task.id, GlobalKey.new),
                task: task,
                strikethroughDone: settings.strikethroughDone,
                onToggleTask: () => _toggleTask(task),
                onToggleSubtask: (Subtask subtask) =>
                    _toggleSubtask(task, subtask),
              ),
            );
          },
        );
      },
    );
  }
}

/// §5.6, TODO-3, TODO-4. One Task and its subtasks.
class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.strikethroughDone,
    required this.onToggleTask,
    required this.onToggleSubtask,
    super.key,
  });

  final Task task;
  final bool strikethroughDone;
  final VoidCallback onToggleTask;
  final ValueChanged<Subtask> onToggleSubtask;

  @override
  Widget build(BuildContext context) => ItemRow(
    name: task.name.value,
    tags: task.tags,
    // ROW-3. Tapping the name or tag text opens Edit Task.
    onOpen: () => context.push(Routes.editTask(task.id)),
    // TODO-3. "Each Task row has a completion circle to the left of the name."
    leading: CompletionCircle(status: task.status, onTap: onToggleTask),
    // TODO-3. "The name is struck through if `settings.strikethroughDone`."
    struckThrough: task.status == TaskStatus.done && strikethroughDone,
    // TODO-4. "Subtasks are listed below the Task's tag line, indented one
    // step … All subtasks are shown, including Done ones."
    children: <Widget>[
      for (final Subtask subtask in task.subtasks)
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CompletionCircle(
                status: subtask.status,
                size: 18,
                // TODO-4, SUB-1. "When the parent is `Done`, the subtask
                // circles are rendered in a visibly disabled state."
                locked: task.subtaskStatusesLocked,
                onTap: () => onToggleSubtask(subtask),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    subtask.name.value,
                    // TODO-4. "A subtask name shows up to 2 lines with an
                    // ellipsis."
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      decoration:
                          subtask.status == TaskStatus.done && strikethroughDone
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// TODO-6. "Below the last Task is a link `"Archived tasks"`."
class _ArchiveLink extends StatelessWidget {
  const _ArchiveLink();

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => context.push(Routes.archive),
      child: const Text('Archived tasks'),
    ),
  );
}

/// REVIEW-3. The empty state, plus TODO-6's link, which is not conditional on
/// there being Tasks.
class _Empty extends StatelessWidget {
  const _Empty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      children: <Widget>[
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        const _ArchiveLink(),
      ],
    ),
  );
}

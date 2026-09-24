/// TASKFORM-2, TASKFORM-5. The subtask editor, and the drafts it edits.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zen_domain/zen_domain.dart';

/// TASKFORM-2. One row of the editor while it is being edited.
///
/// A draft rather than a [Subtask] because the form holds text the user is
/// still typing, which may not yet parse as a [SubtaskName] (§3.4). It becomes
/// a [Subtask] only at [materialize], on Save.
final class SubtaskDraft {
  /// A row for an existing [original], or a new one when it is `null`.
  SubtaskDraft({
    required this.original,
    required String name,
    TaskStatus? status,
  }) : controller = TextEditingController(text: name),
       status = status ?? original?.status ?? TaskStatus.todo;

  /// A row for an existing subtask.
  factory SubtaskDraft.of(Subtask subtask) =>
      SubtaskDraft(original: subtask, name: subtask.name.value);

  /// TASKFORM-2. "new subtasks are always `Todo`".
  factory SubtaskDraft.blank() =>
      SubtaskDraft(original: null, name: '', status: TaskStatus.todo);

  /// The subtask as it was loaded, or `null` for one the user just added.
  final Subtask? original;

  /// The editable name field's text.
  final TextEditingController controller;

  /// The row's status control.
  TaskStatus status;

  /// Whether this row would parse as a subtask at all.
  ///
  /// SUB-7 hard-deletes a subtask, and an empty row the user opened and never
  /// filled in is the same thing not yet begun: Save drops it rather than
  /// refusing (D-M4-6).
  bool get isBlank => controller.text.trim().isEmpty;

  /// §3.4. The parsed name, or the violation refusing it.
  Result<SubtaskName, RuleViolation> get name =>
      SubtaskName.parse(controller.text);

  /// Turns the draft back into a [Subtask], preserving what did not change.
  ///
  /// An untouched row returns its [original] unchanged, so a save that edited
  /// only the Task's own fields leaves every subtask's `updatedAt` where it
  /// was. INV-1 is [Subtask.withStatus]'s to maintain.
  Subtask materialize(SubtaskName parsed, DateTime now, IdGenerator ids) {
    final Subtask? existing = original;
    if (existing == null) {
      return Subtask(
        id: ids.newId(),
        name: parsed,
        status: status,
        createdAt: now,
        updatedAt: now,
        completedAt: status == TaskStatus.done ? now : null,
      );
    }
    Subtask next = existing;
    if (next.name != parsed) {
      next = next.copyWith(name: parsed, updatedAt: now);
    }
    if (next.status != status) {
      next = next.withStatus(status, now);
    }
    return next;
  }

  /// Releases the row's controller.
  void dispose() => controller.dispose();
}

/// TASKFORM-2, TASKFORM-5. "A section headed `"Subtasks"` containing the
/// ordered subtask list, with an `"Add subtask"` row at the **end** of the
/// list."
///
/// TASKFORM-5 is the whole of what `Done` changes here: status controls
/// disabled with a hint, the `"Add subtask"` row hidden, and name fields,
/// delete buttons and drag handles left alone. The caller passes [locked] from
/// the form's status control, not from the saved Task, because TASKFORM-5
/// requires the unlock to happen "immediately, before saving".
class SubtaskEditor extends StatelessWidget {
  /// Edits [drafts] in place, reporting structural changes through the
  /// callbacks.
  const SubtaskEditor({
    required this.drafts,
    required this.locked,
    required this.showStatusControls,
    required this.onAdd,
    required this.onRemove,
    required this.onReorder,
    required this.onChanged,
    this.readOnly = false,
    super.key,
  });

  /// The rows, in their user-controlled order (§3.3).
  final List<SubtaskDraft> drafts;

  /// SUB-1, TASKFORM-5. Whether the status controls are locked by a `Done`
  /// parent.
  final bool locked;

  /// TASKFORM-2. "Add and Convert modes: new subtasks are always `Todo` and
  /// the control is hidden."
  final bool showStatusControls;

  /// TASKFORM-2. Appends a row and focuses it.
  final VoidCallback onAdd;

  /// SUB-7. Hard-deletes the row at the given index.
  final ValueChanged<int> onRemove;

  /// TASKFORM-2. Moves a row, `(oldIndex, newIndex)`.
  final void Function(int oldIndex, int newIndex) onReorder;

  /// Reports any edit, so the form can mark itself dirty (NAV-1).
  final VoidCallback onChanged;

  /// ARCH-3, SEARCH-3. The read-only screens show the list but edit nothing.
  final bool readOnly;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text('Subtasks', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: drafts.length,
        // `onReorderItem` reports the destination index already adjusted for
        // the removal, which `onReorder` did not.
        onReorderItem: onReorder,
        itemBuilder: (BuildContext context, int index) => _SubtaskRow(
          key: ObjectKey(drafts[index]),
          draft: drafts[index],
          index: index,
          locked: locked,
          showStatusControl: showStatusControls,
          readOnly: readOnly,
          onRemove: () => onRemove(index),
          onChanged: onChanged,
          onSubmit: onAdd,
        ),
      ),
      // TASKFORM-2, SUB-8. The row is at the end of the list, and is absent
      // while the status control reads `Done`.
      if (!locked && !readOnly)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add subtask'),
          ),
        ),
    ],
  );
}

class _SubtaskRow extends StatelessWidget {
  const _SubtaskRow({
    required this.draft,
    required this.index,
    required this.locked,
    required this.showStatusControl,
    required this.readOnly,
    required this.onRemove,
    required this.onChanged,
    required this.onSubmit,
    super.key,
  });

  final SubtaskDraft draft;
  final int index;
  final bool locked;
  final bool showStatusControl;
  final bool readOnly;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: <Widget>[
        // TASKFORM-2, TASKFORM-5. Hidden in Add and Convert, disabled while the
        // Task is Done, with SUB-2's hint as the tooltip.
        if (showStatusControl)
          Tooltip(
            message: locked ? const SubtasksLocked().message : '',
            child: _StatusDropdown(
              value: draft.status,
              enabled: !locked && !readOnly,
              onChanged: (TaskStatus next) {
                draft.status = next;
                onChanged();
              },
            ),
          ),
        Expanded(
          child: TextField(
            controller: draft.controller,
            readOnly: readOnly,
            maxLines: 1,
            // §3.4. Subtask names have no line breaks either.
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
            ],
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Subtask',
            ),
            onChanged: (String _) => onChanged(),
            // TASKFORM-2. "Pressing Enter in a subtask name commits it and
            // appends another new row."
            onSubmitted: (String _) => onSubmit(),
          ),
        ),
        // TASKFORM-5. Delete and drag stay enabled in every state.
        if (!readOnly) ...<Widget>[
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete subtask',
            onPressed: onRemove,
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.drag_handle),
            ),
          ),
        ],
      ],
    ),
  );
}

/// TASKFORM-2. A subtask's status control: `Todo / Blocked / Done`.
class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final TaskStatus value;
  final bool enabled;
  final ValueChanged<TaskStatus> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButton<TaskStatus>(
    value: value,
    underline: const SizedBox.shrink(),
    onChanged: enabled
        ? (TaskStatus? next) {
            if (next != null) {
              onChanged(next);
            }
          }
        : null,
    items: <DropdownMenuItem<TaskStatus>>[
      for (final MapEntry<TaskStatus, String> entry in statusLabels.entries)
        DropdownMenuItem<TaskStatus>(
          value: entry.key,
          child: Text(entry.value),
        ),
    ],
  );
}

/// TASKFORM-1, TASKFORM-2. The three statuses' user-facing labels, in the order
/// the specification writes them.
const Map<TaskStatus, String> statusLabels = <TaskStatus, String>{
  TaskStatus.todo: 'Todo',
  TaskStatus.blocked: 'Blocked',
  TaskStatus.done: 'Done',
};

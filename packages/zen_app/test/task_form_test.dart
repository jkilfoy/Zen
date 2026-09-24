/// §5.4. The Edit Task screen, and the acceptance scenarios it carries.
///
/// M5's definition of done: "AC-4, AC-5 pass on the Edit Task screen."
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_domain/zen_domain.dart';

import 'support/harness.dart';

/// TASKFORM-1. The Task's own status control.
Finder get statusControl => find.byType(SegmentedButton<TaskStatus>);

/// TASKFORM-2. Each subtask row's status control.
Finder get subtaskStatusControls => find.byType(DropdownButton<TaskStatus>);

/// One segment of the Task's status control. Tapping the control itself would
/// land on whichever segment happens to be in the middle.
Finder statusSegment(String label) =>
    find.descendant(of: statusControl, matching: find.text(label));

/// TASKFORM-2. The last subtask row's name field — the one just appended.
///
/// `InputDecorator` keeps the hint in the tree even when the field has text, so
/// every subtask row matches the hint; the appended row is the last of them.
Finder get lastSubtaskField => find.widgetWithText(TextField, 'Subtask').last;

/// The incomplete-subtasks popup of §4.2, verbatim.
Finder get incompleteSubtasksPopup => find.text(
  'This task has incomplete subtasks. Complete the subtasks before finishing '
  'this task.',
);

void main() {
  /// Opens Edit Task for [name] by tapping its row on the To Do tab (ROW-3).
  Future<void> openEditTask(
    WidgetTester tester,
    ZenHarness harness,
    String name,
  ) async {
    await harness.pumpApp(tester);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  /// AC-4 and AC-5's Task: Done, with every subtask Done.
  Future<Task> seedDoneTask(ZenHarness harness) => seedTask(
    harness,
    name: 'Ship it',
    status: TaskStatus.done,
    subtasks: const <(String, TaskStatus)>[('Test', TaskStatus.done)],
  );

  testWidgets(
    'AC-4: a Done task is partly editable, and setting Status to Todo unlocks '
    'it without saving first',
    (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      final Task before = await seedDoneTask(harness);
      await openEditTask(tester, harness, 'Ship it');

      // "Then subtask status controls are disabled and the `"Add subtask"` row
      // is absent".
      expect(
        tester
            .widget<DropdownButton<TaskStatus>>(subtaskStatusControls.first)
            .onChanged,
        isNull,
      );
      expect(find.text('Add subtask'), findsNothing);

      // "but renaming, deleting and reordering all work." TASKFORM-5 keeps the
      // name field, the delete button and the drag handle enabled.
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Test'))
            .readOnly,
        isFalse,
      );
      expect(find.byTooltip('Delete subtask'), findsOneWidget);
      expect(find.byIcon(Icons.drag_handle), findsOneWidget);

      // "When the user sets Status to Todo, then the status controls become
      // editable and `"Add subtask"` appears, without saving first."
      await tapItem(tester, statusSegment('Todo'));

      expect(
        tester
            .widget<DropdownButton<TaskStatus>>(subtaskStatusControls.first)
            .onChanged,
        isNotNull,
      );
      expect(find.text('Add subtask'), findsOneWidget);

      // "without saving first": nothing has been written.
      final Task stored = (await harness.tasks.findById(before.id))!;
      expect(stored.status, TaskStatus.done);
    },
  );

  testWidgets(
    'AC-5: adding a subtask requires reopening the task, and the save clears '
    'completedAt',
    (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      final Task before = await seedDoneTask(harness);
      await openEditTask(tester, harness, 'Ship it');

      // "Then there is no way to add a subtask." SUB-8.
      expect(find.text('Add subtask'), findsNothing);

      // "When the user sets Status to Todo, adds a subtask and presses Save".
      await tapItem(tester, statusSegment('Todo'));
      await tapItem(tester, find.text('Add subtask'));
      await tester.enterText(lastSubtaskField, 'Write the changelog');
      await tester.pumpAndSettle();
      await tapItem(tester, find.widgetWithText(FilledButton, 'Save'));

      // "then the Task is saved as `Todo` with the new subtask and
      // `completedAt` cleared."
      final Task after = (await harness.tasks.findById(before.id))!;
      expect(after.status, TaskStatus.todo);
      expect(after.completedAt, isNull);
      expect(after.subtasks.length, 2);
      expect(after.subtasks.last.name.value, 'Write the changelog');
      expect(after.subtasks.last.status, TaskStatus.todo);
      expect(after.invariantFailures, isEmpty);
    },
  );

  testWidgets(
    'TASKFORM-4: setting Status to Done with an incomplete subtask shows the '
    'popup and leaves the status unchanged',
    (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      await seedTask(
        harness,
        name: 'Write report',
        subtasks: const <(String, TaskStatus)>[
          ('Draft', TaskStatus.done),
          ('Proofread', TaskStatus.todo),
        ],
      );
      await openEditTask(tester, harness, 'Write report');

      await tapItem(tester, statusSegment('Done'));

      expect(incompleteSubtasksPopup, findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // "and leaves the status unchanged": the `"Add subtask"` row is still
      // there, which is TASKFORM-5's tell that the control still reads Todo.
      expect(find.text('Add subtask'), findsOneWidget);
    },
  );

  testWidgets('TASKFORM-5: re-selecting Done re-applies the lock', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await seedDoneTask(harness);
    await openEditTask(tester, harness, 'Ship it');

    await tapItem(tester, statusSegment('Todo'));
    expect(find.text('Add subtask'), findsOneWidget);

    await tapItem(tester, statusSegment('Done'));
    expect(find.text('Add subtask'), findsNothing);
    expect(
      tester
          .widget<DropdownButton<TaskStatus>>(subtaskStatusControls.first)
          .onChanged,
      isNull,
    );
  });

  testWidgets(
    'TASKFORM-5: a subtask added while Todo blocks going back to Done',
    (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      await seedDoneTask(harness);
      await openEditTask(tester, harness, 'Ship it');

      await tapItem(tester, statusSegment('Todo'));
      await tapItem(tester, find.text('Add subtask'));
      await tester.enterText(lastSubtaskField, 'One more thing');
      await tester.pumpAndSettle();

      // "if the user added a subtask in between and it is not `Done`,
      // TASKFORM-4 blocks that status change."
      await tapItem(tester, statusSegment('Done'));
      expect(incompleteSubtasksPopup, findsOneWidget);
    },
  );

  testWidgets('SUB-7: deleting a subtask removes it on save', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    final Task before = await seedTask(
      harness,
      name: 'Move',
      subtasks: const <(String, TaskStatus)>[
        ('Pack', TaskStatus.todo),
        ('Clean', TaskStatus.todo),
        ('Keys', TaskStatus.todo),
      ],
    );
    await openEditTask(tester, harness, 'Move');

    await tapItem(tester, find.byTooltip('Delete subtask').at(1));
    await tapItem(tester, find.widgetWithText(FilledButton, 'Save'));

    final Task after = (await harness.tasks.findById(before.id))!;
    expect(after.subtasks.map((Subtask s) => s.name.value).toList(), <String>[
      'Pack',
      'Keys',
    ]);
  });

  testWidgets('TASKFORM-9: the Advanced details panel, collapsed by default', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    final Task task = await seedTask(harness, name: 'Buy milk');
    await openEditTask(tester, harness, 'Buy milk');

    expect(find.text('Advanced details'), findsOneWidget);
    // Collapsed: the fields are not in the tree yet.
    expect(find.text('createdAt'), findsNothing);

    await tapItem(tester, find.text('Advanced details'));

    for (final String field in <String>[
      'id',
      'createdAt',
      'updatedAt',
      'completedAt',
      'archivedAt',
      'deletedAt',
    ]) {
      expect(find.text(field), findsOneWidget, reason: field);
    }
    expect(find.text(task.id), findsOneWidget);
    // "Null fields are shown as `"—"`" — completedAt, archivedAt, deletedAt.
    expect(find.text('—'), findsNWidgets(3));
    // IDEAFORM-6. "The id row offers a copy action."
    expect(find.byTooltip('Copy id'), findsOneWidget);
  });

  testWidgets('TASKFORM-9: a converted task shows where it came from', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await seedIdea(harness, name: 'Learn Rust');
    await harness.pumpApp(tester);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ideas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make Task'));
    await tester.pumpAndSettle();
    await tapItem(tester, find.widgetWithText(FilledButton, 'Create Task'));

    await tester.tap(find.text('Learn Rust'));
    await tester.pumpAndSettle();
    await tapItem(tester, find.text('Advanced details'));

    expect(find.text('Converted from idea'), findsOneWidget);
    expect(find.text('sourceIdeaId'), findsOneWidget);
    expect(find.text('sourceIdeaCreatedAt'), findsOneWidget);
  });

  testWidgets(
    'TASKFORM-7, DEL-1, DEL-4: deleting a task asks, then soft-deletes',
    (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      final Task before = await seedTask(harness, name: 'Buy milk');
      await openEditTask(tester, harness, 'Buy milk');

      await tapItem(tester, find.widgetWithText(TextButton, 'Delete'));
      // DEL-4's copy, verbatim.
      expect(find.text('Delete this task?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      final Task after = (await harness.tasks.findById(before.id))!;
      expect(after.isDeleted, isTrue);
      expect(after.deletedAt, isNotNull);
      // TASKFORM-8. Back to the To Do tab, where it no longer appears.
      expect(find.text('Buy milk'), findsNothing);
    },
  );

  testWidgets('DEL-4: with confirmDestructive off, deleting does not ask', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await harness.settings.write(Settings(confirmDestructive: false));
    final Task before = await seedTask(harness, name: 'Buy milk');
    await openEditTask(tester, harness, 'Buy milk');

    await tapItem(tester, find.widgetWithText(TextButton, 'Delete'));

    expect(find.text('Delete this task?'), findsNothing);
    expect((await harness.tasks.findById(before.id))!.isDeleted, isTrue);
  });

  testWidgets('D-M4-6: a subtask row left blank is dropped on save', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    final Task before = await seedTask(
      harness,
      name: 'Move',
      subtasks: const <(String, TaskStatus)>[('Pack', TaskStatus.todo)],
    );
    await openEditTask(tester, harness, 'Move');

    // Open a blank row and save without typing. It is dropped, and the existing
    // subtask comes back identical, because nothing about it changed.
    await tapItem(tester, find.text('Add subtask'));
    await tapItem(tester, find.widgetWithText(FilledButton, 'Save'));

    final Task after = (await harness.tasks.findById(before.id))!;
    expect(after.subtasks.single, before.subtasks.single);
  });

  testWidgets('IDEAFORM-6: the Idea form shows its three fields', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    final Idea idea = await seedIdea(harness, name: 'Read SICP');
    await harness.pumpApp(tester);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ideas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read SICP'));
    await tester.pumpAndSettle();
    await tapItem(tester, find.text('Advanced details'));

    expect(find.text(idea.id), findsOneWidget);
    expect(find.text('createdAt'), findsOneWidget);
    expect(find.text('updatedAt'), findsOneWidget);
    // An Idea has no other lifecycle fields (§3.2).
    expect(find.text('completedAt'), findsNothing);
  });

  testWidgets(
    'IDEAFORM-5, DEL-3: deleting an idea removes it and tombstones it',
    (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      final Idea idea = await seedIdea(harness, name: 'Read SICP');
      await harness.pumpApp(tester);
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ideas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read SICP'));
      await tester.pumpAndSettle();

      await tapItem(tester, find.widgetWithText(TextButton, 'Delete'));
      expect(
        find.text('Delete this idea? This cannot be undone.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(await readStream(tester, harness.ideas.watchAll()), isEmpty);
      final List<IdeaTombstone> tombstones = await harness.tombstones.all();
      expect(tombstones.single.id, idea.id);
      expect(tombstones.single.reason, TombstoneReason.deleted);
    },
  );
}

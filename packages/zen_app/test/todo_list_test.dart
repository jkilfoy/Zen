/// §5.7. The To Do tab, and the acceptance scenarios it carries.
///
/// M4's definition of done: "AC-1, AC-2, AC-3, AC-7 pass again as widget
/// tests." They passed as pure domain tests in M1; these run the same scenarios
/// through the real screen against a real database.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_app/src/router.dart';
import 'package:zen_app/src/widgets/completion_circle.dart';
import 'package:zen_app/src/widgets/item_row.dart';
import 'package:zen_domain/zen_domain.dart';

import 'support/harness.dart';

/// Every completion circle on screen, in layout order: a Task's own circle,
/// then its subtasks' (TODO-3, TODO-4).
Finder get circles => find.byType(CompletionCircle);

void main() {
  /// Opens the app on the To Do tab.
  Future<void> openTodo(WidgetTester tester, ZenHarness harness) async {
    await harness.pumpApp(tester);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'AC-1: tapping the circle of a task with incomplete subtasks shows the '
    'popup and changes nothing',
    (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      final Task task = await seedTask(
        harness,
        name: 'Write report',
        subtasks: const <(String, TaskStatus)>[
          ('Draft', TaskStatus.done),
          ('Proofread', TaskStatus.todo),
        ],
      );
      await openTodo(tester, harness);

      await tester.tap(circles.first);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This task has incomplete subtasks. Complete the subtasks before '
          'finishing this task.',
        ),
        findsOneWidget,
      );
      final Task? after = await harness.tasks.findById(task.id);
      expect(after!.status, TaskStatus.todo);
      expect(after.completedAt, isNull);
    },
  );

  testWidgets(
    'AC-2: with every subtask Done the circle completes the task, sets '
    'completedAt and strikes the name through',
    (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      final Task task = await seedTask(
        harness,
        name: 'Write report',
        subtasks: const <(String, TaskStatus)>[
          ('Draft', TaskStatus.done),
          ('Proofread', TaskStatus.done),
        ],
      );
      await openTodo(tester, harness);

      await tester.tap(circles.first);
      await tester.pumpAndSettle();

      final Task after = (await harness.tasks.findById(task.id))!;
      expect(after.status, TaskStatus.done);
      expect(after.completedAt, isNotNull);

      // TODO-3. "The name is struck through if `settings.strikethroughDone`",
      // whose factory default is true (§3.6).
      final Text name = tester.widget<Text>(find.text('Write report'));
      expect(name.style?.decoration, TextDecoration.lineThrough);
    },
  );

  testWidgets(
    'AC-3: a Done task locks its subtask statuses, and reopening it unlocks '
    'them',
    (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      final Task task = await seedTask(
        harness,
        name: 'Ship it',
        status: TaskStatus.done,
        subtasks: const <(String, TaskStatus)>[('Test', TaskStatus.done)],
      );
      await openTodo(tester, harness);

      // TODO-4, SUB-1. The subtask's circle renders disabled.
      final CompletionCircle subtaskCircle = tester.widget<CompletionCircle>(
        circles.at(1),
      );
      expect(subtaskCircle.locked, isTrue);

      // SUB-2. Tapping it changes nothing and shows the hint.
      await tester.tap(circles.at(1));
      await tester.pumpAndSettle();
      expect(
        find.text("Set the task back to Todo to change its subtasks' status."),
        findsOneWidget,
      );
      Task after = (await harness.tasks.findById(task.id))!;
      expect(after.subtasks.single.status, TaskStatus.done);
      expect(after.status, TaskStatus.done);

      // "When the user then taps the task's circle (task → Todo) and taps the
      // subtask's circle again, then the subtask becomes `Todo`."
      await tester.tap(circles.first);
      await tester.pumpAndSettle();
      after = (await harness.tasks.findById(task.id))!;
      expect(after.status, TaskStatus.todo);

      await tester.tap(circles.at(1));
      await tester.pumpAndSettle();
      after = (await harness.tasks.findById(task.id))!;
      expect(after.subtasks.single.status, TaskStatus.todo);
    },
  );

  testWidgets(
    'AC-7: a Blocked task does not toggle, and its subtasks remain toggleable',
    (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      final Task task = await seedTask(
        harness,
        name: 'Waiting on Sam',
        status: TaskStatus.blocked,
        subtasks: const <(String, TaskStatus)>[('Email Sam', TaskStatus.todo)],
      );
      await openTodo(tester, harness);

      await tester.tap(circles.first);
      await tester.pumpAndSettle();
      Task after = (await harness.tasks.findById(task.id))!;
      expect(after.status, TaskStatus.blocked);
      // §4.2. The refusal is silent: no popup, no snack bar.
      expect(find.byType(AlertDialog), findsNothing);

      // SUB-6. "Subtasks of a `Blocked` Task can be toggled."
      await tester.tap(circles.at(1));
      await tester.pumpAndSettle();
      after = (await harness.tasks.findById(task.id))!;
      expect(after.subtasks.single.status, TaskStatus.done);
      expect(after.status, TaskStatus.blocked);
    },
  );

  testWidgets('TODO-1, TODO-2: every unarchived, undeleted task, oldest first', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await seedTask(harness, name: 'First task', createdAt: base);
    await seedTask(
      harness,
      name: 'Second task',
      createdAt: base.add(const Duration(minutes: 1)),
      status: TaskStatus.done,
    );
    await seedTask(
      harness,
      name: 'Third task',
      createdAt: base.add(const Duration(minutes: 2)),
      status: TaskStatus.blocked,
    );
    await seedTask(
      harness,
      name: 'Archived task',
      createdAt: base,
      status: TaskStatus.done,
      archived: true,
    );
    await seedTask(
      harness,
      name: 'Deleted task',
      createdAt: base,
      deleted: true,
    );
    await openTodo(tester, harness);

    // TODO-1. Done and Blocked tasks are visible; archived and deleted are not.
    expect(find.text('Archived task'), findsNothing);
    expect(find.text('Deleted task'), findsNothing);

    // TODO-2. "by `createdAt` ascending (oldest first). Status changes do not
    // move or regroup a task."
    final double first = tester.getTopLeft(find.text('First task')).dy;
    final double second = tester.getTopLeft(find.text('Second task')).dy;
    final double third = tester.getTopLeft(find.text('Third task')).dy;
    expect(first, lessThan(second));
    expect(second, lessThan(third));
  });

  testWidgets('REVIEW-3, TODO-6: the empty state and the archive link', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await openTodo(tester, harness);

    expect(
      find.text('Nothing to do. Add a task from the home screen.'),
      findsOneWidget,
    );
    expect(find.text('Archived tasks'), findsOneWidget);
  });

  testWidgets(
    'REVIEW-4: the Review screen offers no way to author a new item',
    (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      await seedTask(harness, name: 'Something to do');
      await openTodo(tester, harness);

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Add task'), findsNothing);
      expect(find.text('Add subtask'), findsNothing);
    },
  );

  testWidgets(
    'B2: tapping anywhere right of the completion circle opens Edit Task',
    (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      await seedTask(
        harness,
        name: 'Buy milk',
        subtasks: const <(String, TaskStatus)>[
          ('Oat, not dairy', TaskStatus.todo),
        ],
      );
      await openTodo(tester, harness);

      // Empty space to the right of the name, well past where the glyphs stop.
      final Rect region = tester.getRect(
        find.byKey(ItemRow.tapRegionKey).first,
      );
      await tester.tapAt(Offset(region.right - 8, region.top + 8));
      await tester.pumpAndSettle();

      expect(find.text('Edit Task'), findsOneWidget);
    },
  );

  testWidgets('B2: the region stops short of the leading completion circle', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await seedTask(harness, name: 'Buy milk');
    await openTodo(tester, harness);

    final Rect region = tester.getRect(find.byKey(ItemRow.tapRegionKey).first);
    final Rect circle = tester.getRect(circles.first);

    // "to the right of the completion circle for tasks".
    expect(region.left, greaterThanOrEqualTo(circle.right));
  });

  testWidgets('B2: a subtask circle still toggles rather than opening Edit', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    final Task task = await seedTask(
      harness,
      name: 'Move',
      subtasks: const <(String, TaskStatus)>[('Pack', TaskStatus.todo)],
    );
    await openTodo(tester, harness);

    // The subtask rows are inside the tap region now, so the nested
    // InkResponse has to win the gesture arena against the InkWell above it.
    await tester.tap(circles.at(1));
    await tester.pumpAndSettle();

    expect(find.text('Edit Task'), findsNothing);
    final Task after = (await harness.tasks.findById(task.id))!;
    expect(after.subtasks.single.status, TaskStatus.done);
  });

  testWidgets('ROW-3: tapping the name opens Edit Task', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await seedTask(harness, name: 'Buy milk');
    await openTodo(tester, harness);

    await tester.tap(find.text('Buy milk'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Task'), findsOneWidget);
  });

  testWidgets(
    'ROW-2: tags render as @tag, and the line is omitted when empty',
    (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      await seedTask(
        harness,
        name: 'Tagged task',
        tags: const <String>['home', 'errand'],
        createdAt: base,
      );
      await seedTask(
        harness,
        name: 'Bare task',
        createdAt: base.add(const Duration(minutes: 1)),
      );
      await openTodo(tester, harness);

      expect(find.text('@home @errand'), findsOneWidget);
      // The bare row contributes no tag line at all.
      expect(find.textContaining('@'), findsOneWidget);
      expect(find.text('Bare task'), findsOneWidget);
    },
  );

  testWidgets('TODO-6: the archive link opens Archived Tasks', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await seedTask(harness, name: 'Something to do');
    await openTodo(tester, harness);

    await tester.tap(find.text('Archived tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing archived yet.'), findsOneWidget);
  });

  testWidgets('REVIEW-1, REVIEW-2: the top bar, and the default tab', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await openTodo(tester, harness);

    expect(find.text('To Do'), findsOneWidget);
    expect(find.text('Ideas'), findsOneWidget);
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    // REVIEW-2. Entering from Home lands on To Do.
    expect(
      find.text('Nothing to do. Add a task from the home screen.'),
      findsOneWidget,
    );
  });

  testWidgets('NFR-6: a completion circle announces its state and its lock', (
    WidgetTester tester,
  ) async {
    expect(
      CompletionCircle.semanticLabelFor(TaskStatus.todo, locked: false),
      'Todo',
    );
    expect(
      CompletionCircle.semanticLabelFor(TaskStatus.done, locked: true),
      'Done, locked',
    );
    expect(
      CompletionCircle.semanticLabelFor(TaskStatus.blocked, locked: false),
      'Blocked',
    );
  });

  testWidgets('§5.1: Home opens Review on the To Do tab (HOME-4)', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await harness.pumpApp(tester);

    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsOneWidget);
    expect(Routes.review, '/review');
  });
}

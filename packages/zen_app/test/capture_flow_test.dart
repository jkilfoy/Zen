/// §5.2, §5.3, §5.4. The capture path: Home, Add Idea, Add Task.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_domain/zen_domain.dart';

import 'support/harness.dart';

void main() {
  /// HOME-2, HOME-3. Home ▸ Add ▸ Idea, in the two taps NFR-2 asks for.
  Future<void> openAddIdea(WidgetTester tester, ZenHarness harness) async {
    await harness.pumpApp(tester);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Idea'));
    await tester.pumpAndSettle();
  }

  /// HOME-2, HOME-3. Home ▸ Add ▸ Task.
  Future<void> openAddTask(WidgetTester tester, ZenHarness harness) async {
    await harness.pumpApp(tester);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Task'));
    await tester.pumpAndSettle();
  }

  testWidgets('HOME-1, HOME-2: Add expands in place into Idea and Task', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await harness.pumpApp(tester);

    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // "replaces the Add region, in place and without navigating"
    expect(find.text('Idea'), findsOneWidget);
    expect(find.text('Task'), findsOneWidget);
    expect(find.text('Add'), findsNothing);
    expect(find.text('Review'), findsOneWidget);

    // "Tapping outside them or pressing Back restores the `"Add"` label."
    await tester.tap(find.text('Review').first, warnIfMissed: false);
    await tester.pumpAndSettle();
  });

  testWidgets('HOME-3: Add Idea opens with the name field focused', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await openAddIdea(tester, harness);

    expect(find.text('Add Idea'), findsWidgets);
    final TextField name = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Name'),
    );
    expect(name.autofocus, isTrue);
  });

  testWidgets(
    'CREATE-1, IDEAFORM-2, IDEAFORM-4: adding an idea stores it and lands on '
    'the Ideas tab',
    (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      await openAddIdea(tester, harness);

      // IDEAFORM-2. Disabled until the name is valid (NAME-2: three
      // characters).
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add Idea'))
            .onPressed,
        isNull,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Learn Rust',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add Idea'));
      await tester.pumpAndSettle();

      final List<Idea> stored = await readStream(
        tester,
        harness.ideas.watchAll(),
      );
      expect(stored.single.name.value, 'Learn Rust');
      // §3.2. The timeframe defaults to `settings.defaultIdeaTimeframe`.
      expect(stored.single.timeframe, Timeframe.now);

      // IDEAFORM-4. "the app navigates to Review on the Ideas tab, with the
      // group containing the new Idea expanded and the new Idea scrolled into
      // view".
      expect(find.text('Ideas'), findsOneWidget);
      expect(find.text('Learn Rust'), findsOneWidget);
      expect(find.text('Now (1)'), findsOneWidget);
    },
  );

  testWidgets('IDEAFORM-2, NAME-2: a two-character name is refused', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await openAddIdea(tester, harness);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'ab');
    // IDEAFORM-2. "Messages appear once the user has typed and then paused."
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Name must be at least 3 characters.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add Idea'))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'AC-8: a colliding task name is refused, and the same name as an idea is '
    'not',
    (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      await seedTask(harness, name: 'Buy milk');
      await openAddTask(tester, harness);

      // "When the user tries to add another Task "buy  MILK", then the save
      // button is disabled and `"A task with this name already exists."` is
      // shown." §2's normalization makes the two names equal.
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'buy  MILK',
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(
        find.text('A task with this name already exists.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add Task'))
            .onPressed,
        isNull,
      );
      // NAME-8. "The message SHOULD offer an `"Open it"` link."
      expect(find.text('Open it'), findsOneWidget);

      // "Adding an **Idea** named "Buy milk" succeeds." NAME-6: the two kinds
      // are independent namespaces.
      final Result<Idea, RuleViolation> idea = await harness.ideas.create(
        Idea(
          id: 'idea-milk',
          name: ItemName.parse('Buy milk').unwrap(),
          timeframe: Timeframe.now,
          createdAt: base,
          updatedAt: base,
        ),
      );
      expect(idea.isOk, isTrue);
    },
  );

  testWidgets('AC-9: a name freed by archiving can be used again', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await seedTask(
      harness,
      name: 'Water the plants',
      status: TaskStatus.done,
      archived: true,
    );
    await openAddTask(tester, harness);

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Water the plants',
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // NAME-7. An archived Task reserves no name, so nothing is refused.
    expect(find.text('A task with this name already exists.'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Add Task'));
    await tester.pumpAndSettle();

    // "then it is created successfully and both exist: one archived, one
    // active."
    final List<Task> all = await readStream(tester, harness.tasks.watchAll());
    expect(all.length, 2);
    expect(all.where((Task t) => t.isArchived).length, 1);
    expect(all.where((Task t) => t.isActive).length, 1);
  });

  testWidgets(
    'CREATE-2, TASKFORM-2, TASKFORM-8: adding a task with subtasks lands on '
    'the To Do tab',
    (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      await openAddTask(tester, harness);

      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Move');
      await tester.pumpAndSettle();

      // TASKFORM-2. "In Add and Convert modes the Task is always `Todo`, so the
      // `"Add subtask"` row is always present."
      expect(find.text('Add subtask'), findsOneWidget);
      await tester.tap(find.text('Add subtask'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Subtask'), 'Pack');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Add Task'));
      await tester.pumpAndSettle();

      final List<Task> stored = await readStream(
        tester,
        harness.tasks.watchActive(),
      );
      expect(stored.single.name.value, 'Move');
      expect(stored.single.status, TaskStatus.todo);
      expect(stored.single.subtasks.single.name.value, 'Pack');
      // §3.4. "new subtasks are always `Todo`".
      expect(stored.single.subtasks.single.status, TaskStatus.todo);

      // TASKFORM-8. Review, To Do tab, with the new Task in view.
      expect(find.text('To Do'), findsOneWidget);
      expect(find.text('Move'), findsOneWidget);
    },
  );

  testWidgets('TASKFORM-1: Add mode has no Status control', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await openAddTask(tester, harness);

    // "Status (Edit mode only: segmented control Todo / Blocked / Done)".
    expect(find.byType(SegmentedButton<TaskStatus>), findsNothing);
  });

  testWidgets('NAV-1: leaving a dirty form asks "Discard changes?"', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await openAddIdea(tester, harness);

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Something typed',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Add Idea'), findsWidgets);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    // Back on Home, with nothing written.
    expect(find.text('Review'), findsOneWidget);
    expect(await readStream(tester, harness.ideas.watchAll()), isEmpty);
  });

  testWidgets('§3.5, TAG-1, TAG-4: the chip input strips @ and dedupes', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await openAddIdea(tester, harness);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Tagged');
    await tester.pumpAndSettle();

    Future<void> addTag(String raw) async {
      await tester.enterText(find.widgetWithText(TextField, 'Tags'), raw);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    await addTag('@code');
    await addTag('CODE');
    await addTag('books');

    await tester.tap(find.widgetWithText(FilledButton, 'Add Idea'));
    await tester.pumpAndSettle();

    final List<Idea> stored = await readStream(
      tester,
      harness.ideas.watchAll(),
    );
    // TAG-1 stripped the `@`; TAG-4 made the second, differently cased `code`
    // a no-op and kept the casing first typed.
    expect(stored.single.tags.map((Tag tag) => tag.value).toList(), <String>[
      'code',
      'books',
    ]);
  });
}

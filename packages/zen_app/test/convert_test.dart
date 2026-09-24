/// §4.4, §5.8. Converting an Idea into a Task, from both entry points.
///
/// M4's definition of done: "AC-11, AC-12 pass via the `"Make Task"` entry
/// point." M5's adds: "AC-11 also passes via the Edit Idea entry point."
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_domain/zen_domain.dart';

import 'support/harness.dart';

void main() {
  /// Opens the app on the Ideas tab.
  Future<void> openIdeas(WidgetTester tester, ZenHarness harness) async {
    await harness.pumpApp(tester);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ideas'));
    await tester.pumpAndSettle();
  }

  /// AC-11's Idea, exactly as the scenario states it.
  Future<Idea> seedLearnRust(ZenHarness harness) => seedIdea(
    harness,
    name: 'Learn Rust',
    tags: const <String>['code'],
    context: 'Book + exercises',
    timeframe: Timeframe.soon,
  );

  /// AC-11's assertions about the result, shared by the two entry points.
  Future<void> expectConverted(WidgetTester tester, ZenHarness harness) async {
    final List<Task> tasks = await readStream(
      tester,
      harness.tasks.watchActive(),
    );
    final Task task = tasks.single;
    expect(task.name.value, 'Learn Rust');
    expect(task.tags.map((Tag tag) => tag.value).toList(), <String>['code']);
    expect(task.description.value, 'Book + exercises');
    expect(task.status, TaskStatus.todo);
    expect(task.subtasks, isEmpty);
    // CONVERT-1. `sourceIdeaId` and `sourceIdeaCreatedAt` are set as a pair
    // (INV-8), and the Idea's timeframe is discarded.
    expect(task.sourceIdeaId, isNotNull);
    expect(task.sourceIdeaCreatedAt, isNotNull);

    // "The Idea is gone, a tombstone with `reason = converted` exists".
    expect(await readStream(tester, harness.ideas.watchAll()), isEmpty);
    final List<IdeaTombstone> tombstones = await harness.tombstones.all();
    expect(tombstones.single.id, task.sourceIdeaId);
    expect(tombstones.single.reason, TombstoneReason.converted);

    // "and the To Do list is shown."
    expect(find.text('To Do'), findsOneWidget);
    expect(find.text('Learn Rust'), findsOneWidget);
  }

  testWidgets('AC-11: "Make Task" on an idea row converts it', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await seedLearnRust(harness);
    await openIdeas(tester, harness);

    // IDEAS-1. The Idea is in the `Soon` group, which the factory default
    // expands (§3.6).
    expect(find.text('Soon (1)'), findsOneWidget);
    // IDEAS-5. Ideas have no completion circle.
    expect(find.text('Learn Rust'), findsOneWidget);

    await tester.tap(find.text('Make Task'));
    await tester.pumpAndSettle();

    // CONVERT-1. The Create Task screen, pre-filled.
    expect(find.text('Create Task'), findsWidgets);
    expect(find.text('Book + exercises'), findsOneWidget);
    expect(find.text('@code'), findsOneWidget);

    // CONVERT-4. Nothing is written until this press.
    expect(await readStream(tester, harness.tasks.watchActive()), isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Create Task'));
    await tester.pumpAndSettle();

    await expectConverted(tester, harness);
  });

  testWidgets('AC-11: Edit Idea ▸ "Create Task" gives an identical result', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await seedLearnRust(harness);
    await openIdeas(tester, harness);

    // IDEAFORM-5, CONVERT-0. The second entry point.
    await tester.tap(find.text('Learn Rust'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Idea'), findsWidgets);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Create Task'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create Task'));
    await tester.pumpAndSettle();

    await expectConverted(tester, harness);
  });

  testWidgets(
    'AC-12: editing the pre-filled name then cancelling leaves the idea '
    'untouched',
    (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      final Idea before = await seedLearnRust(harness);
      await openIdeas(tester, harness);

      await tester.tap(find.text('Make Task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Learn Rust properly',
      );
      await tester.pumpAndSettle();

      // NAV-1. The edit made the form dirty, so Back asks first (CONVERT-5:
      // "Any edits the user made on the Create Task screen are discarded,
      // subject to the usual `"Discard changes?"` prompt").
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      // "then the Idea is unchanged — including its timeframe and original
      // name — no Task exists, and the app is on the Ideas tab."
      final List<Idea> ideas = await readStream(
        tester,
        harness.ideas.watchAll(),
      );
      expect(ideas.single, before);
      expect(await readStream(tester, harness.tasks.watchAll()), isEmpty);
      expect(find.text('Soon (1)'), findsOneWidget);
    },
  );

  testWidgets(
    'CONVERT-3: a name colliding with an active task blocks confirm',
    (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      await seedTask(harness, name: 'Learn Rust');
      final Idea before = await seedLearnRust(harness);
      await openIdeas(tester, harness);

      await tester.tap(find.text('Make Task'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(
        find.text('A task with this name already exists.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Create Task'),
            )
            .onPressed,
        isNull,
      );
      // "The Idea is not touched."
      final List<Idea> ideas = await readStream(
        tester,
        harness.ideas.watchAll(),
      );
      expect(ideas.single, before);
    },
  );

  testWidgets('IDEAS-1, IDEAS-3: four groups in fixed order, empty ones shown', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await seedIdea(harness, name: 'Urgent thing');
    await seedIdea(
      harness,
      name: 'Someday thing',
      timeframe: Timeframe.distant,
    );
    await openIdeas(tester, harness);

    expect(find.text('Now (1)'), findsOneWidget);
    expect(find.text('Soon (0)'), findsOneWidget);
    expect(find.text('Later (0)'), findsOneWidget);
    expect(find.text('Distant (1)'), findsOneWidget);

    // IDEAS-1, IDEAS-2. `Distant` is collapsed by default, because it is not in
    // `settings.expandedIdeaGroups` (§3.6).
    expect(find.text('Urgent thing'), findsOneWidget);
    expect(find.text('Someday thing'), findsNothing);

    // IDEAS-2. Tapping the header toggles it.
    await tester.tap(find.text('Distant (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Someday thing'), findsOneWidget);
  });

  testWidgets('IDEAS-6: the Make Task button carries its accessibility label', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await seedIdea(harness, name: 'Learn Rust');
    await openIdeas(tester, harness);

    expect(
      find.bySemanticsLabel('Make task from idea: Learn Rust'),
      findsOneWidget,
    );
  });

  testWidgets('REVIEW-3: an empty Ideas tab', (WidgetTester tester) async {
    final ZenHarness harness = ZenHarness();
    await openIdeas(tester, harness);

    expect(find.text('No ideas yet.'), findsOneWidget);
  });
}

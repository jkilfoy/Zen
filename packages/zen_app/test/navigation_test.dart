/// NAV-1, §5.1, B1. The shape of the navigation stack.
///
/// These assert **stack depth and contents**, not merely that the right screen
/// is showing. B1's defect was invisible to the latter: the correct screen was
/// on display the whole time, with nothing underneath it. A regression here
/// would look identical to a pass unless the pages beneath are counted, which
/// is why every test below either counts offstage screens or pops and checks
/// what is revealed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_app/src/router.dart';
import 'package:zen_app/src/screens/home_screen.dart';
import 'package:zen_app/src/screens/idea_form_screen.dart';
import 'package:zen_app/src/screens/review_screen.dart';
import 'package:zen_app/src/screens/task_form_screen.dart';
import 'package:zen_domain/zen_domain.dart';

import 'support/harness.dart';

/// How many of [T] are in the tree, including pages hidden beneath the top one.
///
/// `skipOffstage: false` is the point: a route below an opaque route keeps its
/// widgets (`maintainState` defaults to true), so this counts the whole stack
/// rather than what is painted.
int inStack<T extends Widget>() =>
    find.byType(T, skipOffstage: false).evaluate().length;

/// Whether there is anything to go back to.
bool get canPop => rootNavigatorKey.currentState!.canPop();

void main() {
  Future<void> openTodo(WidgetTester tester, ZenHarness harness) async {
    await harness.pumpApp(tester);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
  }

  group('B1: Home survives a `go`', () {
    testWidgets('Home ▸ Review leaves Home underneath', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await openTodo(tester, harness);

      expect(inStack<ReviewScreen>(), 1);
      expect(inStack<HomeScreen>(), 1);
      expect(canPop, isTrue);
    });

    testWidgets('adding an Idea lands on Review with Home underneath', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await harness.pumpApp(tester);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Idea'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Learn Rust',
      );
      await tester.pumpAndSettle();
      await tapItem(tester, find.widgetWithText(FilledButton, 'Add Idea'));

      // IDEAFORM-4 lands here, and the finished form must be gone…
      expect(inStack<ReviewScreen>(), 1);
      expect(inStack<IdeaFormScreen>(), 0);
      // …but Home must not be.
      expect(inStack<HomeScreen>(), 1);
      expect(canPop, isTrue);

      // NAV-1. Back returns to the previous screen, which is Home.
      //
      // Home's own state survives — HOME-2's expanded Add region is still
      // expanded, so the label reads `Idea`/`Task` rather than `Add`. Assert
      // the screen rather than its contents.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(inStack<ReviewScreen>(), 0);
      expect(canPop, isFalse);
    });

    testWidgets('adding a Task lands on Review with Home underneath', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await harness.pumpApp(tester);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Move');
      await tester.pumpAndSettle();
      await tapItem(tester, find.widgetWithText(FilledButton, 'Add Task'));

      expect(inStack<ReviewScreen>(), 1);
      expect(inStack<TaskFormScreen>(), 0);
      expect(inStack<HomeScreen>(), 1);
      expect(canPop, isTrue);
    });

    testWidgets('saving an edit lands on Review with Home underneath', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await seedTask(harness, name: 'Buy milk');
      await openTodo(tester, harness);

      await tester.tap(find.text('Buy milk'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Buy oat milk',
      );
      await tester.pumpAndSettle();
      await tapItem(tester, find.widgetWithText(FilledButton, 'Save'));

      expect(inStack<ReviewScreen>(), 1);
      expect(inStack<TaskFormScreen>(), 0);
      expect(inStack<HomeScreen>(), 1);
      expect(canPop, isTrue);
    });

    testWidgets('converting an Idea lands on Review with Home underneath', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await seedIdea(harness, name: 'Learn Rust');
      await openTodo(tester, harness);
      await tester.tap(find.text('Ideas'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Make Task'));
      await tester.pumpAndSettle();
      await tapItem(tester, find.widgetWithText(FilledButton, 'Create Task'));

      expect(inStack<ReviewScreen>(), 1);
      expect(inStack<TaskFormScreen>(), 0);
      expect(inStack<HomeScreen>(), 1);
      expect(canPop, isTrue);
    });

    testWidgets('deleting a Task lands on Review with Home underneath', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await seedTask(harness, name: 'Buy milk');
      await openTodo(tester, harness);

      await tester.tap(find.text('Buy milk'));
      await tester.pumpAndSettle();
      await tapItem(tester, find.widgetWithText(TextButton, 'Delete'));
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(inStack<ReviewScreen>(), 1);
      expect(inStack<HomeScreen>(), 1);
      expect(canPop, isTrue);
    });

    testWidgets('unarchiving lands on Review with Home underneath', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await seedTask(
        harness,
        name: 'Water the plants',
        status: TaskStatus.done,
        archived: true,
      );
      await openTodo(tester, harness);
      await tapItem(tester, find.text('Archived tasks'));
      await tester.tap(find.text('Water the plants'));
      await tester.pumpAndSettle();
      await tapItem(tester, find.widgetWithText(FilledButton, 'Unarchive'));

      expect(inStack<ReviewScreen>(), 1);
      expect(inStack<HomeScreen>(), 1);
      expect(canPop, isTrue);
    });
  });

  group('B1: nesting does not make `push` duplicate the branch', () {
    // The risk in nesting routes: if `push` appended the whole matched
    // sub-stack rather than the leaf, pushing an Edit screen from Review would
    // produce [Home, Review, Home, Edit] — still showing the right screen, so
    // nothing but a count would catch it.
    testWidgets('pushing Edit Task from Review adds exactly one page', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await seedTask(harness, name: 'Buy milk');
      await openTodo(tester, harness);
      expect(inStack<HomeScreen>(), 1);

      await tester.tap(find.text('Buy milk'));
      await tester.pumpAndSettle();

      expect(inStack<TaskFormScreen>(), 1);
      // The stack is [Home, Review, EditTask] — one of each, not two Homes.
      expect(inStack<HomeScreen>(), 1);
      expect(inStack<ReviewScreen>(), 1);

      // And Back walks it back one page at a time.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(canPop, isFalse);
    });

    testWidgets('pushing Review from Home adds exactly one page', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await openTodo(tester, harness);

      expect(inStack<HomeScreen>(), 1);
      expect(inStack<ReviewScreen>(), 1);
    });

    testWidgets('Settings from Home adds exactly one page', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await harness.pumpApp(tester);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      expect(inStack<HomeScreen>(), 1);
      expect(canPop, isTrue);
    });

    testWidgets('Home itself has nothing to pop to', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await harness.pumpApp(tester);

      expect(inStack<HomeScreen>(), 1);
      expect(canPop, isFalse);
    });
  });

  group(
    'CONVERT-5: cancel returns to the Ideas tab from either entry point',
    () {
      testWidgets('from "Make Task", with the form untouched', (
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
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();

        expect(find.text('Now (1)'), findsOneWidget);
        expect(inStack<HomeScreen>(), 1);
      });

      testWidgets('from Edit Idea, with the form untouched', (
        WidgetTester tester,
      ) async {
        final ZenHarness harness = ZenHarness();
        await seedIdea(harness, name: 'Learn Rust');
        await harness.pumpApp(tester);
        await tester.tap(find.text('Review'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ideas'));
        await tester.pumpAndSettle();

        // IDEAFORM-5's entry point. A clean form pops natively, so without
        // CONVERT-5 being enforced this lands back on Edit Idea instead.
        await tester.tap(find.text('Learn Rust'));
        await tester.pumpAndSettle();
        await tapItem(
          tester,
          find.widgetWithText(OutlinedButton, 'Create Task'),
        );
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();

        expect(find.text('Now (1)'), findsOneWidget);
        expect(find.text('Edit Idea'), findsNothing);
        expect(inStack<HomeScreen>(), 1);
      });

      testWidgets('from Edit Idea, with an edited form, after discarding', (
        WidgetTester tester,
      ) async {
        final ZenHarness harness = ZenHarness();
        final Idea before = await seedIdea(harness, name: 'Learn Rust');
        await harness.pumpApp(tester);
        await tester.tap(find.text('Review'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ideas'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Learn Rust'));
        await tester.pumpAndSettle();
        await tapItem(
          tester,
          find.widgetWithText(OutlinedButton, 'Create Task'),
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Name'),
          'Learn Rust properly',
        );
        await tester.pumpAndSettle();

        // NAV-1's prompt still fires: it hangs off the pop, not off the `go`.
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(find.text('Discard changes?'), findsOneWidget);
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();

        expect(find.text('Now (1)'), findsOneWidget);
        expect(find.text('Edit Idea'), findsNothing);
        final List<Idea> ideas = await readStream(
          tester,
          harness.ideas.watchAll(),
        );
        expect(ideas.single, before);
      });
    },
  );
}

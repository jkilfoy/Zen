/// §5.10. `SCR-SEARCH`: the screen over `SearchQuery`.
///
/// What counts as a match is `zen_domain`'s and is tested there
/// (`search/search_query_test.dart`). These tests are about the screen: that
/// the controls are the ones SEARCH-2 names, that they start where SEARCH-2
/// says, and that a result opens the right Edit screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_domain/zen_domain.dart';

import 'support/harness.dart';

void main() {
  /// Opens Search through REVIEW-1's search icon.
  Future<void> openSearch(WidgetTester tester, ZenHarness harness) async {
    await harness.pumpApp(tester);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.widgetWithText(TextField, 'Search'), text);
    await tester.pumpAndSettle();
  }

  testWidgets('SEARCH-2: the filters start where the specification says', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await openSearch(tester, harness);

    bool selected(String label) => tester
        .widget<FilterChip>(find.widgetWithText(FilterChip, label))
        .selected;

    // "Kind: Ideas / Tasks / Both" — both, to start.
    expect(selected('Ideas'), isTrue);
    expect(selected('Tasks'), isTrue);
    // "Idea timeframe: multi-select, all four selected by default."
    for (final String timeframe in <String>[
      'Now',
      'Soon',
      'Later',
      'Distant',
    ]) {
      expect(selected(timeframe), isTrue, reason: timeframe);
    }
    // "Task state: … The default is all except Deleted."
    expect(selected('Todo'), isTrue);
    expect(selected('Blocked'), isTrue);
    expect(selected('Done'), isTrue);
    expect(selected('Archived'), isTrue);
    expect(selected('Deleted'), isFalse);
  });

  testWidgets('SEARCH-1: the text matches names, tags, context and subtasks', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await seedIdea(
      harness,
      name: 'Read SICP',
      tags: const <String>['cs'],
      context: 'The wizard book',
    );
    await seedTask(
      harness,
      name: 'Move house',
      subtasks: const <(String, TaskStatus)>[
        ('Pack the kitchen', TaskStatus.todo),
      ],
    );
    await openSearch(tester, harness);

    await type(tester, 'sicp');
    expect(find.text('Read SICP'), findsOneWidget);
    expect(find.text('Move house'), findsNothing);

    await type(tester, 'wizard');
    expect(find.text('Read SICP'), findsOneWidget);

    await type(tester, 'cs');
    expect(find.text('Read SICP'), findsOneWidget);

    await type(tester, 'kitchen');
    expect(find.text('Move house'), findsOneWidget);
    expect(find.text('Read SICP'), findsNothing);

    await type(tester, 'nothing matches this');
    expect(find.text('No matches.'), findsOneWidget);
  });

  testWidgets('SEARCH-2: a deleted task appears only with the Deleted filter', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await seedTask(harness, name: 'Cancel the gym', deleted: true);
    await openSearch(tester, harness);

    await type(tester, 'gym');
    expect(find.text('Cancel the gym'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Deleted'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel the gym'), findsOneWidget);
  });

  testWidgets('SEARCH-2: turning off a kind hides it and its filter row', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await seedIdea(harness, name: 'Read SICP');
    await seedTask(harness, name: 'Read the manual');
    await openSearch(tester, harness);

    await type(tester, 'read');
    expect(find.text('Read SICP'), findsOneWidget);
    expect(find.text('Read the manual'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Ideas'));
    await tester.pumpAndSettle();
    expect(find.text('Read SICP'), findsNothing);
    expect(find.text('Read the manual'), findsOneWidget);
    // The timeframe row is about Ideas, so it goes with them.
    expect(find.text('Idea timeframe'), findsNothing);
  });

  testWidgets(
    'SEARCH-3: results carry a kind badge and open the right screen',
    (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      await seedIdea(harness, name: 'Read SICP');
      await seedTask(harness, name: 'Read the manual');
      await openSearch(tester, harness);

      await type(tester, 'read');
      expect(find.text('Idea'), findsOneWidget);
      expect(find.text('Task'), findsOneWidget);

      await tester.tap(find.text('Read SICP'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Idea'), findsWidgets);
    },
  );

  testWidgets('SEARCH-3: a deleted task opens read-only with Restore', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await seedTask(harness, name: 'Cancel the gym', deleted: true);
    await openSearch(tester, harness);

    await tester.tap(find.widgetWithText(FilterChip, 'Deleted'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel the gym'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Restore'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Name')).readOnly,
      isTrue,
    );
  });

  testWidgets('SEARCH-2: an archived task is under Archived, not Done', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await seedTask(
      harness,
      name: 'Water the plants',
      status: TaskStatus.done,
      archived: true,
    );
    await openSearch(tester, harness);
    await type(tester, 'plants');

    expect(find.text('Water the plants'), findsOneWidget);

    // INV-3 makes it Done, but SEARCH-2's Archived is the state it is in.
    await tester.tap(find.widgetWithText(FilterChip, 'Archived'));
    await tester.pumpAndSettle();
    expect(find.text('Water the plants'), findsNothing);
  });
}

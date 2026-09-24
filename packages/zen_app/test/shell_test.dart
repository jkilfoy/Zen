/// The parts of the app that are not one screen: HOME-5's shortcuts, NFR-7's
/// responsiveness, and §11.5.5's recovery screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_app/src/screens/unreadable_database_screen.dart';
import 'package:zen_app/src/widgets/item_row.dart';
import 'package:zen_data/zen_data.dart';
import 'package:zen_domain/zen_domain.dart';

import 'support/harness.dart';

void main() {
  group('HOME-5: the desktop keyboard shortcuts', () {
    /// Presses [key] with the platform modifier held.
    Future<void> pressCtrl(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    testWidgets('Ctrl+I opens Add Idea', (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      await harness.pumpApp(tester);

      await pressCtrl(tester, LogicalKeyboardKey.keyI);
      expect(find.widgetWithText(FilledButton, 'Add Idea'), findsOneWidget);
    });

    testWidgets('Ctrl+T opens Add Task', (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      await harness.pumpApp(tester);

      await pressCtrl(tester, LogicalKeyboardKey.keyT);
      expect(find.widgetWithText(FilledButton, 'Add Task'), findsOneWidget);
    });

    testWidgets('Ctrl+R opens Review', (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      await harness.pumpApp(tester);

      await pressCtrl(tester, LogicalKeyboardKey.keyR);
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('Ctrl+F opens Search', (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      await harness.pumpApp(tester);

      await pressCtrl(tester, LogicalKeyboardKey.keyF);
      expect(find.widgetWithText(TextField, 'Search'), findsOneWidget);
    });

    testWidgets('Esc goes back', (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      await harness.pumpApp(tester);

      await pressCtrl(tester, LogicalKeyboardKey.keyR);
      expect(find.byType(TabBar), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      // Back on Home.
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Review'), findsOneWidget);
    });
  });

  group('NFR-7: the UI adapts from 400 px wide upward', () {
    /// Pumps [harness] at [size] and fails on any overflow.
    ///
    /// A `RenderFlex` overflow is reported as an exception rather than a
    /// failure, so without this check a squashed layout passes silently.
    Future<void> expectNoOverflow(
      WidgetTester tester,
      ZenHarness harness,
      Size size,
      Future<void> Function() reach,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await reach();
      expect(tester.takeException(), isNull);
    }

    testWidgets('the To Do list holds together at 400 px', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await seedTask(
        harness,
        name: 'A task with a fairly long name that has to wrap somewhere',
        tags: const <String>['home', 'errand', 'weekend'],
        subtasks: const <(String, TaskStatus)>[
          ('A subtask whose name is also on the long side', TaskStatus.todo),
        ],
      );
      await expectNoOverflow(tester, harness, const Size(400, 900), () async {
        await harness.pumpApp(tester);
        await tester.tap(find.text('Review'));
        await tester.pumpAndSettle();
      });
    });

    testWidgets('the Ideas list holds together at 400 px, Make Task and all', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await seedIdea(
        harness,
        name: 'An idea with a fairly long name that has to wrap somewhere',
        tags: const <String>['reading', 'someday'],
      );
      await expectNoOverflow(tester, harness, const Size(400, 900), () async {
        await harness.pumpApp(tester);
        await tester.tap(find.text('Review'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ideas'));
        await tester.pumpAndSettle();
      });
      expect(find.text('Make Task'), findsOneWidget);
    });
  });

  group('ROW-5: the trailing action keeps its distance', () {
    testWidgets('consecutive Make Task buttons are at least 24 px apart', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await seedIdea(harness, name: 'First idea', createdAt: base);
      await seedIdea(
        harness,
        name: 'Second idea',
        createdAt: base.add(const Duration(minutes: 1)),
      );
      await harness.pumpApp(tester);
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ideas'));
      await tester.pumpAndSettle();

      final Finder buttons = find.widgetWithText(TextButton, 'Make Task');
      expect(buttons, findsNWidgets(2));

      final Rect first = tester.getRect(buttons.first);
      final Rect second = tester.getRect(buttons.last);
      expect(second.top - first.bottom, greaterThanOrEqualTo(24));

      // "Its touch target is at least 48 × 48 dp."
      expect(first.height, greaterThanOrEqualTo(48));
      expect(first.width, greaterThanOrEqualTo(48));

      // "separated from the text block by at least 16 dp/px", and it never
      // overlaps the row-opens-Edit tap region (ROW-3). Measured against the
      // tap region itself rather than the glyphs: since B2 that region fills
      // the row, so the text's right edge would flatter the result.
      final Rect tapRegion = tester.getRect(
        find.byKey(ItemRow.tapRegionKey).first,
      );
      expect(first.left - tapRegion.right, greaterThanOrEqualTo(16));
      expect(tapRegion.overlaps(first), isFalse);
    });
  });

  group('§11.5.5: the database cannot be opened', () {
    testWidgets('the recovery screen names the problem and destroys nothing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const UnreadableDatabaseApp(
          DatabaseUnreadable(
            originalPath: r'C:\Users\someone\zen.sqlite',
            quarantinedPath:
                r'C:\Users\someone\zen.sqlite.unreadable-2026-09-23',
            cause: 'PRAGMA integrity_check returned "malformed"',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // "Do not crash to a blank screen and do not silently create an empty
      // database over the top, which would present as total data loss."
      expect(find.text('Zen cannot open its database'), findsOneWidget);
      expect(
        find.textContaining('Your data has not been deleted'),
        findsOneWidget,
      );
      // "keep the unreadable file in place, renamed with a timestamp".
      expect(
        find.text(r'C:\Users\someone\zen.sqlite.unreadable-2026-09-23'),
        findsOneWidget,
      );
      expect(find.textContaining('PRAGMA integrity_check'), findsOneWidget);

      // D-M4-9. Both offered actions are present and disabled until M6.
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Restore from backup…'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Import snapshot…'),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('a file that could not be moved is reported as still intact', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const UnreadableDatabaseApp(
          DatabaseUnreadable(
            originalPath: r'C:\Users\someone\zen.sqlite',
            quarantinedPath: null,
            cause: 'locked by another process',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Nowhere — the file is still where it was, and intact.'),
        findsOneWidget,
      );
    });
  });
}

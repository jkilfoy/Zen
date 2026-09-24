/// §5.9. `SCR-ARCHIVE`, and EOD-3's scheduling of the sweep.
///
/// M5's definition of done: "AC-10 passes through the Archived Tasks UI."
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_app/src/providers/app_providers.dart';
import 'package:zen_app/src/providers/archive_scheduler.dart';
import 'package:zen_data/zen_data.dart';
import 'package:zen_domain/zen_domain.dart';

import 'support/harness.dart';

/// A Toronto wall-clock reading as the UTC instant it denotes, under standard
/// time — the same longhand `end_of_day_test.dart` uses.
DateTime est(int y, int mo, int d, [int h = 0, int mi = 0]) =>
    DateTime.utc(y, mo, d, h + 5, mi);

void main() {
  /// Opens Archived Tasks through TODO-6's link.
  Future<void> openArchive(WidgetTester tester, ZenHarness harness) async {
    await harness.pumpApp(tester);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tapItem(tester, find.text('Archived tasks'));
  }

  testWidgets('ARCH-1: tasks are grouped by the logical day they completed', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    // AC-6's pair: both cross the same Wed 02:00 boundary, so both are filed
    // under Tuesday.
    await seedArchived(
      harness,
      name: 'Late Tuesday',
      at: est(2026, 1, 20, 23, 10),
    );
    await seedArchived(
      harness,
      name: 'Early Wednesday',
      at: est(2026, 1, 21, 1, 30),
    );
    // And one from the next logical day.
    await seedArchived(
      harness,
      name: 'Wednesday proper',
      at: est(2026, 1, 21, 9),
    );
    await openArchive(tester, harness);

    expect(find.text('Tue, Jan 20 2026'), findsOneWidget);
    expect(find.text('Wed, Jan 21 2026'), findsOneWidget);

    // "newest first".
    expect(
      tester.getTopLeft(find.text('Wed, Jan 21 2026')).dy,
      lessThan(tester.getTopLeft(find.text('Tue, Jan 20 2026')).dy),
    );
    // Both of Tuesday's are under the Tuesday header.
    expect(
      tester.getTopLeft(find.text('Late Tuesday')).dy,
      greaterThan(tester.getTopLeft(find.text('Tue, Jan 20 2026')).dy),
    );
  });

  testWidgets('ARCH-1: deleted tasks do not appear in the archive', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await seedTask(
      harness,
      name: 'Archived and deleted',
      status: TaskStatus.done,
      archived: true,
      deleted: true,
    );
    await openArchive(tester, harness);

    expect(find.text('Nothing archived yet.'), findsOneWidget);
  });

  testWidgets('ARCH-2: an archived row\'s circle cannot be tapped', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    final Task task = await seedArchived(harness, name: 'Water the plants');
    await openArchive(tester, harness);

    await tester.tap(find.byType(InkResponse).first, warnIfMissed: false);
    await tester.pumpAndSettle();

    final Task after = (await harness.tasks.findById(task.id))!;
    expect(after.isArchived, isTrue);
    expect(after.status, TaskStatus.done);
  });

  testWidgets('ARCH-3: tapping opens Edit Task read-only, with Unarchive', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    final Task task = await seedArchived(harness, name: 'Water the plants');
    await openArchive(tester, harness);

    await tester.tap(find.text('Water the plants'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Task'), findsOneWidget);
    // Read-only: no Save, no Delete, no editable fields, no "Add subtask".
    expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Delete'), findsNothing);
    expect(find.text('Add subtask'), findsNothing);
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Name')).readOnly,
      isTrue,
    );
    // "plus an `"Unarchive"` action".
    expect(find.widgetWithText(FilledButton, 'Unarchive'), findsOneWidget);

    await tapItem(tester, find.widgetWithText(FilledButton, 'Unarchive'));

    // "Unarchiving sets `isArchived = false`, clears `archivedAt`, sets status
    // to `Todo` and clears `completedAt`."
    final Task after = (await harness.tasks.findById(task.id))!;
    expect(after.isArchived, isFalse);
    expect(after.archivedAt, isNull);
    expect(after.status, TaskStatus.todo);
    expect(after.completedAt, isNull);
    // "The Task then reappears in the To Do list."
    expect(find.text('Water the plants'), findsOneWidget);
  });

  testWidgets(
    'AC-10: unarchiving is blocked while an active task holds the name',
    (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      // AC-9's state: one archived, one active, same name.
      await seedArchived(harness, name: 'Water the plants');
      await seedTask(harness, name: 'Water the plants');
      await openArchive(tester, harness);

      await tester.tap(find.text('Water the plants'));
      await tester.pumpAndSettle();

      // "the action is blocked with …"
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Unarchive'),
            )
            .onPressed,
        isNull,
      );
      expect(find.text(const ActiveTaskHoldsName().message), findsOneWidget);
      // "No rename option is offered."
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Name'))
            .readOnly,
        isTrue,
      );
    },
  );

  testWidgets('SEARCH-3, AC-10: the same applies to restoring a deleted task', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await seedTask(harness, name: 'Water the plants', deleted: true);
    await seedTask(harness, name: 'Water the plants');
    await harness.pumpApp(tester);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    // SEARCH-2. Deleted is off by default, so select it.
    await tester.tap(find.widgetWithText(FilterChip, 'Deleted'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Water the plants').first);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Restore'))
          .onPressed,
      isNull,
    );
    expect(find.text(const ActiveTaskHoldsName().message), findsOneWidget);
  });

  testWidgets('DEL-2, SEARCH-3: an unobstructed restore succeeds', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    final Task task = await seedTask(
      harness,
      name: 'Water the plants',
      deleted: true,
    );
    await harness.pumpApp(tester);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Deleted'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Water the plants'));
    await tester.pumpAndSettle();

    await tapItem(tester, find.widgetWithText(FilledButton, 'Restore'));

    final Task after = (await harness.tasks.findById(task.id))!;
    expect(after.isDeleted, isFalse);
    expect(after.deletedAt, isNull);
    // DEL-2. "Restoring … leaves the status as it was."
    expect(after.status, TaskStatus.todo);
  });

  group('EOD-3: the sweep runs at start and at each boundary', () {
    /// A sweeper over the harness's repositories, as `main.dart` builds it.
    ArchiveScheduler schedulerFor(ZenHarness harness) => ArchiveScheduler(
      sweeper: ArchiveSweeper(
        clock: harness.clock,
        zone: harness.container.read(timeZoneRulesProvider),
        settings: harness.settings,
        tasks: harness.tasks,
      ),
      clock: harness.clock,
    );

    testWidgets(
      'AC-6: a replica closed across a boundary archives on its next start',
      (WidgetTester tester) async {
        // "Given EoD = 02:00 and a task completed Tue 23:10. The app is closed
        // until Thu 09:00."
        final ZenHarness harness = ZenHarness(now: est(2026, 1, 22, 9));
        final Task task = await seedTask(
          harness,
          name: 'Water the plants',
          status: TaskStatus.done,
          createdAt: est(2026, 1, 20, 23, 10),
        );

        final ArchiveScheduler scheduler = schedulerFor(harness);
        addTearDown(scheduler.dispose);
        await tester.runAsync(scheduler.start);

        // "then the task is archived with `archivedAt` = Wed 02:00 local."
        final Task after = (await harness.tasks.findById(task.id))!;
        expect(after.isArchived, isTrue);
        expect(after.archivedAt, est(2026, 1, 21, 2));
        // EOD-2A. Archiving is a system action and must not move `updatedAt`.
        expect(after.updatedAt, task.updatedAt);

        // "It is absent from To Do and present in Archived Tasks under
        // Tuesday."
        await openArchive(tester, harness);
        expect(find.text('Tue, Jan 20 2026'), findsOneWidget);
        expect(find.text('Water the plants'), findsOneWidget);
      },
    );

    testWidgets('the sweep is idempotent, so re-running it costs nothing', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness(now: est(2026, 1, 22, 9));
      final Task task = await seedTask(
        harness,
        name: 'Water the plants',
        status: TaskStatus.done,
        createdAt: est(2026, 1, 20, 23, 10),
      );

      final ArchiveScheduler scheduler = schedulerFor(harness);
      addTearDown(scheduler.dispose);
      await tester.runAsync(scheduler.start);
      final Task once = (await harness.tasks.findById(task.id))!;
      await tester.runAsync(scheduler.sweepAndReschedule);
      final Task twice = (await harness.tasks.findById(task.id))!;

      expect(twice, once);
    });

    testWidgets('a task not yet past its boundary is left alone', (
      WidgetTester tester,
    ) async {
      // Completed Tue 23:10; it is now Wed 01:00, before the Wed 02:00
      // boundary.
      final ZenHarness harness = ZenHarness(now: est(2026, 1, 21, 1));
      final Task task = await seedTask(
        harness,
        name: 'Water the plants',
        status: TaskStatus.done,
        createdAt: est(2026, 1, 20, 23, 10),
      );

      final ArchiveScheduler scheduler = schedulerFor(harness);
      addTearDown(scheduler.dispose);
      await tester.runAsync(scheduler.start);

      expect((await harness.tasks.findById(task.id))!.isArchived, isFalse);
    });
  });
}

/// A Done, archived Task whose completion instant is [at].
Future<Task> seedArchived(
  ZenHarness harness, {
  required String name,
  DateTime? at,
}) => seedTask(
  harness,
  name: name,
  status: TaskStatus.done,
  archived: true,
  createdAt: at ?? est(2026, 1, 20, 23, 10),
);

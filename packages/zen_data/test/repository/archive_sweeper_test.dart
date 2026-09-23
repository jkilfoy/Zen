/// §4.5, §11.5.4, AC-6. The archive sweep against a real database.
///
/// AC-6 is M3's to prove: "Given EoD = 02:00 and a task completed Tue 23:10.
/// The app is closed until Thu 09:00. When the app starts, then the task is
/// archived with `archivedAt` = Wed 02:00 local." The domain already tests
/// `archiveBoundaryAfter` at exact instants including both DST transitions;
/// what is new here is that the sweep selects the right rows, writes the right
/// boundary, and holds EOD-2A.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zen_data/zen_data.dart';
import 'package:zen_domain/testing.dart';
import 'package:zen_domain/zen_domain.dart';

import '../support/harness.dart';

void main() {
  late TestRepositories repos;

  const String toronto = TorontoTimeZoneRules.zoneId;
  const LocalTime twoAm = LocalTime(2, 0);

  /// The instant at which the Toronto wall clock reads [hour]:[minute] on the
  /// given local date, in September — EDT, so UTC−04:00.
  DateTime torontoEdt(int day, int hour, int minute) =>
      DateTime.utc(2026, 9, day, hour, minute).add(const Duration(hours: 4));

  setUp(() => repos = TestRepositories());

  group('AC-6: archiving across days', () {
    test(
      'a task completed Tue 23:10 archives at Wed 02:00, seen Thu 09:00',
      () async {
        // Tuesday 22 September 2026, 23:10 local.
        final DateTime completed = torontoEdt(22, 23, 10);
        await repos.tasks.create(
          aTask(
            id: 't1',
            named: 'Write report',
            status: TaskStatus.done,
            createdAt: completed,
            updatedAt: completed,
            completedAt: completed,
          ),
        );

        // Thursday 09:00 local: the app has been closed across one boundary.
        final List<Task> archived = await repos.tasks.runArchiveSweep(
          nowUtc: torontoEdt(24, 9, 0),
          endOfDay: twoAm,
          zoneId: toronto,
        );

        expect(archived, hasLength(1));
        expect(
          archived.single.archivedAt,
          torontoEdt(23, 2, 0),
          reason: 'the boundary it crossed, not the instant the sweep ran',
        );

        final Task stored = (await repos.tasks.findById('t1'))!;
        expect(stored.isArchived, isTrue);
        expect(stored.archivedAt, torontoEdt(23, 2, 0));
        expect(stored.completedAt, completed, reason: 'INV-1 is untouched');
      },
    );

    test('EOD-6: it leaves the To Do list and joins the archive', () async {
      final DateTime completed = torontoEdt(22, 23, 10);
      await repos.tasks.create(
        aTask(
          id: 't1',
          named: 'Write report',
          status: TaskStatus.done,
          createdAt: completed,
          updatedAt: completed,
          completedAt: completed,
        ),
      );

      await repos.tasks.runArchiveSweep(
        nowUtc: torontoEdt(24, 9, 0),
        endOfDay: twoAm,
        zoneId: toronto,
      );

      expect(await repos.tasks.watchActive().first, isEmpty);
      expect((await repos.tasks.watchArchived().first).single.id, 't1');
    });

    test('EOD-2A: the sweep does not move updatedAt', () async {
      // The app is running, the boundary passes, and the user renames the Task
      // before the sweep fires. Moving `updatedAt` back to the boundary would
      // make the rename look older than it is, and §9.3 step 4 resolves by
      // latest `updatedAt` — a peer with pre-edit content could then win.
      final DateTime completed = torontoEdt(22, 23, 10);
      final DateTime renamed = torontoEdt(23, 8, 0);
      await repos.tasks.create(
        aTask(
          id: 't1',
          named: 'Write report',
          status: TaskStatus.done,
          createdAt: completed,
          updatedAt: renamed,
          completedAt: completed,
        ),
      );

      await repos.tasks.runArchiveSweep(
        nowUtc: torontoEdt(24, 9, 0),
        endOfDay: twoAm,
        zoneId: toronto,
      );

      final Task stored = (await repos.tasks.findById('t1'))!;
      expect(stored.updatedAt, renamed);
      expect(stored.archivedAt, torontoEdt(23, 2, 0));
      expect(stored.archivedAt!.isBefore(stored.updatedAt), isTrue);
    });

    test(
      'EOD-2: a task completed just before the boundary still archives',
      () async {
        // "A task completed Wed 01:30 also archives at Wed 02:00."
        final DateTime completed = torontoEdt(23, 1, 30);
        await repos.tasks.create(
          aTask(
            id: 't1',
            named: 'Late one',
            status: TaskStatus.done,
            createdAt: completed,
            updatedAt: completed,
            completedAt: completed,
          ),
        );

        final List<Task> archived = await repos.tasks.runArchiveSweep(
          nowUtc: torontoEdt(23, 9, 0),
          endOfDay: twoAm,
          zoneId: toronto,
        );

        expect(archived.single.archivedAt, torontoEdt(23, 2, 0));
      },
    );

    test(
      'EOD-2: a task completed after the boundary waits for the next',
      () async {
        // "A task completed Wed 02:30 archives at Thu 02:00."
        final DateTime completed = torontoEdt(23, 2, 30);
        await repos.tasks.create(
          aTask(
            id: 't1',
            named: 'Just missed it',
            status: TaskStatus.done,
            createdAt: completed,
            updatedAt: completed,
            completedAt: completed,
          ),
        );

        expect(
          await repos.tasks.runArchiveSweep(
            nowUtc: torontoEdt(23, 23, 0),
            endOfDay: twoAm,
            zoneId: toronto,
          ),
          isEmpty,
        );

        final List<Task> later = await repos.tasks.runArchiveSweep(
          nowUtc: torontoEdt(24, 9, 0),
          endOfDay: twoAm,
          zoneId: toronto,
        );
        expect(later.single.archivedAt, torontoEdt(24, 2, 0));
      },
    );
  });

  group('§11.5.4: what the sweep does and does not touch', () {
    test('it ignores Todo, Blocked, archived and deleted Tasks', () async {
      final DateTime old = torontoEdt(20, 12, 0);
      await repos.tasks.create(aTask(id: 'todo', named: 'Todo one'));
      await repos.tasks.create(
        aTask(id: 'blocked', named: 'Blocked one', status: TaskStatus.blocked),
      );
      await repos.tasks.create(
        aTask(
          id: 'archived',
          named: 'Already archived',
          status: TaskStatus.done,
          createdAt: old,
          updatedAt: old,
          completedAt: old,
          isArchived: true,
          archivedAt: torontoEdt(21, 2, 0),
        ),
      );
      await repos.tasks.create(
        aTask(
          id: 'deleted',
          named: 'Deleted one',
          status: TaskStatus.done,
          createdAt: old,
          updatedAt: old,
          completedAt: old,
          isDeleted: true,
          deletedAt: old,
        ),
      );

      expect(
        await repos.tasks.runArchiveSweep(
          nowUtc: torontoEdt(24, 9, 0),
          endOfDay: twoAm,
          zoneId: toronto,
        ),
        isEmpty,
      );
    });

    test(
      'EOD-3: it is idempotent, so start plus foreground costs nothing',
      () async {
        final DateTime completed = torontoEdt(22, 23, 10);
        await repos.tasks.create(
          aTask(
            id: 't1',
            named: 'Write report',
            status: TaskStatus.done,
            createdAt: completed,
            updatedAt: completed,
            completedAt: completed,
          ),
        );

        final DateTime now = torontoEdt(24, 9, 0);
        final List<Task> first = await repos.tasks.runArchiveSweep(
          nowUtc: now,
          endOfDay: twoAm,
          zoneId: toronto,
        );
        final List<Task> second = await repos.tasks.runArchiveSweep(
          nowUtc: now,
          endOfDay: twoAm,
          zoneId: toronto,
        );

        expect(first, hasLength(1));
        expect(second, isEmpty);
        expect(
          (await repos.tasks.findById('t1'))!.archivedAt,
          torontoEdt(23, 2, 0),
        );
      },
    );

    test('EOD-3: a replica closed across several boundaries needs no catch-up '
        'loop', () async {
      for (final (String id, int day) in <(String, int)>[
        ('t1', 18),
        ('t2', 19),
        ('t3', 20),
      ]) {
        final DateTime completed = torontoEdt(day, 23, 10);
        await repos.tasks.create(
          aTask(
            id: id,
            named: 'Task $id',
            status: TaskStatus.done,
            createdAt: completed,
            updatedAt: completed,
            completedAt: completed,
          ),
        );
      }

      final List<Task> archived = await repos.tasks.runArchiveSweep(
        nowUtc: torontoEdt(24, 9, 0),
        endOfDay: twoAm,
        zoneId: toronto,
      );

      expect(archived, hasLength(3));
      expect(archived.map((Task t) => t.archivedAt), <DateTime>[
        torontoEdt(19, 2, 0),
        torontoEdt(20, 2, 0),
        torontoEdt(21, 2, 0),
      ], reason: 'each records its own boundary, not a shared sweep instant');
    });

    test('a Done Task with Done subtasks archives with them intact', () async {
      final DateTime completed = torontoEdt(22, 23, 10);
      await repos.tasks.create(
        aTask(
          id: 't1',
          named: 'Write report',
          status: TaskStatus.done,
          subtasks: <Subtask>[
            aSubtask(
              id: 's1',
              status: TaskStatus.done,
              createdAt: completed,
              updatedAt: completed,
            ),
          ],
          createdAt: completed,
          updatedAt: completed,
          completedAt: completed,
        ),
      );

      await repos.tasks.runArchiveSweep(
        nowUtc: torontoEdt(24, 9, 0),
        endOfDay: twoAm,
        zoneId: toronto,
      );

      expect((await repos.tasks.findById('t1'))!.subtasks, hasLength(1));
    });

    test('HIST-2: archiving is logged at the boundary instant', () async {
      final DateTime completed = torontoEdt(22, 23, 10);
      await repos.tasks.create(
        aTask(
          id: 't1',
          named: 'Write report',
          status: TaskStatus.done,
          createdAt: completed,
          updatedAt: completed,
          completedAt: completed,
        ),
      );

      await repos.tasks.runArchiveSweep(
        nowUtc: torontoEdt(24, 9, 0),
        endOfDay: twoAm,
        zoneId: toronto,
      );

      final ItemEvent archived = (await repos.events.forItem('t1'))
          .firstWhere((ItemEvent e) => e.type == ItemEventType.archived);
      expect(archived.timestamp, torontoEdt(23, 2, 0));
    });
  });

  group('§11.5.4: ArchiveSweeper reads the settings and the zone', () {
    test('it uses settings.endOfDay rather than a hard-coded 02:00', () async {
      final DateTime completed = torontoEdt(22, 23, 10);
      await repos.tasks.create(
        aTask(
          id: 't1',
          named: 'Write report',
          status: TaskStatus.done,
          createdAt: completed,
          updatedAt: completed,
          completedAt: completed,
        ),
      );
      await repos.settings.write(Settings(endOfDay: const LocalTime(5, 0)));

      final ArchiveSweeper sweeper = ArchiveSweeper(
        clock: FakeClock(torontoEdt(23, 4, 0), zoneId: toronto),
        zone: repos.zone,
        settings: repos.settings,
        tasks: repos.tasks,
      );

      expect(
        await sweeper.sweep(),
        isEmpty,
        reason: '04:00 local is before the configured 05:00 boundary',
      );

      final ArchiveSweeper later = ArchiveSweeper(
        clock: FakeClock(torontoEdt(23, 6, 0), zoneId: toronto),
        zone: repos.zone,
        settings: repos.settings,
        tasks: repos.tasks,
      );
      expect((await later.sweep()).single.archivedAt, torontoEdt(23, 5, 0));
    });

    test(
      'EOD-3: nextBoundaryAfter is what a timer would be set from',
      () async {
        final ArchiveSweeper sweeper = ArchiveSweeper(
          clock: FakeClock(torontoEdt(22, 23, 10), zoneId: toronto),
          zone: repos.zone,
          settings: repos.settings,
          tasks: repos.tasks,
        );

        expect(
          await sweeper.nextBoundaryAfter(torontoEdt(22, 23, 10)),
          torontoEdt(23, 2, 0),
        );
      },
    );
  });
}

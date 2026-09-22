import 'package:test/test.dart';
import 'package:zen_domain/testing.dart';
import 'package:zen_domain/zen_domain.dart';

import '../support/fixtures.dart';

/// §4.5, §11.12 item 4. The End-of-Day calculator at exact boundary instants,
/// including both DST transitions and the spring-forward case where the
/// configured time does not exist.
void main() {
  const TorontoTimeZoneRules toronto = TorontoTimeZoneRules();
  const String zone = TorontoTimeZoneRules.zoneId;
  const LocalTime twoAm = LocalTime.endOfDayDefault;

  /// A Toronto wall-clock reading as the UTC instant it denotes, given the
  /// offset in effect. Written out longhand so the tests state real instants
  /// rather than leaning on the code under test.
  DateTime est(int y, int mo, int d, [int h = 0, int mi = 0]) =>
      DateTime.utc(y, mo, d, h + 5, mi);
  DateTime edt(int y, int mo, int d, [int h = 0, int mi = 0]) =>
      DateTime.utc(y, mo, d, h + 4, mi);

  group('EOD-1: the fixture models America/Toronto', () {
    test('standard time in January is UTC-5', () {
      expect(
        toronto.offsetAt(DateTime.utc(2026, 1, 15), zone),
        const Duration(hours: -5),
      );
    });

    test('daylight time in July is UTC-4', () {
      expect(
        toronto.offsetAt(DateTime.utc(2026, 7, 15), zone),
        const Duration(hours: -4),
      );
    });

    test('daylight time starts at 07:00Z on the second Sunday in March', () {
      // 2026-03-08 is the second Sunday in March.
      expect(
        toronto.offsetAt(DateTime.utc(2026, 3, 8, 6, 59), zone),
        const Duration(hours: -5),
      );
      expect(
        toronto.offsetAt(DateTime.utc(2026, 3, 8, 7), zone),
        const Duration(hours: -4),
      );
    });

    test('daylight time ends at 06:00Z on the first Sunday in November', () {
      // 2026-11-01 is the first Sunday in November.
      expect(
        toronto.offsetAt(DateTime.utc(2026, 11, 1, 5, 59), zone),
        const Duration(hours: -4),
      );
      expect(
        toronto.offsetAt(DateTime.utc(2026, 11, 1, 6), zone),
        const Duration(hours: -5),
      );
    });

    test('an unknown zone is programmer error', () {
      expect(
        () => toronto.offsetAt(DateTime.utc(2026), 'Europe/Paris'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('EOD-2: the first boundary strictly after completedAt', () {
    test('a task completed Tue 23:10 archives at Wed 02:00', () {
      // The specification's own first example.
      expect(
        archiveBoundaryAfter(est(2026, 1, 20, 23, 10), twoAm, zone, toronto),
        est(2026, 1, 21, 2),
      );
    });

    test('a task completed Wed 01:30 also archives at Wed 02:00', () {
      expect(
        archiveBoundaryAfter(est(2026, 1, 21, 1, 30), twoAm, zone, toronto),
        est(2026, 1, 21, 2),
      );
    });

    test('a task completed Wed 02:30 archives at Thu 02:00', () {
      expect(
        archiveBoundaryAfter(est(2026, 1, 21, 2, 30), twoAm, zone, toronto),
        est(2026, 1, 22, 2),
      );
    });

    test('completed exactly on a boundary archives at the next one', () {
      // "strictly after" (EOD-2).
      expect(
        archiveBoundaryAfter(est(2026, 1, 21, 2), twoAm, zone, toronto),
        est(2026, 1, 22, 2),
      );
    });

    test('one millisecond before a boundary archives at that boundary', () {
      expect(
        archiveBoundaryAfter(
          est(2026, 1, 21, 2).subtract(const Duration(milliseconds: 1)),
          twoAm,
          zone,
          toronto,
        ),
        est(2026, 1, 21, 2),
      );
    });

    test('an endOfDay of midnight still works', () {
      expect(
        archiveBoundaryAfter(
          est(2026, 1, 20, 10),
          const LocalTime(0, 0),
          zone,
          toronto,
        ),
        est(2026, 1, 21),
      );
    });

    test('a late endOfDay puts the boundary on the same local day', () {
      expect(
        archiveBoundaryAfter(
          est(2026, 1, 20, 10),
          const LocalTime(23, 30),
          zone,
          toronto,
        ),
        est(2026, 1, 20, 23, 30),
      );
    });
  });

  group('EOD-5: DST, spring forward', () {
    // 2026-03-08: 02:00 EST does not exist. The clock goes 01:59:59 EST to
    // 03:00:00 EDT at 07:00Z. With the factory default endOfDay of 02:00, this
    // is exactly the case EOD-5 calls out.
    test(
      'the configured time does not exist, so the transition instant is used',
      () {
        expect(
          archiveBoundaryAfter(est(2026, 3, 7, 23), twoAm, zone, toronto),
          DateTime.utc(2026, 3, 8, 7),
        );
      },
    );

    test(
      'that instant reads 03:00 local, the first valid time after 02:00',
      () {
        final DateTime boundary = DateTime.utc(2026, 3, 8, 7);
        final DateTime wall = boundary.add(toronto.offsetAt(boundary, zone));
        expect(wall, DateTime.utc(2026, 3, 8, 3));
      },
    );

    test('a task completed just after the gap archives the following day', () {
      expect(
        archiveBoundaryAfter(edt(2026, 3, 8, 10), twoAm, zone, toronto),
        edt(2026, 3, 9, 2),
      );
    });

    test('an endOfDay of 01:30 is unaffected by the gap', () {
      expect(
        archiveBoundaryAfter(
          est(2026, 3, 7, 23),
          const LocalTime(1, 30),
          zone,
          toronto,
        ),
        est(2026, 3, 8, 1, 30),
      );
    });

    test(
      'an endOfDay of 03:00 lands on the first instant of daylight time',
      () {
        expect(
          archiveBoundaryAfter(
            est(2026, 3, 7, 23),
            const LocalTime(3, 0),
            zone,
            toronto,
          ),
          DateTime.utc(2026, 3, 8, 7),
        );
      },
    );
  });

  group('EOD-5: DST, fall back', () {
    // 2026-11-01: 01:00-01:59 EDT repeats as 01:00-01:59 EST. The clock goes
    // 01:59:59 EDT to 01:00:00 EST at 06:00Z.
    test('an ambiguous 01:30 resolves to the earlier occurrence', () {
      // 01:30 EDT is 05:30Z; 01:30 EST is 06:30Z. D-M1-5 takes the earlier,
      // consistent with EOD-2 asking for the first boundary after completion.
      expect(
        archiveBoundaryAfter(
          edt(2026, 10, 31, 23),
          const LocalTime(1, 30),
          zone,
          toronto,
        ),
        DateTime.utc(2026, 11, 1, 5, 30),
      );
    });

    test('02:00 is unambiguous on the fall-back date and reads as EST', () {
      // The clock never reaches 02:00 EDT, so 02:00 occurs once, at 07:00Z.
      expect(
        archiveBoundaryAfter(edt(2026, 10, 31, 23), twoAm, zone, toronto),
        DateTime.utc(2026, 11, 1, 7),
      );
    });

    test('a task completed inside the repeated hour still archives correctly', () {
      // 01:30 EDT, the first pass through the repeated hour. The next boundary
      // is 02:00 the same local date, at 07:00Z.
      expect(
        archiveBoundaryAfter(
          DateTime.utc(2026, 11, 1, 5, 30),
          twoAm,
          zone,
          toronto,
        ),
        DateTime.utc(2026, 11, 1, 7),
      );
    });

    test('and so does one completed in the second pass through that hour', () {
      // 01:30 EST, at 06:30Z.
      expect(
        archiveBoundaryAfter(
          DateTime.utc(2026, 11, 1, 6, 30),
          twoAm,
          zone,
          toronto,
        ),
        DateTime.utc(2026, 11, 1, 7),
      );
    });
  });

  group('EOD-3, AC-6: a replica closed across boundaries', () {
    test(
      'AC-6: closed from Tue 23:10 to Thu 09:00, it archives at Wed 02:00',
      () {
        final DateTime completedAt = est(2026, 1, 20, 23, 10);
        final DateTime restartedAt = est(2026, 1, 22, 9);
        final Task task = aTask(
          status: TaskStatus.done,
          completedAt: completedAt,
          createdAt: est(2026, 1, 20, 8),
          updatedAt: completedAt,
        );

        expect(
          isDueForArchive(task, restartedAt, twoAm, zone, toronto),
          isTrue,
        );
        expect(
          archiveBoundaryAfter(completedAt, twoAm, zone, toronto),
          est(2026, 1, 21, 2),
        );
      },
    );

    test(
      'the boundary derives from completedAt, not from when the sweep ran',
      () {
        // Closed for a fortnight; the answer does not move.
        final DateTime completedAt = est(2026, 1, 20, 23, 10);
        expect(
          archiveBoundaryAfter(completedAt, twoAm, zone, toronto),
          archiveBoundaryAfter(completedAt, twoAm, zone, toronto),
        );
        expect(
          isDueForArchive(
            task0(completedAt),
            est(2026, 2, 3, 9),
            twoAm,
            zone,
            toronto,
          ),
          isTrue,
        );
      },
    );
  });

  group('EOD-2, EOD-3: which tasks the sweep picks up', () {
    final DateTime completedAt = est(2026, 1, 20, 23, 10);
    final DateTime beforeBoundary = est(2026, 1, 21, 1, 59);
    final DateTime atBoundary = est(2026, 1, 21, 2);

    test('a Done task is not due before its boundary', () {
      expect(
        isDueForArchive(
          task0(completedAt),
          beforeBoundary,
          twoAm,
          zone,
          toronto,
        ),
        isFalse,
      );
    });

    test('a Done task is due exactly at its boundary', () {
      expect(
        isDueForArchive(task0(completedAt), atBoundary, twoAm, zone, toronto),
        isTrue,
      );
    });

    test('a Todo task is never due', () {
      expect(
        isDueForArchive(aTask(), atBoundary, twoAm, zone, toronto),
        isFalse,
      );
    });

    test('a Blocked task is never due', () {
      expect(
        isDueForArchive(
          aTask(status: TaskStatus.blocked),
          atBoundary,
          twoAm,
          zone,
          toronto,
        ),
        isFalse,
      );
    });

    test('an already-archived task is not due again', () {
      expect(
        isDueForArchive(
          aTask(
            status: TaskStatus.done,
            completedAt: completedAt,
            isArchived: true,
            archivedAt: atBoundary,
          ),
          atBoundary,
          twoAm,
          zone,
          toronto,
        ),
        isFalse,
      );
    });

    test('a soft-deleted task is not archived', () {
      expect(
        isDueForArchive(
          aTask(
            status: TaskStatus.done,
            completedAt: completedAt,
            isDeleted: true,
          ),
          atBoundary,
          twoAm,
          zone,
          toronto,
        ),
        isFalse,
      );
    });
  });

  group('EOD-4: changing endOfDay applies to future sweeps only', () {
    test('a new endOfDay moves the boundary of an unarchived task', () {
      final DateTime completedAt = est(2026, 1, 20, 23, 10);
      expect(
        archiveBoundaryAfter(completedAt, twoAm, zone, toronto),
        est(2026, 1, 21, 2),
      );
      expect(
        archiveBoundaryAfter(completedAt, const LocalTime(5, 0), zone, toronto),
        est(2026, 1, 21, 5),
      );
    });

    test('an already-archived task keeps its archivedAt', () {
      // EOD-4: "Already-archived tasks are not un-archived." The boundary is
      // stored, so a later change to the setting cannot move it.
      final Task archived = aTask(
        status: TaskStatus.done,
        completedAt: est(2026, 1, 20, 23, 10),
        isArchived: true,
        archivedAt: est(2026, 1, 21, 2),
      );
      expect(archived.archivedAt, est(2026, 1, 21, 2));
      expect(
        isDueForArchive(archived, est(2026, 1, 25), twoAm, zone, toronto),
        isFalse,
      );
    });
  });

  group('EOD-5: a zone with no transitions', () {
    test('UTC boundaries are plain 24-hour steps', () {
      expect(
        archiveBoundaryAfter(
          DateTime.utc(2026, 3, 7, 23),
          twoAm,
          'UTC',
          FixedOffsetTimeZoneRules.utc,
        ),
        DateTime.utc(2026, 3, 8, 2),
      );
    });

    test('a positive offset zone works the same way', () {
      // UTC+05:30. 23:00 local on the 7th is 17:30Z; the next 02:00 local is
      // 20:30Z on the 7th.
      expect(
        archiveBoundaryAfter(
          DateTime.utc(2026, 3, 7, 17, 30),
          twoAm,
          'Asia/Kolkata',
          const FixedOffsetTimeZoneRules(Duration(hours: 5, minutes: 30)),
        ),
        DateTime.utc(2026, 3, 7, 20, 30),
      );
    });
  });
}

/// A Done task completed at [completedAt], for the sweep tests.
Task task0(DateTime completedAt) => aTask(
  status: TaskStatus.done,
  createdAt: completedAt.subtract(const Duration(hours: 8)),
  updatedAt: completedAt,
  completedAt: completedAt,
);

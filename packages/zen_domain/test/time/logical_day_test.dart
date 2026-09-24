/// ARCH-1, AC-6. `logicalDayOf`: which day an archived Task is filed under.
library;

import 'package:test/test.dart';
import 'package:zen_domain/testing.dart';
import 'package:zen_domain/zen_domain.dart';

void main() {
  const TorontoTimeZoneRules toronto = TorontoTimeZoneRules();
  const String zone = TorontoTimeZoneRules.zoneId;
  const LocalTime twoAm = LocalTime.endOfDayDefault;

  /// A Toronto wall-clock reading as the UTC instant it denotes, written out
  /// longhand as `end_of_day_test.dart` does.
  DateTime est(int y, int mo, int d, [int h = 0, int mi = 0]) =>
      DateTime.utc(y, mo, d, h + 5, mi);
  DateTime edt(int y, int mo, int d, [int h = 0, int mi = 0]) =>
      DateTime.utc(y, mo, d, h + 4, mi);

  /// The calendar date [logicalDayOf] returns, as a wall-clock carrier.
  DateTime day(int y, int mo, int d) => DateTime.utc(y, mo, d);

  group('ARCH-1: the logical day an instant belongs to', () {
    test('AC-6: completed Tue 23:10 with EoD 02:00 is filed under Tuesday', () {
      expect(
        logicalDayOf(est(2026, 1, 20, 23, 10), twoAm, zone, toronto),
        day(2026, 1, 20),
      );
    });

    test(
      'AC-6: completed Wed 01:30 is also Tuesday — both cross Wed 02:00',
      () {
        expect(
          logicalDayOf(est(2026, 1, 21, 1, 30), twoAm, zone, toronto),
          day(2026, 1, 20),
        );
      },
    );

    test('completed Wed 02:30 is Wednesday: it crosses Thu 02:00', () {
      expect(
        logicalDayOf(est(2026, 1, 21, 2, 30), twoAm, zone, toronto),
        day(2026, 1, 21),
      );
    });

    test('exactly at the boundary belongs to the day that is closing', () {
      // EOD-2's boundary is the first one *strictly after* `completedAt`, so an
      // instant at 02:00 exactly crosses the next day's, and therefore belongs
      // to the day that just began.
      expect(
        logicalDayOf(est(2026, 1, 21, 2), twoAm, zone, toronto),
        day(2026, 1, 21),
      );
    });

    test('EoD at midnight makes the logical day the calendar day', () {
      const LocalTime midnight = LocalTime(0, 0);

      expect(
        logicalDayOf(est(2026, 1, 20, 23, 10), midnight, zone, toronto),
        day(2026, 1, 20),
      );
      expect(
        logicalDayOf(est(2026, 1, 21, 0, 30), midnight, zone, toronto),
        day(2026, 1, 21),
      );
    });

    test('EOD-5: a spring-forward day still groups correctly', () {
      // 2026-03-08, 02:00 does not exist in Toronto. `archiveBoundaryAfter`
      // returns the first valid instant after it, whose wall date is still the
      // 8th, so a task completed on the 7th is filed under the 7th.
      expect(
        logicalDayOf(est(2026, 3, 7, 23), twoAm, zone, toronto),
        day(2026, 3, 7),
      );
    });

    test('EOD-5: a fall-back day still groups correctly', () {
      // 2026-11-01, 01:30 happens twice. Either reading is before that day's
      // 02:00 boundary, so the task belongs to October 31st.
      expect(
        logicalDayOf(edt(2026, 11, 1, 1, 30), twoAm, zone, toronto),
        day(2026, 10, 31),
      );
    });

    test('the returned carrier has no time-of-day component', () {
      final DateTime result = logicalDayOf(
        est(2026, 1, 20, 23, 10),
        twoAm,
        zone,
        toronto,
      );

      expect(result.isUtc, isTrue);
      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
    });
  });
}

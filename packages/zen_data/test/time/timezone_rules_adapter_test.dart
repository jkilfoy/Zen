/// EOD-5, D-M1-2. The `package:timezone` adapter for the domain's port.
///
/// The interesting assertion is the cross-check: `zen_domain`'s
/// [TorontoTimeZoneRules] is a hand-written fixture modelling the post-2007
/// North American rules, and the whole EoD calculator is tested against it. If
/// the real IANA database and that fixture disagreed, every EoD test in
/// `zen_domain` would be proving something about a zone that does not exist.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zen_data/zen_data.dart';
import 'package:zen_domain/testing.dart';
import 'package:zen_domain/zen_domain.dart';

void main() {
  late TimeZoneDatabaseRules rules;

  const TorontoTimeZoneRules fixture = TorontoTimeZoneRules();
  const String toronto = TorontoTimeZoneRules.zoneId;

  setUp(() => rules = TimeZoneDatabaseRules());

  group('EOD-5: offsets', () {
    test('Toronto is UTC-5 in January and UTC-4 in July', () {
      expect(
        rules.offsetAt(DateTime.utc(2026, 1, 15, 12), toronto),
        const Duration(hours: -5),
      );
      expect(
        rules.offsetAt(DateTime.utc(2026, 7, 15, 12), toronto),
        const Duration(hours: -4),
      );
    });

    test('UTC is UTC', () {
      expect(
        rules.offsetAt(DateTime.utc(2026, 1, 15, 12), 'UTC'),
        Duration.zero,
      );
    });

    test('a half-hour zone is handled, not rounded', () {
      // Kolkata is UTC+05:30 all year — a Duration, not a whole number of
      // hours, which is why the port's return type is one.
      expect(
        rules.offsetAt(DateTime.utc(2026, 1, 15, 12), 'Asia/Kolkata'),
        const Duration(hours: 5, minutes: 30),
      );
    });

    test('an unknown zone is an ArgumentError, per the port contract', () {
      expect(
        () => rules.offsetAt(DateTime.utc(2026), 'Mars/Olympus_Mons'),
        throwsArgumentError,
      );
    });
  });

  group('D-M1-2: the fixture and the real database agree', () {
    test('at every hour across both 2026 DST transitions', () {
      // Two 48-hour windows around the spring-forward and fall-back instants,
      // which is where a fixture is most likely to be wrong.
      for (final DateTime start in <DateTime>[
        DateTime.utc(2026, 3, 7),
        DateTime.utc(2026, 10, 31),
      ]) {
        for (int hour = 0; hour < 96; hour++) {
          final DateTime instant = start.add(Duration(hours: hour));
          expect(
            rules.offsetAt(instant, toronto),
            fixture.offsetAt(instant, toronto),
            reason: 'offsets differ at $instant',
          );
        }
      }
    });

    test('on the first of every month from 2024 to 2030', () {
      for (int year = 2024; year <= 2030; year++) {
        for (int month = 1; month <= 12; month++) {
          final DateTime instant = DateTime.utc(year, month, 1, 12);
          expect(
            rules.offsetAt(instant, toronto),
            fixture.offsetAt(instant, toronto),
            reason: 'offsets differ at $instant',
          );
        }
      }
    });

    test('EOD-5: the spring-forward gap resolves the same way in both', () {
      // 02:00 local does not exist on 8 March 2026. EOD-5: "use the first
      // valid instant after it", which is the transition itself, 07:00Z.
      final DateTime viaFixture = instantOfLocalWallTime(
        year: 2026,
        month: 3,
        day: 8,
        time: const LocalTime(2, 0),
        zoneId: toronto,
        zone: fixture,
      );
      final DateTime viaDatabase = instantOfLocalWallTime(
        year: 2026,
        month: 3,
        day: 8,
        time: const LocalTime(2, 0),
        zoneId: toronto,
        zone: rules,
      );

      expect(viaFixture, DateTime.utc(2026, 3, 8, 7));
      expect(viaDatabase, viaFixture);
    });

    test('D-M1-5: the fall-back ambiguity resolves the same way in both', () {
      // 01:30 local happens twice on 1 November 2026. D-M1-5 takes the
      // earlier, which is 05:30Z rather than 06:30Z.
      final DateTime viaFixture = instantOfLocalWallTime(
        year: 2026,
        month: 11,
        day: 1,
        time: const LocalTime(1, 30),
        zoneId: toronto,
        zone: fixture,
      );
      final DateTime viaDatabase = instantOfLocalWallTime(
        year: 2026,
        month: 11,
        day: 1,
        time: const LocalTime(1, 30),
        zoneId: toronto,
        zone: rules,
      );

      expect(viaFixture, DateTime.utc(2026, 11, 1, 5, 30));
      expect(viaDatabase, viaFixture);
    });
  });

  group('AC-6 over the real database', () {
    test('a task completed Tue 23:10 archives at Wed 02:00 local', () {
      // Tuesday 22 September 2026 23:10 EDT is 03:10Z on the 23rd.
      expect(
        archiveBoundaryAfter(
          DateTime.utc(2026, 9, 23, 3, 10),
          const LocalTime(2, 0),
          toronto,
          rules,
        ),
        DateTime.utc(2026, 9, 23, 6),
        reason: 'Wednesday 02:00 EDT',
      );
    });

    test('initialization is idempotent, so constructing twice is free', () {
      TimeZoneDatabaseRules.ensureInitialized();
      TimeZoneDatabaseRules.ensureInitialized();
      expect(
        TimeZoneDatabaseRules().offsetAt(DateTime.utc(2026, 1, 15), toronto),
        const Duration(hours: -5),
      );
    });
  });
}

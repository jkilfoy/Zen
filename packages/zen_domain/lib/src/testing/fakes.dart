/// Test doubles for the domain's three injected ports.
///
/// These ship in `lib/` rather than in `test/`, behind the `testing.dart`
/// barrel, because `zen_data`, `zen_sync` and `zen_app` all need them and a
/// package's `test/` directory is not importable from a sibling package. They
/// are pure Dart with no IO, so §11.1 still holds. Recorded in `DECISIONS.md`
/// (D-M1-8).
library;

import '../ids/id_generator.dart';
import '../time/clock.dart';
import '../time/instant_precision.dart';
import '../time/time_zone_rules.dart';

/// §11.4.3. A [Clock] that returns exactly what it is told.
///
/// EOD-2 through EOD-5 are specified at exact instants, including two DST
/// transitions a year, so the tests that cover them must be able to stand the
/// clock anywhere.
///
/// Like every [Clock] it truncates to whole milliseconds (§3, INV-9), so a test
/// cannot accidentally introduce a precision the database would reject.
final class FakeClock implements Clock {
  /// Creates a clock reading [now] in [zoneId].
  FakeClock(DateTime now, {this.zoneId = 'UTC'})
    : _now = truncateToMilliseconds(now);

  DateTime _now;

  /// The IANA zone this clock reports. Settable, because EOD-5 computes
  /// boundaries in the device's *current* zone and a device can travel.
  String zoneId;

  @override
  DateTime nowUtc() => _now;

  @override
  String localZoneId() => zoneId;

  /// Moves the clock to [instant].
  void set(DateTime instant) => _now = truncateToMilliseconds(instant);

  /// Moves the clock forward by [duration].
  void advance(Duration duration) =>
      _now = truncateToMilliseconds(_now.add(duration));
}

/// §3. An [IdGenerator] producing predictable, ordered ids.
///
/// Real ids are UUIDv7 (§3). Tests need reproducibility instead, and the merge
/// tie-breaks on the lexicographically smallest id (§9.3 step 4), so the ids
/// this produces are zero-padded to sort the same way they are generated.
final class SequentialIdGenerator implements IdGenerator {
  /// Creates a generator producing `<prefix>-0000`, `<prefix>-0001`, and so on.
  SequentialIdGenerator({this.prefix = 'id'});

  /// The stem every generated id starts with.
  final String prefix;

  int _next = 0;

  /// How many ids have been handed out.
  int get count => _next;

  @override
  String newId() => '$prefix-${(_next++).toString().padLeft(4, '0')}';
}

/// EOD-5. A [TimeZoneRules] with one offset and no transitions.
///
/// For the many tests where DST is beside the point.
final class FixedOffsetTimeZoneRules implements TimeZoneRules {
  /// Creates rules that always report [offset].
  const FixedOffsetTimeZoneRules(this.offset);

  /// UTC itself.
  static const FixedOffsetTimeZoneRules utc = FixedOffsetTimeZoneRules(
    Duration.zero,
  );

  /// The offset reported for every instant and every zone.
  final Duration offset;

  @override
  Duration offsetAt(DateTime utc, String zoneId) => offset;
}

/// EOD-5. A [TimeZoneRules] that models `America/Toronto`.
///
/// Eastern Time is the case the specification cares about: with the factory
/// default `endOfDay` of 02:00, the spring-forward transition lands exactly on
/// a boundary that does not exist, which is the case EOD-5 calls out.
///
/// Models the post-2007 North American rules — DST from the second Sunday in
/// March at 02:00 local to the first Sunday in November at 02:00 local — and
/// nothing else. It is a fixture, not a time-zone database; `zen_data` supplies
/// the real thing over `package:timezone` (D-M1-2).
final class TorontoTimeZoneRules implements TimeZoneRules {
  /// Creates the fixture.
  const TorontoTimeZoneRules();

  /// The zone this fixture answers for.
  static const String zoneId = 'America/Toronto';

  /// Standard time, UTC−05:00.
  static const Duration standardOffset = Duration(hours: -5);

  /// Daylight time, UTC−04:00.
  static const Duration daylightOffset = Duration(hours: -4);

  @override
  Duration offsetAt(DateTime utc, String zoneId) {
    if (zoneId != TorontoTimeZoneRules.zoneId) {
      throw ArgumentError.value(
        zoneId,
        'zoneId',
        'TorontoTimeZoneRules only models ${TorontoTimeZoneRules.zoneId}',
      );
    }
    final DateTime instant = utc.toUtc();
    final int year = instant.year;

    // Spring forward: 02:00 EST on the second Sunday in March, which is 07:00Z.
    final DateTime daylightStart = _nthSundayOf(
      year,
      3,
      2,
    ).add(const Duration(hours: 2)).subtract(standardOffset);

    // Fall back: 02:00 EDT on the first Sunday in November, which is 06:00Z.
    final DateTime daylightEnd = _nthSundayOf(
      year,
      11,
      1,
    ).add(const Duration(hours: 2)).subtract(daylightOffset);

    final bool inDaylight =
        !instant.isBefore(daylightStart) && instant.isBefore(daylightEnd);
    return inDaylight ? daylightOffset : standardOffset;
  }

  /// Midnight (as a UTC carrier) on the [nth] Sunday of [month] in [year].
  static DateTime _nthSundayOf(int year, int month, int nth) {
    final DateTime first = DateTime.utc(year, month);
    // DateTime.weekday is 1 (Monday) through 7 (Sunday).
    final int daysToSunday = (7 - first.weekday) % 7;
    return first.add(Duration(days: daysToSunday + (nth - 1) * 7));
  }
}

/// §4.5, §11.4.4. The End-of-Day calculator.
///
/// Pure: given a completion instant, the configured local wall-clock time and a
/// zone, it returns the instant at which the task archives. No clock, no IO.
library;

import '../model/task.dart';
import 'local_time.dart';
import 'time_zone_rules.dart';

/// How many local days forward [archiveBoundaryAfter] will look.
///
/// Two is always enough: either today's boundary is still ahead of the
/// completion instant, or tomorrow's is. The third is slack, and exceeding it
/// means [TimeZoneRules] returned something incoherent.
const int _maxDaysToScan = 3;

/// EOD-2, EOD-5, §11.4.4. The instant at which a Task completed at
/// [completedAtUtc] archives.
///
/// EOD-2: "the **first EoD boundary strictly after** its `completedAt`".
/// Strictly, so a Task completed exactly on a boundary archives at the next
/// one.
///
/// EOD-5: boundaries are wall-clock times on each local date, so this walks
/// local dates rather than adding 24-hour spans — across a DST change the two
/// differ by an hour.
///
/// Because the answer is derived from [completedAtUtc] rather than from when
/// the sweep last ran, a replica closed across several boundaries still
/// archives correctly on its next start, with no catch-up loop (EOD-3,
/// §11.5.4, AC-6).
DateTime archiveBoundaryAfter(
  DateTime completedAtUtc,
  LocalTime endOfDay,
  String zoneId,
  TimeZoneRules zone,
) {
  final DateTime completedUtc = completedAtUtc.toUtc();
  final DateTime wallOfCompletion = _wallClockAt(completedUtc, zoneId, zone);

  DateTime date = DateTime.utc(
    wallOfCompletion.year,
    wallOfCompletion.month,
    wallOfCompletion.day,
  );

  for (int day = 0; day < _maxDaysToScan; day++) {
    final DateTime boundary = instantOfLocalWallTime(
      year: date.year,
      month: date.month,
      day: date.day,
      time: endOfDay,
      zoneId: zoneId,
      zone: zone,
    );
    if (boundary.isAfter(completedUtc)) {
      return boundary;
    }
    // A wall-clock day forward. The carrier is UTC, so this is exact calendar
    // arithmetic with no DST of its own — which is the point.
    date = date.add(const Duration(days: 1));
  }

  throw StateError(
    'No End-of-Day boundary found within $_maxDaysToScan days of '
    '$completedAtUtc in $zoneId. TimeZoneRules returned incoherent offsets.',
  );
}

/// EOD-2, EOD-3. Whether [task] is due to be archived as of [nowUtc].
///
/// True only for a Task that is `Done`, not already archived and not deleted,
/// whose boundary has passed. The sweep in `zen_data` (§11.5.4) applies this;
/// the decision lives here so it can be tested without a database.
bool isDueForArchive(
  Task task,
  DateTime nowUtc,
  LocalTime endOfDay,
  String zoneId,
  TimeZoneRules zone,
) {
  final DateTime? completedAt = task.completedAt;
  if (completedAt == null || task.isArchived || task.isDeleted) {
    return false;
  }
  final DateTime boundary = archiveBoundaryAfter(
    completedAt,
    endOfDay,
    zoneId,
    zone,
  );
  return !nowUtc.isBefore(boundary);
}

/// EOD-5. The instant at which the wall clock in [zoneId] reads [time] on the
/// local date [year]-[month]-[day].
///
/// Two local dates a year do not have exactly one such instant, and EOD-5 says
/// what to do about the first of them:
///
/// * **Gap** (spring forward). The configured time does not exist on that date
///   — with the factory default of 02:00, this is precisely what happens in
///   North America. EOD-5: "use the first valid instant after it", which is the
///   transition instant itself.
/// * **Ambiguity** (fall back). The configured time occurs twice. EOD-5 does
///   not say which to take, so this returns the **earlier**, consistent with
///   EOD-2 asking for the *first* boundary after a completion. Recorded in
///   `DECISIONS.md` (D-M1-5).
///
/// Assumes a zone changes offset at most once in any 24-hour span, which is
/// true of every zone in the IANA database.
DateTime instantOfLocalWallTime({
  required int year,
  required int month,
  required int day,
  required LocalTime time,
  required String zoneId,
  required TimeZoneRules zone,
}) {
  // A UTC DateTime used purely as a carrier for a wall-clock reading. It is not
  // an instant; it is "what the clock on the wall says".
  final DateTime wall = DateTime.utc(year, month, day, time.hour, time.minute);

  // Every offset plausibly in effect around this wall time. Sampling a day
  // either side brackets any transition near it.
  final Set<Duration> offsets = <Duration>{
    zone.offsetAt(wall.subtract(const Duration(days: 1)), zoneId),
    zone.offsetAt(wall, zoneId),
    zone.offsetAt(wall.add(const Duration(days: 1)), zoneId),
  };

  final List<DateTime> candidates =
      offsets.map((Duration offset) => wall.subtract(offset)).toList()..sort();

  final List<DateTime> valid = candidates
      .where((DateTime instant) => _wallClockAt(instant, zoneId, zone) == wall)
      .toList();

  if (valid.isNotEmpty) {
    // One match is the ordinary case; two means an ambiguous hour, and the
    // earliest is the documented choice.
    return valid.first;
  }

  // A gap: no instant reads [time] on this date. The largest candidate is
  // exactly the transition instant, which is the first valid instant after the
  // time that does not exist.
  return candidates.last;
}

/// The wall-clock reading in [zoneId] at the instant [utc], as a UTC-carrier
/// [DateTime]. See [instantOfLocalWallTime] for what "carrier" means here.
DateTime _wallClockAt(DateTime utc, String zoneId, TimeZoneRules zone) =>
    utc.add(zone.offsetAt(utc, zoneId));

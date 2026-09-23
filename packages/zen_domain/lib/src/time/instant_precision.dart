/// §3, INV-9. Millisecond precision, which §3 makes exact rather than a floor.
library;

/// §3, INV-9. Returns [instant] truncated to whole milliseconds, in UTC.
///
/// §3: "Every instant MUST be truncated to whole milliseconds, and the
/// truncation happens where instants enter the system — in [Clock], so nothing
/// downstream has to remember, and again at the storage and snapshot-parsing
/// boundaries, so an instant arriving from a peer or an older database cannot
/// smuggle in finer precision."
///
/// Truncation rather than rounding, so that an instant never moves forwards
/// past another event: INV-5 and §9.3's `updatedAt` ordering both compare
/// instants, and rounding could invert a pair that was genuinely ordered.
DateTime truncateToMilliseconds(DateTime instant) {
  final DateTime utc = instant.toUtc();
  if (utc.microsecond == 0) {
    return utc;
  }
  return utc.subtract(Duration(microseconds: utc.microsecond));
}

/// §3, INV-9. Whether [instant] carries no precision finer than a millisecond.
///
/// What INV-9 asserts, and what the `length(...) = 24` schema checks in
/// §11.5.2 enforce on the way to disk: `toIso8601String()` emits exactly
/// `YYYY-MM-DDTHH:MM:SS.mmmZ` for a UTC instant whose microsecond component is
/// zero, and six fractional digits otherwise.
bool hasMillisecondPrecision(DateTime instant) =>
    instant.toUtc().microsecond == 0;

/// §3, INV-9. The INV-9 failures among [timestamps], keyed by field name.
///
/// Shared by [Idea], [Task] and [Subtask], so that the three report the breach
/// in one voice. Null values pass: INV-9 is about precision, and INV-1 and
/// INV-4 are what decide whether a value is present at all.
List<String> timestampPrecisionFailures(Map<String, DateTime?> timestamps) =>
    <String>[
      for (final MapEntry<String, DateTime?> entry in timestamps.entries)
        if (entry.value != null && !hasMillisecondPrecision(entry.value!))
          'INV-9: ${entry.key} ${entry.value} is finer than millisecond '
              'precision',
    ];

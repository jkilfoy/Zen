/// EOD-5, §11.2, D-M1-2. The adapter that supplies the domain's
/// [TimeZoneRules] port.
library;

import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:zen_domain/zen_domain.dart';

/// EOD-5. [TimeZoneRules] over `package:timezone`.
///
/// §11.2 puts `timezone` in `zen_data` only: it reaches `dart:io`, which §11.1
/// forbids in `zen_domain`. So the domain declares the one-method port and
/// keeps the part that is actually hard — wall-clock arithmetic across a DST
/// gap or an ambiguous hour — in `end_of_day.dart`, where it is tested against
/// a fixture with real transition rules. This adapter is the one line that was
/// promised (D-M1-2).
final class TimeZoneDatabaseRules implements TimeZoneRules {
  /// Creates the adapter, loading the IANA database on first use.
  TimeZoneDatabaseRules() {
    ensureInitialized();
  }

  static bool _initialized = false;

  /// Loads the bundled IANA database, once per process.
  ///
  /// `package:timezone` ships the data as Dart source, so this reads no files
  /// and works identically in a test, on Windows and on Android.
  static void ensureInitialized() {
    if (_initialized) {
      return;
    }
    tz_data.initializeTimeZones();
    _initialized = true;
  }

  @override
  Duration offsetAt(DateTime utc, String zoneId) {
    final tz.Location location;
    try {
      location = tz.getLocation(zoneId);
    } on tz.LocationNotFoundException catch (error) {
      // The port's contract: "Throws [ArgumentError] if [zoneId] is not a zone
      // this implementation knows. An unknown zone is programmer error or a
      // broken platform channel, not something the user can cause (§11.4.1)."
      throw ArgumentError.value(zoneId, 'zoneId', error.msg);
    }
    // `TimeZone.offset` is already a [Duration] in timezone 0.11.1, and
    // positive east of Greenwich — which is the sign the port asks for.
    return location.timeZone(utc.toUtc().millisecondsSinceEpoch).offset;
  }
}

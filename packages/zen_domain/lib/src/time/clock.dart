/// §11.4.3. The clock abstraction.
library;

/// §11.4.3. The source of the current time and the device's time zone.
///
/// `DateTime.now()` must not appear anywhere in `zen_domain`, `zen_data` or
/// `zen_sync` (§11.11); a CI grep and
/// `zen_domain/test/architecture_test.dart` enforce that. Every rule that needs
/// the time takes it as a parameter, and every service that needs one takes a
/// [Clock].
///
/// Tests use a fake clock so that EOD-2 through EOD-5 can be exercised at exact
/// instants, including the DST cases. See `package:zen_domain/testing.dart`.
abstract interface class Clock {
  /// The current instant, in UTC.
  ///
  /// §3: all timestamps are stored as UTC instants and displayed in the
  /// device's local time zone.
  DateTime nowUtc();

  /// The device's current IANA zone, e.g. `'America/Toronto'`.
  ///
  /// EOD-5 computes boundaries in the device's *current* local zone, so this is
  /// read at each sweep rather than cached.
  String localZoneId();
}

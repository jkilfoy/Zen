/// EOD-5. The port through which the domain reads IANA time-zone offsets.
library;

/// EOD-5. Resolves the UTC offset in effect in a named IANA zone at an instant.
///
/// §11.4.4 gives `archiveBoundaryAfter` a `String zoneId` parameter, but
/// `dart:core` knows only "local" and "UTC" — it cannot resolve an arbitrary
/// IANA zone. The obvious fix, depending on `package:timezone`, would breach
/// §11.1: that package declares `package:http` as a runtime dependency, which
/// reaches `dart:io`, and `zen_domain`'s pubspec must not depend on anything
/// that touches IO.
///
/// So the domain declares the port and someone downstream supplies the data.
/// The part that is actually hard — wall-clock arithmetic across a DST gap or
/// an ambiguous hour — stays here in `end_of_day.dart` where it is tested
/// against a fake zone with real transition rules. The adapter over
/// `package:timezone` in `zen_data` is a one-liner.
///
/// Recorded in `DECISIONS.md` (D-M1-2).
abstract interface class TimeZoneRules {
  /// The UTC offset in effect in [zoneId] at the instant [utc].
  ///
  /// [utc] must be a UTC `DateTime`. The returned offset is what you add to
  /// [utc] to get the local wall-clock reading, so it is negative west of
  /// Greenwich: `America/Toronto` in January returns `-5 hours`.
  ///
  /// Throws [ArgumentError] if [zoneId] is not a zone this implementation
  /// knows. An unknown zone is programmer error or a broken platform channel,
  /// not something the user can cause (§11.4.1).
  Duration offsetAt(DateTime utc, String zoneId);
}

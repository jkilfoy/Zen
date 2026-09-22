/// §3.6, EOD-1. A wall-clock time of day, with no date and no zone.
library;

import 'package:meta/meta.dart';

/// §3.6, EOD-1. A local time of day in `HH:MM` form.
///
/// `settings.endOfDay` is one of these (factory default 02:00). It is a *wall
/// clock* reading, not an instant: EOD-5 requires that it be applied to each
/// local date in turn, which is why it carries no zone and no offset.
@immutable
final class LocalTime implements Comparable<LocalTime> {
  /// Constructs a time of day. [hour] must be 0–23 and [minute] 0–59.
  ///
  /// Out-of-range values are programmer error (§11.4.1): the Settings screen
  /// offers a time picker, so the user cannot produce one. Use [tryParse] for
  /// input that might be malformed.
  const LocalTime(this.hour, this.minute)
    : assert(hour >= 0 && hour <= 23, 'hour must be 0-23'),
      assert(minute >= 0 && minute <= 59, 'minute must be 0-59');

  /// §3.6. The factory default for `settings.endOfDay`: 02:00.
  static const LocalTime endOfDayDefault = LocalTime(2, 0);

  /// Hour of the day, 0–23.
  final int hour;

  /// Minute of the hour, 0–59.
  final int minute;

  /// Parses `HH:MM`, returning `null` if [raw] is not a valid time of day.
  ///
  /// Used when reading the setting back out of storage, where a malformed value
  /// should fall back to the default rather than crash the app (§11.5.5).
  static LocalTime? tryParse(String raw) {
    final List<String> parts = raw.split(':');
    if (parts.length != 2) {
      return null;
    }
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return LocalTime(hour, minute);
  }

  /// Minutes since local midnight.
  int get minutesSinceMidnight => hour * 60 + minute;

  /// Formats as zero-padded `HH:MM`, the form stored in settings.
  String format() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  int compareTo(LocalTime other) =>
      minutesSinceMidnight.compareTo(other.minutesSinceMidnight);

  @override
  bool operator ==(Object other) =>
      other is LocalTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => format();
}

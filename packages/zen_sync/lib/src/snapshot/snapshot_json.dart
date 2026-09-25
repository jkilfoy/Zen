/// §11.6.1. Reading typed values out of a decoded snapshot document.
///
/// Split out of `snapshot_codec.dart` for §11.11's "files stay under roughly
/// 400 lines", the same way D-M2-8 split `field_resolution.dart` out of the
/// merge strategy: what is left there reads as §11.6.1's document, and the
/// plumbing that makes each read fail usefully is here.
///
/// Not exported from `zen_sync.dart`. Nothing outside the codec has any reason
/// to reach it.
library;

import 'package:zen_domain/zen_domain.dart';

/// Internal control flow for the codec.
///
/// Never escapes `SnapshotCodec`: every public entry point there converts it to
/// a `SnapshotFieldInvalid`, so §11.4.1's "results, not exceptions" holds at the
/// boundary, which is what it is about. Threading a `Result` through thirty
/// nested field reads would bury the shape of the format under plumbing
/// (D-M6-2).
final class MalformedSnapshot implements Exception {
  /// Records that the value at [path] was unusable, because of [reason].
  MalformedSnapshot(this.path, this.reason);

  /// A dotted path into the document, e.g. `tasks[3].subtasks[1].status`.
  final String path;

  /// Why that value could not be used.
  final String reason;

  @override
  String toString() => 'Malformed snapshot at $path: $reason';
}

/// Returns [value] as a JSON object, or refuses.
Map<String, Object?> jsonObject(Object? value, String path) =>
    value is Map<String, Object?>
    ? value
    : throw MalformedSnapshot(path, 'is not a JSON object');

/// Returns `json[key]` as a JSON array, or refuses.
List<Object?> jsonList(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  return value is List<Object?>
      ? value
      : throw MalformedSnapshot(key, 'is not a JSON array');
}

/// Returns [value] as a string, or refuses.
String jsonStringValue(Object? value, String path) =>
    value is String ? value : throw MalformedSnapshot(path, 'is not a string');

/// Returns `json[key]` as a string, or refuses.
String jsonString(Map<String, Object?> json, String key, String path) =>
    jsonStringValue(json[key], path);

/// Returns `json[key]` as a string, or null when the key holds JSON null.
String? jsonStringOrNull(Map<String, Object?> json, String key, String path) {
  final Object? value = json[key];
  return value == null ? null : jsonStringValue(value, path);
}

/// Returns `json[key]` as an integer, or refuses.
int jsonInt(Map<String, Object?> json, String key, String path) {
  final Object? value = json[key];
  return value is int
      ? value
      : throw MalformedSnapshot(path, 'is not an integer');
}

/// Returns `json[key]` as a boolean, or refuses.
bool jsonBool(Map<String, Object?> json, String key, String path) {
  final Object? value = json[key];
  return value is bool
      ? value
      : throw MalformedSnapshot(path, 'is not a boolean');
}

/// §3. Parses a timestamp and truncates it to whole milliseconds.
///
/// §3 puts a truncation at "the storage and snapshot-parsing boundaries, so an
/// instant arriving from a peer or an older database cannot smuggle in finer
/// precision". This is that boundary. Truncating rather than refusing, because
/// INV-9 is about what this replica stores, and a peer writing microseconds is
/// not a reason to drop its data.
DateTime jsonInstant(Map<String, Object?> json, String key, String path) {
  final String raw = jsonString(json, key, path);
  final DateTime parsed;
  try {
    parsed = DateTime.parse(raw);
  } on FormatException {
    throw MalformedSnapshot(path, 'is not an ISO-8601 timestamp');
  }
  if (!parsed.isUtc && !raw.endsWith('Z') && !_hasOffset(raw)) {
    // §3: every instant is UTC. A bare local-time string has no defined
    // instant, and guessing this device's zone would make the same file decode
    // differently on two replicas — which breaks MERGE-2 quietly (D-M6-5).
    throw MalformedSnapshot(
      path,
      'has no time zone; §3 requires a UTC instant',
    );
  }
  return truncateToMilliseconds(parsed);
}

/// As [jsonInstant], but null when the key holds JSON null.
DateTime? jsonInstantOrNull(
  Map<String, Object?> json,
  String key,
  String path,
) => json[key] == null ? null : jsonInstant(json, key, path);

/// Returns the member of [values] called [stored], or refuses.
///
/// §11.6.1: an unrecognised `status`, `timeframe` or tombstone `reason` is one
/// of the named reasons a whole file is refused.
T jsonEnum<T extends Enum>(List<T> values, String stored, String path) {
  for (final T value in values) {
    if (value.name == stored) {
      return value;
    }
  }
  throw MalformedSnapshot(
    path,
    'is "$stored", which is not one of '
    '${values.map((T v) => v.name).join(', ')}',
  );
}

/// Whether an ISO-8601 string carries an explicit `+hh:mm` / `-hh:mm` offset.
///
/// Checked past the date's own hyphens, which is why it looks only at the part
/// after `T`.
bool _hasOffset(String raw) {
  final int time = raw.indexOf('T');
  if (time < 0) {
    return false;
  }
  final String rest = raw.substring(time);
  return rest.contains('+') || rest.contains('-');
}

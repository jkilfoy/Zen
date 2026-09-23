/// §3, INV-9, §11.5.2. The storage boundary for timestamps.
library;

import 'package:zen_domain/zen_domain.dart';

/// §3, INV-9. Encodes [instant] as the exact 24-character form the schema
/// requires: `YYYY-MM-DDTHH:MM:SS.mmmZ`.
///
/// Truncating here is not belt-and-braces over [Clock]'s own truncation. §3
/// puts a truncation at the storage boundary precisely so that an instant which
/// never came from a clock — decoded from a peer's snapshot, or read out of an
/// older database — cannot smuggle in finer precision. The INV-9 `CHECK`s
/// backstop it: an instant that escaped this function would be 27 characters
/// and the insert would fail.
String encodeInstant(DateTime instant) =>
    truncateToMilliseconds(instant).toIso8601String();

/// §3, INV-9. Encodes [instant], or `null`.
String? encodeInstantOrNull(DateTime? instant) =>
    instant == null ? null : encodeInstant(instant);

/// §3. Decodes a stored timestamp.
///
/// Truncates on the way out too, so a row written before the INV-9 checks
/// existed cannot hand a finer instant to the domain, where the entity
/// constructors' assert would fire in debug and nothing at all would catch it
/// in release (D-M1-16).
DateTime decodeInstant(String stored) =>
    truncateToMilliseconds(DateTime.parse(stored));

/// §3. Decodes a stored timestamp, or `null`.
DateTime? decodeInstantOrNull(String? stored) =>
    stored == null ? null : decodeInstant(stored);

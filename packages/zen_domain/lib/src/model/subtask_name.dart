/// §3.4. The name of a Subtask, validated on construction.
library;

import 'package:characters/characters.dart';
import 'package:meta/meta.dart';

import '../result.dart';
import 'normalize.dart';

/// §3.4. A validated Subtask name: trimmed, 1–1000 characters, no line breaks.
///
/// Deliberately *not* an [ItemName]: NAME-2's three-character minimum does not
/// apply to subtasks (§3.4, Q12), and NAME-11 exempts subtask names from
/// uniqueness — a Task may contain two subtasks with the same name.
///
/// [normalized] exists all the same, because the merge matches subtasks by
/// `(normalizedName, k)` (§9.3 step 5).
@immutable
final class SubtaskName {
  const SubtaskName._(this.value, this.normalized);

  /// §3.4. Minimum length in Unicode extended grapheme clusters.
  static const int minLength = 1;

  /// §3.4. Maximum length in Unicode extended grapheme clusters.
  static const int maxLength = 1000;

  /// The name as stored and displayed, trimmed.
  final String value;

  /// §2, §9.3 step 5(a). The normalized form used for merge matching.
  final String normalized;

  /// §3.4. Validates [raw]: trimmed, 1–1000 characters, no line breaks.
  static Result<SubtaskName, RuleViolation> parse(String raw) {
    final String trimmed = raw.trim();

    if (trimmed.contains('\n') || trimmed.contains('\r')) {
      return const Err<SubtaskName, RuleViolation>(
        SubtaskNameContainsLineBreak(),
      );
    }

    final int length = trimmed.characters.length;
    if (length < minLength) {
      return const Err<SubtaskName, RuleViolation>(SubtaskNameEmpty());
    }
    if (length > maxLength) {
      return const Err<SubtaskName, RuleViolation>(SubtaskNameTooLong());
    }

    return Ok<SubtaskName, RuleViolation>(
      SubtaskName._(trimmed, normalizeName(trimmed)),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SubtaskName && other.value == value;

  /// NAME-11 exempts subtask names from uniqueness, so equality here is over
  /// the literal [value]. Merge matching uses [normalized] explicitly instead.
  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

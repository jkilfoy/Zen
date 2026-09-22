/// §3.5. A short categorising label attached to an Item.
library;

import 'package:characters/characters.dart';
import 'package:meta/meta.dart';

import '../result.dart';
import 'normalize.dart';

/// Matches any Unicode whitespace character (TAG-2).
final RegExp _anyWhitespace = RegExp(r'\s', unicode: true);

/// §3.5, TAG-1 to TAG-5. A validated tag.
///
/// Stored without a leading `@` (TAG-1) and displayed as `@tag` (TAG-5), which
/// is what [display] is for.
@immutable
final class Tag {
  const Tag._(this.value, this.normalized);

  /// TAG-3. Minimum length in Unicode extended grapheme clusters.
  static const int minLength = 1;

  /// TAG-3. Maximum length in Unicode extended grapheme clusters.
  static const int maxLength = 32;

  /// The tag as the user typed it, without a leading `@` (TAG-1, TAG-4).
  final String value;

  /// TAG-4. The case-folded form used for comparison and de-duplication.
  final String normalized;

  /// §3.5. Validates [raw] against TAG-1 through TAG-3.
  ///
  /// TAG-1 strips a single leading `@`, so both `work` and `@work` parse to the
  /// same tag. TAG-2 rejects any whitespace at all — not merely a leading or
  /// trailing run — since a tag is a single token.
  static Result<Tag, RuleViolation> parse(String raw) {
    String candidate = raw.trim();
    if (candidate.startsWith('@')) {
      candidate = candidate.substring(1).trim();
    }

    if (candidate.characters.length < minLength) {
      return const Err<Tag, RuleViolation>(TagEmpty());
    }
    if (_anyWhitespace.hasMatch(candidate)) {
      return const Err<Tag, RuleViolation>(TagContainsWhitespace());
    }
    if (candidate.characters.length > maxLength) {
      return const Err<Tag, RuleViolation>(TagTooLong());
    }

    return Ok<Tag, RuleViolation>(Tag._(candidate, normalizeTag(candidate)));
  }

  /// TAG-5. The tag as it is shown to the user, with its leading `@`.
  String get display => '@$value';

  @override
  bool operator ==(Object other) =>
      other is Tag && other.normalized == normalized;

  /// TAG-4. Tags compare case-insensitively, so the hash is over [normalized].
  @override
  int get hashCode => normalized.hashCode;

  @override
  String toString() => display;
}

/// §3.2, §3.5, TAG-4. Returns [tags] with case-insensitive duplicates removed,
/// keeping the first occurrence and therefore the case the user typed first.
///
/// "Adding a tag that equals an existing tag on the same Item is a no-op"
/// (TAG-4), and both Ideas and Tasks preserve insertion order (§3.2, §3.3).
List<Tag> dedupeTags(Iterable<Tag> tags) {
  final Set<String> seen = <String>{};
  final List<Tag> result = <Tag>[];
  for (final Tag tag in tags) {
    if (seen.add(tag.normalized)) {
      result.add(tag);
    }
  }
  return List<Tag>.unmodifiable(result);
}

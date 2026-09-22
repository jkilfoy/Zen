/// §3.2, §3.3. An Idea's context and a Task's description: free multi-line
/// plain text, capped at 10,000 characters.
library;

import 'package:characters/characters.dart';
import 'package:meta/meta.dart';

import '../result.dart';

/// §3.2, §3.3, Q10, Q25. Free-form plain text attached to an Item.
///
/// One type serves both fields, since their rules are identical; only the
/// violation differs, which is why [parseContext] and [parseDescription] are
/// separate entry points.
///
/// Unlike [ItemName] this is *not* trimmed: the user's paragraph breaks and
/// indentation are theirs. Only the length cap is enforced.
@immutable
final class ItemText {
  const ItemText._(this.value);

  /// §3.2, §3.3. Maximum length in Unicode extended grapheme clusters.
  static const int maxLength = 10000;

  /// The empty text, which is the default for both fields (§3.2, §3.3).
  static const ItemText empty = ItemText._('');

  /// The text exactly as the user entered it.
  final String value;

  /// Whether this text is empty.
  bool get isEmpty => value.isEmpty;

  /// §3.2. Validates [raw] as an Idea's context.
  static Result<ItemText, RuleViolation> parseContext(String raw) =>
      _parse(raw, const ContextTooLong());

  /// §3.3. Validates [raw] as a Task's description.
  static Result<ItemText, RuleViolation> parseDescription(String raw) =>
      _parse(raw, const DescriptionTooLong());

  static Result<ItemText, RuleViolation> _parse(
    String raw,
    RuleViolation tooLong,
  ) {
    if (raw.characters.length > maxLength) {
      return Err<ItemText, RuleViolation>(tooLong);
    }
    return Ok<ItemText, RuleViolation>(ItemText._(raw));
  }

  @override
  bool operator ==(Object other) => other is ItemText && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

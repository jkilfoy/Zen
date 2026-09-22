/// §3.1. The name of an Idea or a Task, validated on construction.
library;

import 'package:characters/characters.dart';
import 'package:meta/meta.dart';

import '../result.dart';
import 'normalize.dart';

/// §3.1, NAME-1 to NAME-5. A validated Item name.
///
/// §11.4.2: constructing an entity with a raw [String] name must not be
/// possible, so [Idea] and [Task] take an [ItemName]. The only way to make one
/// is [parse], which enforces NAME-1 through NAME-4.
///
/// Uniqueness (NAME-6) is deliberately *not* enforced here — it needs the
/// store. It lives in the repository and, ultimately, in the partial unique
/// index (§11.5.2).
@immutable
final class ItemName {
  const ItemName._(this.value, this.normalized);

  /// NAME-2. Minimum length in Unicode extended grapheme clusters.
  static const int minLength = 3;

  /// NAME-3. Maximum length in Unicode extended grapheme clusters.
  static const int maxLength = 1000;

  /// The name as stored and displayed: [String.trim]med (NAME-1), otherwise
  /// exactly what the user typed.
  final String value;

  /// §2, NAME-5. The normalized form used for every equality comparison.
  final String normalized;

  /// §3.1. Validates [raw] against NAME-1 through NAME-4.
  ///
  /// Checks run in the order the user would hit them: trim first (NAME-1),
  /// then reject line breaks (NAME-4), then length (NAME-2, NAME-3). Length is
  /// measured in Unicode extended grapheme clusters, which is what NAME-2 means
  /// by "user-perceived characters".
  static Result<ItemName, RuleViolation> parse(String raw) {
    final String trimmed = raw.trim();

    // NAME-4. Reachable only by pasting: the name field makes Enter submit.
    if (trimmed.contains('\n') || trimmed.contains('\r')) {
      return const Err<ItemName, RuleViolation>(NameContainsLineBreak());
    }

    final int length = trimmed.characters.length;
    if (length < minLength) {
      return const Err<ItemName, RuleViolation>(NameTooShort());
    }
    if (length > maxLength) {
      return const Err<ItemName, RuleViolation>(NameTooLong());
    }

    return Ok<ItemName, RuleViolation>(
      ItemName._(trimmed, normalizeName(trimmed)),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ItemName && other.normalized == normalized;

  /// NAME-5. Two names are equal if and only if their normalized forms are,
  /// so the hash must be taken over [normalized] rather than [value].
  @override
  int get hashCode => normalized.hashCode;

  @override
  String toString() => value;
}

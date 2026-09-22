/// §2, NAME-5. Name normalization, used for every equality comparison between
/// names and for the `name_normalized` column the uniqueness indexes are built
/// on (§11.5.2).
library;

/// Matches a run of one or more Unicode whitespace characters, including line
/// breaks and non-breaking spaces.
final RegExp _whitespaceRun = RegExp(r'\s+', unicode: true);

/// §2. Returns [raw] trimmed, with internal whitespace runs collapsed to a
/// single space, case-folded.
///
/// Two names are equal if and only if their normalized forms are equal
/// (NAME-5), so this function is the single definition of name equality across
/// the domain, the database index (§11.5.2) and the merge (§9.2).
///
/// Case folding is approximated by [String.toLowerCase]. Dart has no full
/// Unicode case-folding table, so pairs that fold rather than lowercase — `ß`
/// and `ss` most notably — compare as different names. Recorded in
/// `DECISIONS.md` (D-M1-1).
///
/// No Unicode normal form is applied either, so a composed `é` and a decomposed
/// `é` are different names (D-M1-1).
String normalizeName(String raw) =>
    raw.trim().replaceAll(_whitespaceRun, ' ').toLowerCase();

/// TAG-4. Returns [raw] case-folded for tag comparison.
///
/// Tags contain no whitespace (TAG-2), so there is nothing to collapse. Same
/// case-folding limitation as [normalizeName].
String normalizeTag(String raw) => raw.toLowerCase();

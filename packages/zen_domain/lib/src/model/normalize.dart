/// §2, NAME-5. Name normalization, used for every equality comparison between
/// names and for the `name_normalized` column the uniqueness indexes are built
/// on (§11.5.2).
library;

import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Matches a run of one or more Unicode whitespace characters, including line
/// breaks and non-breaking spaces.
final RegExp _whitespaceRun = RegExp(r'\s+', unicode: true);

/// §2. Returns [raw] normalized: NFC, then trimmed, then internal whitespace
/// runs collapsed to a single space, then case-folded — in that order.
///
/// Two names are equal if and only if their normalized forms are equal
/// (NAME-5), so this is the single definition of name equality across the
/// domain, the `name_normalized` column and its uniqueness indexes (§11.5.2),
/// and name matching during a merge (§9.2). Keeping it in one function is what
/// stops those three drifting apart.
///
/// **The NFC pass matters because the two devices have different input
/// stacks.** Without it a composed `é` (U+00E9) and a decomposed `é`
/// (U+0065 U+0301) are different names, so the same idea typed on Windows and
/// on Android would fail to match during a merge and appear twice after
/// syncing.
///
/// The order is the specification's. NFC runs first because composing can
/// change what counts as whitespace-adjacent, and case folding runs last
/// because it is the only step that is not idempotent under the others.
///
/// Case folding is approximated by [String.toLowerCase]. Dart has no full
/// Unicode case-folding table, so pairs that fold rather than lowercase — `ß`
/// and `ss` most notably — compare as different names. A documented and
/// accepted limitation (§2, `DECISIONS.md` D-M1-1).
String normalizeName(String raw) =>
    unorm.nfc(raw).trim().replaceAll(_whitespaceRun, ' ').toLowerCase();

/// TAG-4. Returns [raw] normalized for tag comparison: NFC, then case-folded.
///
/// Tags contain no whitespace (TAG-2), so there is nothing to trim or collapse.
///
/// §2 defines the NFC pass for Item *names* and is silent about tags, but the
/// reason for it applies identically: without NFC the same tag typed on Windows
/// and on Android would not de-duplicate (TAG-4) and would appear twice in the
/// autocomplete list (TAG-6). Recorded in `DECISIONS.md` (D-M1-15).
String normalizeTag(String raw) => unorm.nfc(raw).toLowerCase();

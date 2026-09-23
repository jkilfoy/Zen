/// §9.3 step 4. How each individual field of a conflict component resolves.
///
/// Kept apart from `name_union_merge_strategy.dart` so that the strategy reads
/// as the six numbered steps §9.3 describes, and apart from `record_order.dart`
/// so that ordering records and resolving fields stay separate ideas. Every
/// function here is pure and takes its records **already in record order**,
/// because several of the rules break ties with it.
library;

import 'package:characters/characters.dart';

import '../model/enums.dart';
import '../model/item_text.dart';
import '../model/tag.dart';

/// §9.3 step 4. The index of the primary record in [records], which the caller
/// has already put in record order.
///
/// "Among the records carrying the chosen `id`: the latest `updatedAt`; on a
/// tie, the one whose normalized name sorts first; on a further tie, the first
/// in record order."
///
/// A component normally holds one record per replica, **all carrying the same
/// `id`** — the same Item as it stands on each device — so choosing among them
/// is a real decision, not a formality. The `updatedAt` rule is what makes a
/// rename on one device survive the merge; without it the merge could pick the
/// stale name, and being deterministic it would undo the rename again after
/// every future sync.
int primaryRecordIndex<T>(
  List<T> records, {
  required String id,
  required String Function(T record) idOf,
  required DateTime Function(T record) updatedAtOf,
  required String Function(T record) normalizedNameOf,
}) {
  int best = -1;
  for (int i = 0; i < records.length; i++) {
    if (idOf(records[i]) != id) continue;
    if (best == -1) {
      best = i;
      continue;
    }
    final int byUpdatedAt = updatedAtOf(records[i])
        .compareTo(updatedAtOf(records[best]));
    if (byUpdatedAt != 0) {
      if (byUpdatedAt > 0) best = i;
      continue;
    }
    // Record order already placed `best` first, so an equal name keeps it —
    // which is the third tie-break, applied without a second comparison.
    final int byName = normalizedNameOf(records[i])
        .compareTo(normalizedNameOf(records[best]));
    if (byName < 0) best = i;
  }
  assert(best != -1, 'the chosen id belongs to no record in the component');
  return best;
}

/// §9.3 step 4. The union of [perRecord]'s tags, de-duplicated
/// case-insensitively (TAG-4).
///
/// "The primary record's tags in their own order, then tags contributed by the
/// remaining records taken in record order, each record's in its own order,
/// skipping duplicates." [perRecord] is in record order.
///
/// Tags are a sequence, not a set (MERGE-3A): the order shows in the row's tag
/// line (ROW-2), so it is part of the user's data and not free to rearrange.
List<Tag> unionTags(List<List<Tag>> perRecord, int primaryIndex) {
  final Set<String> seen = <String>{};
  final List<Tag> union = <Tag>[];
  void take(List<Tag> tags) {
    for (final Tag tag in tags) {
      if (seen.add(tag.normalized)) union.add(tag);
    }
  }

  take(perRecord[primaryIndex]);
  for (int i = 0; i < perRecord.length; i++) {
    if (i != primaryIndex) take(perRecord[i]);
  }
  return union;
}

/// §9.3 step 4. The winning `context` (Ideas) or `description` (Tasks).
///
/// "The longest, measured in **grapheme clusters** (the unit NAME-2 counts).
/// Ties, in order: among the tied-longest, the latest `updatedAt`; then the
/// primary record **if its text is among the tied-longest**; then record
/// order."
///
/// The tie-breaks apply in that order, so the primary is consulted only among
/// the candidates still standing after the `updatedAt` round: a primary whose
/// text is tied-longest but staler has already lost, which is what "in order"
/// requires.
///
/// [texts] and [updatedAts] are parallel and in record order.
ItemText longestText(
  List<ItemText> texts,
  List<DateTime> updatedAts,
  int primaryIndex,
) {
  final List<int> lengths = texts
      .map((ItemText t) => t.value.characters.length)
      .toList(growable: false);
  final int longest = lengths.reduce((int a, int b) => a > b ? a : b);

  final List<int> tiedOnLength = <int>[
    for (int i = 0; i < texts.length; i++)
      if (lengths[i] == longest) i,
  ];
  final DateTime latest = tiedOnLength
      .map((int i) => updatedAts[i])
      .reduce((DateTime a, DateTime b) => a.isAfter(b) ? a : b);
  final List<int> tied = <int>[
    for (final int i in tiedOnLength)
      if (updatedAts[i] == latest) i,
  ];

  if (tied.contains(primaryIndex)) return texts[primaryIndex];
  // Record order: `texts` follows the caller's already-sorted records.
  return texts[tied.first];
}

/// §9.3 step 4. The `id` a component resolves to: the lexicographically
/// smallest, which is deterministic and always one of the real conflicting ids.
String smallestId(Iterable<String> ids) =>
    ids.reduce((String a, String b) => a.compareTo(b) <= 0 ? a : b);

/// §9.3 step 4. `createdAt` is the earliest across the component.
DateTime earliestInstant(Iterable<DateTime> instants) =>
    instants.reduce((DateTime a, DateTime b) => a.isBefore(b) ? a : b);

/// §9.3 step 4. `updatedAt` is the latest across the component.
DateTime latestInstant(Iterable<DateTime> instants) =>
    instants.reduce((DateTime a, DateTime b) => a.isAfter(b) ? a : b);

/// §9.3 step 4, step 5(d). The most urgent [Timeframe] among [timeframes]:
/// `Now` > `Soon` > `Later` > `Distant`.
///
/// Never called with an empty iterable: a conflict component always holds at
/// least one record.
Timeframe mostUrgentTimeframe(Iterable<Timeframe> timeframes) =>
    timeframes.reduce((Timeframe a, Timeframe b) => a.mostUrgent(b));

/// §9.3 step 4, step 5(d). The highest-precedence [TaskStatus] among
/// [statuses]: `Done` > `Blocked` > `Todo`.
TaskStatus highestPrecedenceStatus(Iterable<TaskStatus> statuses) =>
    statuses.reduce((TaskStatus a, TaskStatus b) => a.highestPrecedence(b));

/// §9.3 step 4. The earliest of [instants], ignoring nulls; null when they are
/// all null or the iterable is empty.
///
/// The shape `completedAt`, `archivedAt` and `deletedAt` all resolve by.
DateTime? earliestNonNull(Iterable<DateTime?> instants) {
  DateTime? earliest;
  for (final DateTime? instant in instants) {
    if (instant == null) continue;
    if (earliest == null || instant.isBefore(earliest)) {
      earliest = instant;
    }
  }
  return earliest;
}

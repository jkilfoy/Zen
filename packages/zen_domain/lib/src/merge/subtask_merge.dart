/// §9.3 step 5. Subtask resolution: union, `id` first and position-within-a-
/// name only as a fall-back.
library;

import '../model/enums.dart';
import '../model/subtask.dart';
import '../model/task.dart';
import 'field_resolution.dart';
import 'record_order.dart';

/// §9.3 step 5. Resolves the subtask lists of one conflict component into one
/// list.
///
/// [recordsInRecordOrder] are the component's Tasks already sorted by
/// [compareTaskRecords], and [primaryIndex] is the position of the primary
/// record (§9.3 step 4) within that list. Both are the caller's job, because
/// step 4 has to choose the primary anyway and step 5(e) orders by the same
/// record order.
///
/// **Matching is by `id` first, and by position-within-a-name only as a
/// fall-back for what `id` did not match.** The two relations must not be
/// combined into one "shares an `id` or shares a key" relation, because they
/// chain: rename subtask `1` from "Set" to "Warmup" on one replica while the
/// other still holds `[Set 1, Set 2]`, and `A1 ~ B1` by id, `A2 ~ B2` by id,
/// but `A1 ~ B2` by the key `(set, 0)` — one component, and the user's two
/// "Set" subtasks silently become one. That breaches principle 1.2.4.
///
/// Ordering the fall-back after `id` also bounds the damage when matching does
/// go wrong: the result is a **duplicated** subtask rather than a deleted one
/// (§9.4), which the user can see and fix.
List<Subtask> mergeSubtasks({
  required List<Task> recordsInRecordOrder,
  required int primaryIndex,
}) {
  final List<_LocatedSubtask> all = <_LocatedSubtask>[
    for (int r = 0; r < recordsInRecordOrder.length; r++)
      for (int p = 0; p < recordsInRecordOrder[r].subtasks.length; p++)
        _LocatedSubtask(
          subtask: recordsInRecordOrder[r].subtasks[p],
          recordIndex: r,
          position: p,
        ),
  ];

  final List<List<_LocatedSubtask>> groups = _group(all);

  // §9.3 step 5(c). Each subtask joins exactly one group, and no group holds
  // two subtasks of the same record — so nothing is dropped, and the guarantee
  // holds by construction rather than by inspection.
  assert(
    groups.fold<int>(0, (int n, List<_LocatedSubtask> g) => n + g.length) ==
        all.length,
    'a subtask was lost or duplicated while grouping',
  );
  assert(
    groups.every(
      (List<_LocatedSubtask> g) =>
          g.map((_LocatedSubtask s) => s.recordIndex).toSet().length ==
          g.length,
    ),
    'a group holds two subtasks of the same record',
  );

  groups.sort(
    (List<_LocatedSubtask> a, List<_LocatedSubtask> b) =>
        _compareGroupOrder(a, b, primaryIndex),
  );

  return List<Subtask>.unmodifiable(groups.map(_resolveGroup));
}

/// §9.3 step 5(a), 5(b). Groups by `id`, then keys whatever `id` left over.
List<List<_LocatedSubtask>> _group(List<_LocatedSubtask> all) {
  // (a) Match by `id`. Ids are unique within a record, so an id group holds at
  // most one subtask per record. A group of one matched nothing, so it falls
  // through to (b).
  final Map<String, List<_LocatedSubtask>> byId =
      <String, List<_LocatedSubtask>>{};
  for (final _LocatedSubtask located in all) {
    byId
        .putIfAbsent(located.subtask.id, () => <_LocatedSubtask>[])
        .add(located);
  }

  final List<List<_LocatedSubtask>> groups = <List<_LocatedSubtask>>[];
  final List<_LocatedSubtask> unmatched = <_LocatedSubtask>[];
  for (final List<_LocatedSubtask> group in byId.values) {
    if (group.length > 1) {
      groups.add(group);
    } else {
      unmatched.add(group.single);
    }
  }

  // (b) Key the remainder: the k-th subtask bearing a given normalized name,
  // counting over that record's *unmatched* subtasks only, in its list order.
  unmatched.sort(_byRecordThenPosition);
  final Map<String, int> occurrences = <String, int>{};
  final Map<String, List<_LocatedSubtask>> byKey =
      <String, List<_LocatedSubtask>>{};
  for (final _LocatedSubtask located in unmatched) {
    final String name = located.subtask.name.normalized;
    final String perRecord = '${located.recordIndex}\u0000$name';
    final int k = occurrences[perRecord] ?? 0;
    occurrences[perRecord] = k + 1;
    byKey.putIfAbsent('$name\u0000$k', () => <_LocatedSubtask>[]).add(located);
  }
  groups.addAll(byKey.values);

  return groups;
}

/// §9.3 step 5(d). Resolves one group into a single subtask.
Subtask _resolveGroup(List<_LocatedSubtask> group) {
  final List<Subtask> members = group
      .map((_LocatedSubtask l) => l.subtask)
      .toList(growable: false);

  final String id = smallestId(members.map((Subtask s) => s.id));

  // The primary subtask: latest `updatedAt`, then in record order. A group
  // holds at most one subtask per record, so the record's position in record
  // order settles the tie.
  final _LocatedSubtask primary = group.reduce(
    (_LocatedSubtask a, _LocatedSubtask b) => _isPreferredPrimary(a, b) ? a : b,
  );

  final TaskStatus status = highestPrecedenceStatus(
    members.map((Subtask s) => s.status),
  );

  return Subtask(
    id: id,
    name: primary.subtask.name,
    status: status,
    createdAt: earliestInstant(members.map((Subtask s) => s.createdAt)),
    updatedAt: latestInstant(members.map((Subtask s) => s.updatedAt)),
    // INV-1. `status` resolving to `Done` means at least one member is `Done`,
    // so an earliest non-null always exists.
    completedAt: status == TaskStatus.done
        ? earliestNonNull(
            members
                .where((Subtask s) => s.status == TaskStatus.done)
                .map((Subtask s) => s.completedAt),
          )
        : null,
  );
}

/// §9.3 step 5(d). Whether [a] outranks [b] as the group's primary subtask.
bool _isPreferredPrimary(_LocatedSubtask a, _LocatedSubtask b) {
  final int byUpdated = a.subtask.updatedAt.compareTo(b.subtask.updatedAt);
  if (byUpdated != 0) return byUpdated > 0;
  return a.recordIndex <= b.recordIndex;
}

/// §9.3 step 5(e). Orders the resolved groups.
///
/// "First the groups containing a subtask of the primary record, in that
/// record's order; then the remaining groups, ordered by the first record in
/// record order that contributed to the group, and within a record by that
/// subtask's position."
int _compareGroupOrder(
  List<_LocatedSubtask> a,
  List<_LocatedSubtask> b,
  int primaryIndex,
) {
  final _LocatedSubtask? fromPrimaryA = _memberFromRecord(a, primaryIndex);
  final _LocatedSubtask? fromPrimaryB = _memberFromRecord(b, primaryIndex);

  if (fromPrimaryA != null && fromPrimaryB != null) {
    return fromPrimaryA.position.compareTo(fromPrimaryB.position);
  }
  if (fromPrimaryA != null) return -1;
  if (fromPrimaryB != null) return 1;

  final _LocatedSubtask firstA = a.reduce(_earlierContributor);
  final _LocatedSubtask firstB = b.reduce(_earlierContributor);
  final int byRecord = firstA.recordIndex.compareTo(firstB.recordIndex);
  if (byRecord != 0) return byRecord;
  return firstA.position.compareTo(firstB.position);
}

/// The group's member contributed by record [recordIndex], or null. At most one
/// exists (§9.3 step 5(c)).
_LocatedSubtask? _memberFromRecord(
  List<_LocatedSubtask> group,
  int recordIndex,
) {
  for (final _LocatedSubtask located in group) {
    if (located.recordIndex == recordIndex) return located;
  }
  return null;
}

_LocatedSubtask _earlierContributor(_LocatedSubtask a, _LocatedSubtask b) =>
    _byRecordThenPosition(a, b) <= 0 ? a : b;

int _byRecordThenPosition(_LocatedSubtask a, _LocatedSubtask b) {
  final int byRecord = a.recordIndex.compareTo(b.recordIndex);
  if (byRecord != 0) return byRecord;
  return a.position.compareTo(b.position);
}

/// A subtask together with where it came from: which record of the component,
/// in record order, and which position in that record's list.
///
/// §9.3 step 5 needs both — 5(b) counts `k` within a record, 5(d) breaks ties
/// by record order, and 5(e) orders by record then position — so carrying them
/// alongside the subtask keeps all three reading off one structure.
final class _LocatedSubtask {
  const _LocatedSubtask({
    required this.subtask,
    required this.recordIndex,
    required this.position,
  });

  final Subtask subtask;

  /// The index of the record this came from, within the component sorted by
  /// [compareTaskRecords].
  final int recordIndex;

  /// The index of this subtask within that record's own list.
  final int position;
}

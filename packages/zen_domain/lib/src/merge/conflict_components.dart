/// §9.2, MERGE-5, §9.3 step 3. Grouping records into conflict components.
library;

/// §9.2, MERGE-5. Groups [records] into conflict components.
///
/// "Two Ideas, or two Tasks, are **conflicting** if they have the same `id`,
/// **or** if both are **active** (§2) and their normalized names are equal.
/// Conflict is transitive: take the connected components of this relation."
///
/// Transitivity is why this is a union-find rather than a pair of `groupBy`
/// calls: an archived record can join a component by `id` and pull in, through
/// the active record sharing that id, everything that matches *its* name
/// (MERGE-6). That chain is exactly what §9.3 step 6 later has to clean up
/// after.
///
/// Restricting name matching to active records is what allows recurring names
/// (NAME-7): last week's archived "Water the plants" and today's active one are
/// different Items and must not be merged.
///
/// Components come back with their members in the order they appear in
/// [records], and the components themselves in order of first appearance. The
/// caller imposes its own order where the result depends on one — MERGE-2 is
/// satisfied by §9.3's record order and step 8, not here.
List<List<T>> conflictComponents<T>(
  List<T> records, {
  required String Function(T record) idOf,
  required String Function(T record) normalizedNameOf,
  required bool Function(T record) isActive,
}) {
  final _DisjointSet sets = _DisjointSet(records.length);

  final Map<String, int> firstWithId = <String, int>{};
  final Map<String, int> firstActiveWithName = <String, int>{};

  for (int i = 0; i < records.length; i++) {
    final T record = records[i];

    // MERGE-5, first clause: same `id`. Holds for archived and deleted records
    // too (MERGE-6).
    final int? sameId = firstWithId[idOf(record)];
    if (sameId == null) {
      firstWithId[idOf(record)] = i;
    } else {
      sets.union(sameId, i);
    }

    // MERGE-5, second clause: both active, equal normalized names.
    if (!isActive(record)) continue;
    final String name = normalizedNameOf(record);
    final int? sameName = firstActiveWithName[name];
    if (sameName == null) {
      firstActiveWithName[name] = i;
    } else {
      sets.union(sameName, i);
    }
  }

  final Map<int, List<T>> byRoot = <int, List<T>>{};
  for (int i = 0; i < records.length; i++) {
    byRoot.putIfAbsent(sets.find(i), () => <T>[]).add(records[i]);
  }
  return byRoot.values.toList(growable: false);
}

/// Union-find over `0..size-1`, with path compression and union by size.
///
/// Private and deliberately minimal: MERGE-5's transitive closure is the only
/// thing in the project that needs one.
final class _DisjointSet {
  _DisjointSet(int size)
    : _parent = List<int>.generate(size, (int i) => i, growable: false),
      _size = List<int>.filled(size, 1);

  final List<int> _parent;
  final List<int> _size;

  int find(int i) {
    int root = i;
    while (_parent[root] != root) {
      root = _parent[root];
    }
    // Path compression, so repeated finds stay near-constant.
    int walk = i;
    while (_parent[walk] != root) {
      final int next = _parent[walk];
      _parent[walk] = root;
      walk = next;
    }
    return root;
  }

  void union(int a, int b) {
    int rootA = find(a);
    int rootB = find(b);
    if (rootA == rootB) return;
    if (_size[rootA] < _size[rootB]) {
      final int swap = rootA;
      rootA = rootB;
      rootB = swap;
    }
    _parent[rootB] = rootA;
    _size[rootA] += _size[rootB];
  }
}

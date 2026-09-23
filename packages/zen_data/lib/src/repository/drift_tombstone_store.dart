/// §11.4.6, §9.3 step 1. The Drift-backed [TombstoneStore].
library;

import 'package:drift/drift.dart';
import 'package:zen_domain/zen_domain.dart';

import '../database.dart';
import '../mapping/entity_mapping.dart';

/// §11.4.6. Storage for Idea tombstones.
///
/// The table keys on `id` alone, which is what §9.3 step 1 relies on when it
/// reduces the merged tombstones to one per Idea: "A plain set union keeps two
/// tombstones for one Idea … a landmine for M3's tombstone table, which keys on
/// `id`."
final class DriftTombstoneStore implements TombstoneStore {
  /// Creates a store over [db].
  DriftTombstoneStore(this._db);

  final AppDatabase _db;

  @override
  Future<List<IdeaTombstone>> all() async {
    final List<IdeaTombstoneRow> rows =
        await (_db.select(_db.ideaTombstones)
              ..orderBy(<OrderClauseGenerator<IdeaTombstones>>[
                (IdeaTombstones t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return rows.map(tombstoneFromRow).toList(growable: false);
  }

  @override
  Future<Set<String>> tombstonedIdeaIds() async {
    final List<IdeaTombstoneRow> rows = await _db
        .select(_db.ideaTombstones)
        .get();
    return rows.map((IdeaTombstoneRow r) => r.id).toSet();
  }

  @override
  Future<void> add(IdeaTombstone tombstone) async {
    // "Records [tombstone], ignoring one that is already present" (§11.4.6).
    // The first tombstone for an id is the one that counts: §9.3 step 1 takes
    // the earliest `deletedAt`, and a second one could only be later.
    await _db
        .into(_db.ideaTombstones)
        .insert(tombstoneToRow(tombstone), mode: InsertMode.insertOrIgnore);
  }
}

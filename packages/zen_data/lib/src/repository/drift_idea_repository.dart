/// §11.4.6, §11.5. The Drift-backed [IdeaRepository].
library;

import 'package:drift/drift.dart';
import 'package:zen_domain/zen_domain.dart';

import '../database.dart';
import '../mapping/entity_mapping.dart';
import 'constraint_failures.dart';
import 'drift_event_log.dart';
import 'events.dart';

/// §11.4.6. Storage for Ideas.
///
/// Every live Idea is active (§2), so NAME-6 here is the unconditional
/// `idx_ideas_active_name` index — and per §11.5.2 this class does not
/// pre-check it. It attempts the write and translates the failure, which has no
/// time-of-check-to-time-of-use window and, just as importantly, means the
/// index is what the tests actually exercise. [findActiveByNormalizedName] is
/// what the UI uses for NAME-8's live feedback and its `"Open it"` link.
final class DriftIdeaRepository implements IdeaRepository {
  /// Creates a repository over [db], minting event ids with [ids].
  DriftIdeaRepository(this._db, {required IdGenerator ids})
    : _events = EventRecorder(DriftEventLog(_db), ids);

  final AppDatabase _db;
  final EventRecorder _events;

  @override
  Stream<List<Idea>> watchAll() {
    // One query rather than two streams, so drift re-runs it when *either*
    // table changes and an added tag updates the list as an edit should.
    //
    // IDEAS-4: oldest first. Ordering the stored text is ordering the instants,
    // because INV-9 makes every timestamp exactly 24 characters (§3).
    final JoinedSelectStatement<HasResultSet, Object?> query =
        _db.select(_db.ideas).join(<Join<HasResultSet, Object?>>[
          leftOuterJoin(
            _db.ideaTags,
            _db.ideaTags.ownerId.equalsExp(_db.ideas.id),
          ),
        ])..orderBy(<OrderingTerm>[
          OrderingTerm.asc(_db.ideas.createdAt),
          OrderingTerm.asc(_db.ideas.id),
        ]);

    return query.watch().map(_assemble);
  }

  @override
  Future<Idea?> findById(String id) async {
    final IdeaRow? row = await (_db.select(
      _db.ideas,
    )..where((Ideas i) => i.id.equals(id))).getSingleOrNull();
    return row == null ? null : ideaFromRow(row, await _tagsFor(row.id));
  }

  @override
  Future<Idea?> findActiveByNormalizedName(String normalized) async {
    final IdeaRow? row =
        await (_db.select(_db.ideas)
              ..where((Ideas i) => i.nameNormalized.equals(normalized)))
            .getSingleOrNull();
    return row == null ? null : ideaFromRow(row, await _tagsFor(row.id));
  }

  /// §2, NAME-6. The normalized names of every Idea, which are all active.
  ///
  /// Feeds `checkNameAvailable` in the UI (NAME-8). The guarantee is the index,
  /// not this (§11.5.2).
  @override
  Future<Set<String>> activeNormalizedNames() async {
    final List<IdeaRow> rows = await _db.select(_db.ideas).get();
    return rows.map((IdeaRow r) => r.nameNormalized).toSet();
  }

  @override
  Future<Result<Idea, RuleViolation>> create(Idea idea) =>
      translatingIdeaNameCollision<Idea>(
        () => _db.transaction(() async {
          await _db.into(_db.ideas).insert(ideaToRow(idea));
          await _writeTags(idea);
          await _events.record(
            itemId: idea.id,
            kind: ItemKind.idea,
            type: ItemEventType.created,
            at: idea.createdAt,
          );
          return idea;
        }),
      );

  @override
  Future<Result<Idea, RuleViolation>> update(Idea idea) =>
      translatingIdeaNameCollision<Idea>(
        () => _db.transaction(() async {
          final Idea? before = await findById(idea.id);
          if (before == null) {
            throw StateError(
              'Idea ${idea.id} does not exist. `update` edits an existing '
              'Idea; `create` is what adds one.',
            );
          }

          await (_db.update(
            _db.ideas,
          )..where((Ideas i) => i.id.equals(idea.id))).write(ideaToRow(idea));

          // TAG-4's uniqueness is `(owner_id, value_normalized)`, so a tag that
          // merely changed case would collide with its own old row, and a
          // removal would leave `sort_index` sparse. Replacing the list
          // wholesale avoids both.
          await _deleteTags(idea.id);
          await _writeTags(idea);

          await _events.recordIdeaEdit(
            before: before,
            after: idea,
            at: idea.updatedAt,
          );
          return idea;
        }),
      );

  @override
  Future<void> delete(String id, DateTime now) => _db.transaction(() async {
    final Idea? idea = await findById(id);
    if (idea == null) {
      // DEL-3 is idempotent from the caller's side: an Idea that is already
      // gone needs no second tombstone, and INV-7 forbids re-creating it.
      return;
    }

    // The Idea must go before its tombstone: `inv7_tombstone_insert` refuses a
    // tombstone for an Idea that is still present, which is what makes this
    // order compulsory rather than merely conventional (INV-7). Its tags go
    // with it through `ON DELETE CASCADE` (§11.5.1).
    await (_db.delete(_db.ideas)..where((Ideas i) => i.id.equals(id))).go();
    await _db
        .into(_db.ideaTombstones)
        .insert(tombstoneToRow(deleteIdea(idea, now)));
    await _events.record(
      itemId: id,
      kind: ItemKind.idea,
      type: ItemEventType.deleted,
      at: now,
    );
  });

  /// TAG-6. Every distinct tag on an Idea, for autocomplete.
  ///
  /// All live Ideas are active (§2), so no filter is needed. The Task half is
  /// [DriftTaskRepository.activeTagValues]; §11.5.1 notes that TAG-6 is then a
  /// union of two indexed queries.
  Future<List<Tag>> activeTagValues() async {
    final List<IdeaTagRow> rows =
        await (_db.select(_db.ideaTags)
              ..orderBy(<OrderClauseGenerator<IdeaTags>>[
                (IdeaTags t) => OrderingTerm.asc(t.valueNormalized),
              ]))
            .get();
    return dedupeTags(rows.map((IdeaTagRow r) => Tag.parse(r.value).unwrap()));
  }

  Future<List<IdeaTagRow>> _tagsFor(String ideaId) => (_db.select(
    _db.ideaTags,
  )..where((IdeaTags t) => t.ownerId.equals(ideaId))).get();

  Future<void> _writeTags(Idea idea) async {
    final List<IdeaTagsCompanion> rows = ideaTagsToRows(idea);
    if (rows.isEmpty) {
      return;
    }
    await _db.batch((Batch batch) => batch.insertAll(_db.ideaTags, rows));
  }

  Future<void> _deleteTags(String ideaId) => (_db.delete(
    _db.ideaTags,
  )..where((IdeaTags t) => t.ownerId.equals(ideaId))).go();

  /// Collapses the join's one-row-per-tag shape back into one Idea per row,
  /// keeping the query's order.
  List<Idea> _assemble(List<TypedResult> results) {
    final List<IdeaRow> order = <IdeaRow>[];
    final Map<String, List<IdeaTagRow>> tags = <String, List<IdeaTagRow>>{};

    for (final TypedResult result in results) {
      final IdeaRow row = result.readTable(_db.ideas);
      if (!tags.containsKey(row.id)) {
        order.add(row);
        tags[row.id] = <IdeaTagRow>[];
      }
      final IdeaTagRow? tag = result.readTableOrNull(_db.ideaTags);
      if (tag != null) {
        tags[row.id]!.add(tag);
      }
    }

    return <Idea>[
      for (final IdeaRow row in order) ideaFromRow(row, tags[row.id]!),
    ];
  }
}

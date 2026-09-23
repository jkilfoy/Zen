/// §3.7, §11.5.2. Every constraint, attacked.
///
/// These tests go straight to SQL, with the repositories bypassed. That is the
/// point: a constraint reached only through a repository is not tested, because
/// the test would pass identically if the constraint had never been created.
/// §11.5.2 is explicit about why it matters here more than anywhere else —
/// `zen_domain` guards its invariants with `assert`, which Dart strips from
/// release builds, so in the app you actually run these are the only
/// enforcement that executes.
///
/// Each group checks both directions: the well-formed row goes in, and the
/// malformed one is refused by the *named* constraint, so a test cannot pass
/// because something else objected first.
library;

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_data/zen_data.dart';

import '../support/harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());

  group('§11.5.5: connection pragmas', () {
    test('foreign keys are on, which the cascades depend on', () async {
      final QueryRow row = await db
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      expect(row.data.values.first, 1);
    });

    test('a subtask cannot reference a task that does not exist', () async {
      await expectLater(
        insertSubtaskRow(db, taskId: 'no-such-task'),
        violatesForeignKey(),
      );
    });

    test('deleting a task cascades to its subtasks and tags', () async {
      await insertTaskRow(db);
      await insertSubtaskRow(db);
      await db.customStatement(
        "INSERT INTO task_tags VALUES ('t1', 'home', 'home', 0)",
      );

      await db.customStatement("DELETE FROM tasks WHERE id = 't1'");

      expect(await _count(db, 'subtasks'), 0);
      expect(await _count(db, 'task_tags'), 0);
    });

    test('DEL-3: deleting an Idea takes its tags with it', () async {
      // Without the cascade these rows would outlive their Idea and keep
      // feeding TAG-6's autocomplete (§11.5.1).
      await insertIdeaRow(db);
      await insertIdeaTagRow(db);

      await db.customStatement("DELETE FROM ideas WHERE id = 'i1'");

      expect(await _count(db, 'idea_tags'), 0);
    });
  });

  group('INV-1: completedAt != null iff status == Done', () {
    test('a Done task with completedAt is accepted', () async {
      await insertTaskRow(db, status: 'done', completedAt: encodeInstant(base));
      expect(await _count(db, 'tasks'), 1);
    });

    test('a Done task without completedAt is refused', () async {
      await expectLater(
        insertTaskRow(db, status: 'done'),
        violatesCheck('inv1_tasks'),
      );
    });

    test('a Todo task with completedAt is refused', () async {
      await expectLater(
        insertTaskRow(db, completedAt: encodeInstant(base)),
        violatesCheck('inv1_tasks'),
      );
    });

    test('§3.7: the same holds for subtasks', () async {
      await insertTaskRow(db);
      await expectLater(
        insertSubtaskRow(db, status: 'done'),
        violatesCheck('inv1_subtasks'),
      );
      await expectLater(
        insertSubtaskRow(db, completedAt: encodeInstant(base)),
        violatesCheck('inv1_subtasks'),
      );
    });
  });

  group('INV-2: a Done task has only Done subtasks', () {
    test('an open subtask may join a Todo task', () async {
      await insertTaskRow(db);
      await insertSubtaskRow(db);
      expect(await _count(db, 'subtasks'), 1);
    });

    test('an open subtask may not be inserted under a Done task', () async {
      await insertTaskRow(db, status: 'done', completedAt: encodeInstant(base));
      await expectLater(insertSubtaskRow(db), violatesTrigger('INV-2'));
    });

    test('a Done subtask may be inserted under a Done task', () async {
      await insertTaskRow(db, status: 'done', completedAt: encodeInstant(base));
      await insertSubtaskRow(
        db,
        status: 'done',
        completedAt: encodeInstant(base),
      );
      expect(await _count(db, 'subtasks'), 1);
    });

    test('a Done subtask may not be reopened under a Done task', () async {
      await insertTaskRow(db, status: 'done', completedAt: encodeInstant(base));
      await insertSubtaskRow(
        db,
        status: 'done',
        completedAt: encodeInstant(base),
      );

      await expectLater(
        db.customStatement(
          "UPDATE subtasks SET status = 'todo', completed_at = NULL "
          "WHERE id = 's1'",
        ),
        violatesTrigger('INV-2'),
      );
    });

    test('a task may not be completed while a subtask is open', () async {
      await insertTaskRow(db);
      await insertSubtaskRow(db);

      await expectLater(
        db.customStatement(
          "UPDATE tasks SET status = 'done', completed_at = ? WHERE id = 't1'",
          <Object?>[encodeInstant(base)],
        ),
        violatesTrigger('INV-2'),
      );
    });

    test('a task may not be inserted Done over open subtasks', () async {
      // Reachable only if a subtask row survived its parent, which the
      // cascade prevents — but the trigger is cheap and the pair is then
      // closed from both ends.
      await insertTaskRow(db);
      await insertSubtaskRow(db);
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await db.customStatement("DELETE FROM tasks WHERE id = 't1'");
      await db.customStatement('PRAGMA foreign_keys = ON');

      await expectLater(
        insertTaskRow(db, status: 'done', completedAt: encodeInstant(base)),
        violatesTrigger('INV-2'),
      );
    });

    test('a task may be completed once every subtask is Done', () async {
      await insertTaskRow(db);
      await insertSubtaskRow(db);
      await db.customStatement(
        "UPDATE subtasks SET status = 'done', completed_at = ? WHERE id = 's1'",
        <Object?>[encodeInstant(base)],
      );
      await db.customStatement(
        "UPDATE tasks SET status = 'done', completed_at = ? WHERE id = 't1'",
        <Object?>[encodeInstant(base)],
      );

      final QueryRow row = await db
          .customSelect("SELECT status FROM tasks WHERE id = 't1'")
          .getSingle();
      expect(row.data['status'], 'done');
    });
  });

  group('INV-3: archived implies Done', () {
    test('an archived Done task is accepted', () async {
      await insertTaskRow(
        db,
        status: 'done',
        completedAt: encodeInstant(base),
        isArchived: 1,
        archivedAt: encodeInstant(at(600)),
      );
      expect(await _count(db, 'tasks'), 1);
    });

    test('an archived Todo task is refused', () async {
      await expectLater(
        insertTaskRow(db, isArchived: 1, archivedAt: encodeInstant(at(600))),
        violatesCheck('inv3_tasks'),
      );
    });
  });

  group('INV-4: archivedAt iff isArchived, deletedAt iff isDeleted', () {
    test('isArchived without archivedAt is refused', () async {
      await expectLater(
        insertTaskRow(
          db,
          status: 'done',
          completedAt: encodeInstant(base),
          isArchived: 1,
        ),
        violatesCheck('inv4_tasks_archived'),
      );
    });

    test('archivedAt without isArchived is refused', () async {
      await expectLater(
        insertTaskRow(db, archivedAt: encodeInstant(at(600))),
        violatesCheck('inv4_tasks_archived'),
      );
    });

    test('isDeleted without deletedAt is refused', () async {
      await expectLater(
        insertTaskRow(db, isDeleted: 1),
        violatesCheck('inv4_tasks_deleted'),
      );
    });

    test('deletedAt without isDeleted is refused', () async {
      await expectLater(
        insertTaskRow(db, deletedAt: encodeInstant(at(600))),
        violatesCheck('inv4_tasks_deleted'),
      );
    });
  });

  group('INV-5: createdAt <= updatedAt', () {
    test('equal timestamps are accepted', () async {
      await insertIdeaRow(db);
      expect(await _count(db, 'ideas'), 1);
    });

    test('updatedAt before createdAt is refused, for ideas', () async {
      await expectLater(
        insertIdeaRow(
          db,
          createdAt: encodeInstant(at(10)),
          updatedAt: encodeInstant(base),
        ),
        violatesCheck('inv5_ideas'),
      );
    });

    test('updatedAt before createdAt is refused, for tasks', () async {
      await expectLater(
        insertTaskRow(
          db,
          createdAt: encodeInstant(at(10)),
          updatedAt: encodeInstant(base),
        ),
        violatesCheck('inv5_tasks'),
      );
    });

    test('updatedAt before createdAt is refused, for subtasks', () async {
      await insertTaskRow(db);
      await expectLater(
        insertSubtaskRow(
          db,
          createdAt: encodeInstant(at(10)),
          updatedAt: encodeInstant(base),
        ),
        violatesCheck('inv5_subtasks'),
      );
    });

    test(
      '§3: the comparison is sound because the widths are uniform',
      () async {
        // The reason INV-9 is worth its cost. As text, "…00.100Z" sorts *after*
        // "…00.100500Z", because `Z` (0x5A) outranks any digit — so at mixed
        // precision this CHECK would reject a perfectly ordered pair.
        final QueryRow row = await db
            .customSelect(
              "SELECT ('2026-01-01T00:00:00.100Z' > '2026-01-01T00:00:00.100500Z')"
              ' AS wrong_way_round',
            )
            .getSingle();
        expect(row.data['wrong_way_round'], 1);
      },
    );
  });

  group('INV-6: names and tags satisfy §3.1 and §3.5', () {
    test('NAME-6: two Ideas may not share a normalized name', () async {
      await insertIdeaRow(db, id: 'i1', itemName: 'Read SICP');
      await expectLater(
        // AC-8's normalization: different spacing and case, same name.
        insertIdeaRow(db, id: 'i2', itemName: 'read  SICP'),
        violatesUnique('ideas.name_normalized'),
      );
    });

    test('NAME-6: two active Tasks may not share a normalized name', () async {
      await insertTaskRow(db, id: 't1', itemName: 'Buy milk');
      await expectLater(
        insertTaskRow(db, id: 't2', itemName: 'buy  MILK'),
        violatesUnique('tasks.name_normalized'),
      );
    });

    test('NAME-7, AC-9: an archived Task frees its name', () async {
      await insertTaskRow(
        db,
        id: 't1',
        itemName: 'Water the plants',
        status: 'done',
        completedAt: encodeInstant(base),
        isArchived: 1,
        archivedAt: encodeInstant(at(600)),
      );
      await insertTaskRow(db, id: 't2', itemName: 'Water the plants');

      expect(await _count(db, 'tasks'), 2);
    });

    test('NAME-7: a soft-deleted Task frees its name', () async {
      await insertTaskRow(
        db,
        id: 't1',
        itemName: 'Water the plants',
        isDeleted: 1,
        deletedAt: encodeInstant(at(600)),
      );
      await insertTaskRow(db, id: 't2', itemName: 'Water the plants');

      expect(await _count(db, 'tasks'), 2);
    });

    test('NAME-7: two archived Tasks may share a name', () async {
      // The partial index excludes both, so recurring work can archive as
      // often as it likes.
      for (final String id in <String>['t1', 't2']) {
        await insertTaskRow(
          db,
          id: id,
          itemName: 'Water the plants',
          status: 'done',
          completedAt: encodeInstant(base),
          isArchived: 1,
          archivedAt: encodeInstant(at(600)),
        );
      }
      expect(await _count(db, 'tasks'), 2);
    });

    test('AC-8: an Idea and a Task may share a name', () async {
      await insertIdeaRow(db, itemName: 'Buy milk');
      await insertTaskRow(db, itemName: 'Buy milk');
      expect(await _count(db, 'ideas'), 1);
      expect(await _count(db, 'tasks'), 1);
    });

    test('NAME-1: an untrimmed name is refused', () async {
      await expectLater(
        insertIdeaRow(db, itemName: '  Read SICP  '),
        violatesCheck('inv6_ideas_name'),
      );
    });

    test('NAME-4: a name containing a line break is refused', () async {
      await expectLater(
        insertIdeaRow(db, itemName: 'Read\nSICP'),
        violatesCheck('inv6_ideas_name'),
      );
      await expectLater(
        insertTaskRow(db, itemName: 'Buy\rmilk'),
        violatesCheck('inv6_tasks_name'),
      );
    });

    test('an empty name is refused', () async {
      await expectLater(
        insertIdeaRow(db, itemName: '', nameNormalized: 'x'),
        violatesCheck('inv6_ideas_name'),
      );
    });

    test('an empty normalized name is refused', () async {
      await expectLater(
        insertIdeaRow(db, itemName: 'Read SICP', nameNormalized: ''),
        violatesCheck('inv6_ideas_name_normalized'),
      );
    });

    test('a subtask name is held to the same shape', () async {
      await insertTaskRow(db);
      await expectLater(
        insertSubtaskRow(db, subtaskNameValue: ' padded '),
        violatesCheck('inv6_subtasks_name'),
      );
    });

    test('§3.2: an over-long context is refused', () async {
      await expectLater(
        insertIdeaRow(db, context: 'x' * 160001),
        violatesCheck('inv6_ideas_context'),
      );
    });

    test('TAG-2: a tag containing whitespace is refused', () async {
      await insertIdeaRow(db);
      await expectLater(
        insertIdeaTagRow(db, value: 'two words'),
        violatesCheck('inv6_idea_tags_value'),
      );
    });

    test('TAG-1: a tag is stored without its leading @', () async {
      await insertIdeaRow(db);
      await expectLater(
        insertIdeaTagRow(db, value: '@home'),
        violatesCheck('inv6_idea_tags_value'),
      );
    });

    test(
      'TAG-4: one Item may not hold two tags that differ only in case',
      () async {
        await insertIdeaRow(db);
        await insertIdeaTagRow(db, value: 'Work');
        await expectLater(
          insertIdeaTagRow(db, value: 'work', sortIndex: 1),
          violatesUnique('idea_tags.owner_id, idea_tags.value_normalized'),
        );
      },
    );

    test('TAG-4: two different Items may each keep their own casing', () async {
      // "Tags keep the case the user typed" (TAG-4). A shared vocabulary table
      // would have forced one global casing on both (§11.5.1).
      await insertIdeaRow(db, id: 'i1', itemName: 'First idea');
      await insertIdeaRow(db, id: 'i2', itemName: 'Second idea');
      await insertIdeaTagRow(db, ownerId: 'i1', value: 'CS');
      await insertIdeaTagRow(db, ownerId: 'i2', value: 'cs');

      final List<QueryRow> rows = await db
          .customSelect('SELECT value FROM idea_tags ORDER BY owner_id')
          .get();
      expect(rows.map((QueryRow r) => r.data['value']), <String>['CS', 'cs']);
    });

    test('§11.5.1: a tag sort_index is unique within its Item', () async {
      await insertIdeaRow(db);
      await insertIdeaTagRow(db, value: 'home');
      await expectLater(
        insertIdeaTagRow(db, value: 'work'),
        violatesUnique('idea_tags.owner_id, idea_tags.sort_index'),
      );
    });

    test('§11.5.1: a subtask sort_index is unique within its Task', () async {
      await insertTaskRow(db);
      await insertSubtaskRow(db, id: 's1');
      await expectLater(
        insertSubtaskRow(db, id: 's2'),
        violatesUnique('subtasks.task_id, subtasks.sort_index'),
      );
    });

    test('§11.5.1: a negative sort_index is refused', () async {
      await insertTaskRow(db);
      await expectLater(
        insertSubtaskRow(db, sortIndex: -1),
        violatesCheck('sort_index_subtasks'),
      );
    });
  });

  group('INV-7: a tombstoned Idea id is absent from the Ideas table', () {
    test('a tombstone with no matching Idea is accepted', () async {
      await insertTombstoneRow(db, id: 'gone');
      expect(await _count(db, 'idea_tombstones'), 1);
    });

    test('an Idea may not be inserted under a tombstoned id', () async {
      await insertTombstoneRow(db, id: 'gone');
      await expectLater(
        insertIdeaRow(db, id: 'gone'),
        violatesTrigger('INV-7'),
      );
    });

    test('an Idea may not be renamed onto a tombstoned id', () async {
      await insertIdeaRow(db, id: 'i1');
      await insertTombstoneRow(db, id: 'i1-gone');
      await expectLater(
        db.customStatement("UPDATE ideas SET id = 'i1-gone' WHERE id = 'i1'"),
        violatesTrigger('INV-7'),
      );
    });

    test(
      'a tombstone may not be written while its Idea is still there',
      () async {
        // This is what makes DEL-3 and CONVERT-4 write in the right order:
        // delete the Idea first, then the tombstone.
        await insertIdeaRow(db, id: 'i1');
        await expectLater(
          insertTombstoneRow(db, id: 'i1'),
          violatesTrigger('INV-7'),
        );
      },
    );

    test(
      'AC-18: a tombstone does not reserve the name it was created under',
      () async {
        await insertIdeaRow(db, id: 'x', itemName: 'Call bank');
        await db.customStatement("DELETE FROM ideas WHERE id = 'x'");
        await insertTombstoneRow(db, id: 'x');

        // Tombstones carry no name (DEL-3), so a fresh id with the same name is
        // untouched by it.
        await insertIdeaRow(db, id: 'y', itemName: 'Call bank');
        expect(await _count(db, 'ideas'), 1);
      },
    );
  });

  group('INV-8: the sourceIdea fields are both null or both set', () {
    test('a converted Task carrying both is accepted', () async {
      await insertTaskRow(
        db,
        sourceIdeaId: 'idea-1',
        sourceIdeaCreatedAt: encodeInstant(base),
      );
      expect(await _count(db, 'tasks'), 1);
    });

    test('an id without a creation time is refused', () async {
      await expectLater(
        insertTaskRow(db, sourceIdeaId: 'idea-1'),
        violatesCheck('inv8_tasks'),
      );
    });

    test('a creation time without an id is refused', () async {
      await expectLater(
        insertTaskRow(db, sourceIdeaCreatedAt: encodeInstant(base)),
        violatesCheck('inv8_tasks'),
      );
    });
  });

  group('INV-9: every timestamp has exactly millisecond precision', () {
    const String microseconds = '2026-09-22T12:00:00.000001Z';
    const String seconds = '2026-09-22T12:00:00Z';
    const String local = '2026-09-22T12:00:00.000';

    test('a 24-character UTC instant is accepted', () async {
      await insertIdeaRow(db);
      expect(encodeInstant(base).length, 24);
    });

    test('a microsecond component is refused', () async {
      await expectLater(
        insertIdeaRow(db, createdAt: microseconds, updatedAt: microseconds),
        violatesCheck('inv9_ideas_created_at'),
      );
    });

    test('a timestamp with no fractional part is refused', () async {
      await expectLater(
        insertIdeaRow(db, createdAt: seconds, updatedAt: seconds),
        violatesCheck('inv9_ideas_created_at'),
      );
    });

    test('a timestamp with no zone is refused', () async {
      await expectLater(
        insertTaskRow(db, createdAt: local, updatedAt: local),
        violatesCheck('inv9_tasks_created_at'),
      );
    });

    test('every nullable timestamp column is checked too', () async {
      await expectLater(
        insertTaskRow(db, status: 'done', completedAt: microseconds),
        violatesCheck('inv9_tasks_completed_at'),
      );
      await expectLater(
        insertTaskRow(db, isDeleted: 1, deletedAt: microseconds),
        violatesCheck('inv9_tasks_deleted_at'),
      );
      await expectLater(
        insertTaskRow(
          db,
          status: 'done',
          completedAt: encodeInstant(base),
          isArchived: 1,
          archivedAt: microseconds,
        ),
        violatesCheck('inv9_tasks_archived_at'),
      );
      await expectLater(
        insertTaskRow(
          db,
          sourceIdeaId: 'idea-1',
          sourceIdeaCreatedAt: microseconds,
        ),
        violatesCheck('inv9_tasks_source_idea_created_at'),
      );
      await insertTaskRow(db);
      await expectLater(
        insertSubtaskRow(db, status: 'done', completedAt: microseconds),
        violatesCheck('inv9_subtasks_completed_at'),
      );
      await expectLater(
        insertTombstoneRow(db, deletedAt: microseconds),
        violatesCheck('inv9_idea_tombstones_deleted_at'),
      );
    });
  });

  group('the closed vocabularies', () {
    test('an unknown task status is refused', () async {
      await expectLater(
        insertTaskRow(db, status: 'paused'),
        violatesCheck('status_tasks'),
      );
    });

    test('an unknown timeframe is refused', () async {
      await expectLater(
        insertIdeaRow(db, timeframe: 'eventually'),
        violatesCheck('timeframe_ideas'),
      );
    });

    test('an unknown tombstone reason is refused', () async {
      await expectLater(
        insertTombstoneRow(db, reason: 'vanished'),
        violatesCheck('reason_idea_tombstones'),
      );
    });

    test('a boolean column refuses anything but 0 and 1', () async {
      // Written with `deleted_at` absent so that INV-4 is satisfied — `(2 = 1)`
      // and `(NULL IS NOT NULL)` are both false — and the boolean check is the
      // constraint left to object.
      await expectLater(
        insertTaskRow(db, isDeleted: 2),
        violatesCheck('bool_tasks_is_deleted'),
      );
      // `is_archived = 2` also has to get past INV-3 (`is_archived = 0 OR
      // status = 'done'`) before the boolean check is the one objecting.
      await expectLater(
        insertTaskRow(
          db,
          status: 'done',
          completedAt: encodeInstant(base),
          isArchived: 2,
        ),
        violatesCheck('bool_tasks_is_archived'),
      );
    });

    test('STRICT: an INTEGER column refuses text', () async {
      await expectLater(
        db.customStatement(
          'INSERT INTO tasks (id, name, name_normalized, status, created_at, '
          'updated_at, is_archived, is_deleted) '
          "VALUES ('t9','A task','a task','todo',?,?,'yes',0)",
          <Object?>[encodeInstant(base), encodeInstant(base)],
        ),
        throwsA(isA<Object>()),
      );
    });
  });

  group('§11.5.1: the replica table holds exactly one row', () {
    test('the first row is accepted', () async {
      await db.customStatement("INSERT INTO replica VALUES (1, 'r1', 'pc')");
      expect(await _count(db, 'replica'), 1);
    });

    test('a second row collides with the fixed primary key', () async {
      await db.customStatement("INSERT INTO replica VALUES (1, 'r1', 'pc')");
      await expectLater(
        db.customStatement("INSERT INTO replica VALUES (1, 'r2', 'phone')"),
        violatesUnique('replica.id'),
      );
    });

    test('any other id fails the CHECK', () async {
      await expectLater(
        db.customStatement("INSERT INTO replica VALUES (2, 'r2', 'phone')"),
        violatesCheck('single_row_replica'),
      );
    });

    test('an empty replica id is refused', () async {
      await expectLater(
        db.customStatement("INSERT INTO replica VALUES (1, '', 'pc')"),
        violatesCheck('replica_id_present'),
      );
    });
  });
}

Future<int> _count(AppDatabase db, String table) async {
  final QueryRow row = await db
      .customSelect('SELECT count(*) AS c FROM $table')
      .getSingle();
  return row.data['c']! as int;
}

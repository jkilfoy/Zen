/// §11.5.1, §11.5.3. The schema is what it says it is, and the migration
/// harness is in place.
///
/// Two jobs. The first is to hold the *shape* of the schema to account: every
/// table, index and trigger §11.5 names exists, and the two rules that are easy
/// to lose in a refactor — the partial `WHERE` on the Tasks index, and the
/// absence of one on the Ideas index — are asserted against the SQL SQLite
/// actually stored.
///
/// The second is §11.5.3's harness. There is no released version before v1, so
/// there is no upgrade to exercise yet; what can be proved now is that the
/// committed schema dump and the live schema agree. That is the check which
/// catches a table changed without a `schemaVersion` bump — the failure §11.5.3
/// exists to prevent, arriving as a clear message rather than as a corrupt
/// database on someone's phone.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_data/zen_data.dart';

import '../generated_migrations/schema.dart';
import '../support/harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());

  group('§11.5.1: every table exists', () {
    test('the nine tables §11.5.1 names', () async {
      expect(
        await _names(db, 'table'),
        containsAll(<String>[
          'ideas',
          'tasks',
          'subtasks',
          'idea_tags',
          'task_tags',
          'idea_tombstones',
          'events',
          'settings',
          'replica',
        ]),
      );
    });

    test('§11.5.1: the tag tables are per kind, not polymorphic', () async {
      // v1.5 replaced a shared `tags` plus a polymorphic `item_tags`, which
      // could express neither TAG-4 nor a foreign key. If either name comes
      // back, something has been reverted.
      final List<String> tables = await _names(db, 'table');
      expect(tables, isNot(contains('item_tags')));
      expect(tables, isNot(contains('tags')));
    });
  });

  group('§11.5.2: the uniqueness indexes', () {
    test('NAME-7: the Tasks index is partial on the two flags', () async {
      final String sql = await _sql(db, 'index', 'idx_tasks_active_name');
      expect(sql, contains('UNIQUE'));
      expect(sql, contains('name_normalized'));
      expect(
        sql,
        contains('WHERE is_deleted = 0 AND is_archived = 0'),
        reason: 'the WHERE clause is exactly NAME-7 (§11.5.2)',
      );
    });

    test(
      '§2: the Ideas index is unconditional, because every Idea is active',
      () async {
        final String sql = await _sql(db, 'index', 'idx_ideas_active_name');
        expect(sql, contains('UNIQUE'));
        expect(
          sql.toUpperCase(),
          isNot(contains('WHERE')),
          reason: 'NAME-7 frees the names of archived and deleted *Tasks* only',
        );
      },
    );
  });

  group('§11.5.2: the invariant triggers', () {
    test('INV-2 and INV-7 are defended from both directions', () async {
      expect(
        await _names(db, 'trigger'),
        containsAll(<String>[
          'inv2_subtask_insert',
          'inv2_subtask_update',
          'inv2_task_insert',
          'inv2_task_update',
          'inv7_idea_insert',
          'inv7_idea_update',
          'inv7_tombstone_insert',
        ]),
      );
    });

    test('each raises with the invariant it defends named', () async {
      for (final String trigger in <String>[
        'inv2_subtask_insert',
        'inv7_idea_insert',
      ]) {
        final String sql = await _sql(db, 'trigger', trigger);
        // Drift's generator normalises the SQL it stores, hence the space.
        expect(sql, contains('RAISE (ABORT'));
        expect(sql, contains(trigger.startsWith('inv2') ? 'INV-2' : 'INV-7'));
      }
    });
  });

  group('§11.5.2: timestamps are ISO-8601 text, not Unix seconds', () {
    test('the columns are declared TEXT', () async {
      final List<QueryRow> columns = await db
          .customSelect("PRAGMA table_info('tasks')")
          .get();
      final Map<String, String> types = <String, String>{
        for (final QueryRow row in columns)
          row.data['name']! as String: row.data['type']! as String,
      };

      for (final String column in <String>[
        'created_at',
        'updated_at',
        'completed_at',
        'archived_at',
        'deleted_at',
        'source_idea_created_at',
      ]) {
        expect(
          types[column],
          'TEXT',
          reason:
              'Drift stores DateTime as Unix seconds unless '
              '`store_date_time_values_as_text` is set, which would discard '
              'the sub-second part (§3, §11.5.2)',
        );
      }
    });

    test('a stored instant round-trips exactly, to the millisecond', () async {
      final DateTime instant = DateTime.utc(2026, 9, 22, 12, 34, 56, 789);
      await insertIdeaRow(
        db,
        createdAt: encodeInstant(instant),
        updatedAt: encodeInstant(instant),
      );

      final QueryRow row = await db
          .customSelect('SELECT created_at FROM ideas')
          .getSingle();
      expect(row.data['created_at'], '2026-09-22T12:34:56.789Z');
      expect(decodeInstant(row.data['created_at']! as String), instant);
    });
  });

  group('§11.5.3: the migration harness', () {
    test('schemaVersion is 1, the first released version', () {
      expect(db.schemaVersion, 1);
    });

    test('the live schema matches the committed dump for v1', () async {
      // Catches a table, index or trigger changed without a new schema
      // version and a new dump under `drift_schemas/` — the confusing,
      // late-arriving failure §11.5.3 exists to prevent.
      final SchemaVerifier verifier = SchemaVerifier(GeneratedHelper());
      final InitializedSchema schema = await verifier.schemaAt(1);
      final AppDatabase atV1 = AppDatabase(schema.newConnection());
      addTearDown(atV1.close);

      await verifier.migrateAndValidate(atV1, 1);
    });

    test('an upgrade from a version that does not exist is refused', () async {
      // §11.5.3: "Never edit a released migration; always add a new one." Until
      // there is a v2, arriving in `onUpgrade` at all means the database came
      // from a build that no longer exists, and saying so is better than
      // guessing.
      final AppDatabase older = AppDatabase(NativeDatabase.memory());
      addTearDown(older.close);

      await expectLater(
        older
            .customStatement('PRAGMA user_version = 0')
            .then((_) => older.migration.onUpgrade(Migrator(older), 0, 1)),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test(
      'a freshly created database validates against its own schema',
      () async {
        // `createAll` and the generated schema can drift apart if a `.drift`
        // file is edited and the output not regenerated — the stale-generated-
        // output failure the build step in `tools/verify.ps1` also guards.
        await db.validateDatabaseSchema();
      },
    );

    test('the database passes SQLite integrity_check', () async {
      final QueryRow row = await db
          .customSelect('PRAGMA integrity_check')
          .getSingle();
      expect(row.data.values.first, 'ok');
    });
  });
}

Future<List<String>> _names(AppDatabase db, String type) async {
  final List<QueryRow> rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = '$type' "
        "AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  return rows.map((QueryRow r) => r.data['name']! as String).toList();
}

Future<String> _sql(AppDatabase db, String type, String name) async {
  final QueryRow row = await db
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = ? AND name = ?",
        variables: <Variable<Object>>[
          Variable<String>(type),
          Variable<String>(name),
        ],
      )
      .getSingle();
  return row.data['sql']! as String;
}

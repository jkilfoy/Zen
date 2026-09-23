/// §11.5.2, §3. What the mapper must not lose or quietly change.
///
/// §11.5.2 accepts one thing it cannot enforce in SQL: "SQL cannot assert
/// `name_normalized = normalizeName(name)`. A stale normalized value would
/// leave the unique index guarding the wrong string, silently. … The mitigation
/// is that exactly one mapper writes both columns, and a test drives every
/// write path and re-derives `normalizeName(name)` for every row."
///
/// This is that test, plus the fidelity checks that would catch a storage
/// layer trimming precision or rewriting the user's text.
library;

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_data/zen_data.dart';
import 'package:zen_domain/testing.dart';
import 'package:zen_domain/zen_domain.dart';

import '../support/harness.dart';

void main() {
  late TestRepositories repos;

  setUp(() => repos = TestRepositories());

  group('§11.5.2: name_normalized agrees with name, on every write path', () {
    test(
      'after create, update, convert, delete, restore and unarchive',
      () async {
        final IdGenerator ids = SequentialIdGenerator(prefix: 'conv');

        // Create.
        final Idea idea = anIdea(id: 'i1', named: '  Café   RESUMÉ  '.trim());
        await repos.ideas.create(idea);
        final Task task = aTask(id: 't1', named: 'Straße  ITEM');
        await repos.tasks.create(task);

        // Update, including a rename that changes the normalized form.
        await repos.ideas.update(
          idea.copyWith(name: name('Café  Résumé v2'), updatedAt: at(10)),
        );
        await repos.tasks.update(
          task.copyWith(name: name('STRASSE item'), updatedAt: at(10)),
        );

        // Convert: a Task born from an Idea, whose name came through a draft.
        final Idea source = anIdea(id: 'i2', named: 'Ünicode  Idea');
        await repos.ideas.create(source);
        final Task draft = draftTaskFromIdea(source, at(20), ids);
        await repos.conversions.convert(source, draft, at(20));

        // Soft delete, restore and unarchive all rewrite the tasks row.
        await repos.tasks.softDelete('t1', at(30));
        await repos.tasks.restore('t1', at(40));
        await repos.tasks.create(
          aTask(
            id: 't3',
            named: 'Archived  ONE',
            status: TaskStatus.done,
            createdAt: at(50),
            isArchived: true,
            archivedAt: at(60),
          ),
        );
        await repos.tasks.unarchive('t3', at(70));

        // The check is only worth anything over rows that exist, so say how
        // many it covered.
        expect(await _rowCount(repos, 'ideas'), 1);
        expect(await _rowCount(repos, 'tasks'), 3);
        expect(await _rowCount(repos, 'task_tags'), 0);
        await _expectNormalizedColumnsAgree(repos);
      },
    );

    test('and after the archive sweep, which rewrites a row too', () async {
      await repos.tasks.create(
        aTask(
          id: 't1',
          named: 'Water  THE plants',
          status: TaskStatus.done,
          createdAt: base,
          updatedAt: base,
          completedAt: base,
        ),
      );

      await repos.tasks.runArchiveSweep(
        nowUtc: at(60 * 48),
        endOfDay: const LocalTime(2, 0),
        zoneId: TorontoTimeZoneRules.zoneId,
      );

      await _expectNormalizedColumnsAgree(repos);
    });

    test('a hand-written stale value is what the mitigation guards against', () async {
      // Proof that the check has teeth: written in raw SQL, a stale normalized
      // value sails past every constraint, and only this test notices.
      await insertIdeaRow(
        repos.db,
        itemName: 'Read SICP',
        nameNormalized: 'something else entirely',
      );

      await expectLater(
        _expectNormalizedColumnsAgree(repos),
        throwsA(isA<TestFailure>()),
      );
    });
  });

  group('§3, INV-9: timestamps survive the round trip exactly', () {
    test('a millisecond component is kept', () async {
      final DateTime instant = DateTime.utc(2026, 9, 22, 12, 34, 56, 789);
      final Task task = aTask(
        createdAt: instant,
        updatedAt: instant,
        status: TaskStatus.done,
        completedAt: instant,
      );

      await repos.tasks.create(task);

      final Task stored = (await repos.tasks.findById(task.id))!;
      expect(stored.createdAt, instant);
      expect(stored.updatedAt, instant);
      expect(stored.completedAt, instant);
      expect(
        stored.createdAt.millisecond,
        789,
        reason: "Drift's default stores Unix seconds and would read back .000",
      );
    });

    test(
      'a microsecond component is truncated, not rejected, on the way in',
      () async {
        // §3 puts a truncation at the storage boundary "so that an instant
        // arriving from a peer or an older database cannot smuggle in finer
        // precision". The INV-9 CHECKs would otherwise refuse the write.
        final DateTime fine = DateTime.utc(2026, 9, 22, 12, 0, 0, 250, 500);
        expect(encodeInstant(fine), '2026-09-22T12:00:00.250Z');
        expect(
          decodeInstant('2026-09-22T12:00:00.250Z'),
          DateTime.utc(2026, 9, 22, 12, 0, 0, 250),
        );
      },
    );

    test('a decoded instant is UTC, whatever the column held', () async {
      expect(decodeInstant('2026-09-22T12:00:00.000Z').isUtc, isTrue);
    });
  });

  group('§3.3, MERGE-3A: the sequences keep their order and their casing', () {
    test('subtask order survives, and is not inferred from id', () async {
      // Ids deliberately descending, so an implementation ordering by id would
      // reverse the list and be caught.
      final Task task = aTask(
        subtasks: <Subtask>[
          aSubtask(id: 's3', named: 'First'),
          aSubtask(id: 's2', named: 'Second'),
          aSubtask(id: 's1', named: 'Third'),
        ],
      );
      await repos.tasks.create(task);

      expect(
        (await repos.tasks.findById(task.id))!.subtasks
            .map((Subtask s) => s.name.value),
        <String>['First', 'Second', 'Third'],
      );
    });

    test('TAG-4: each Item keeps the casing its user typed', () async {
      await repos.ideas.create(
        anIdea(id: 'i1', named: 'First', tags: <Tag>[tag('CS'), tag('Books')]),
      );
      await repos.ideas.create(
        anIdea(id: 'i2', named: 'Second', tags: <Tag>[tag('cs')]),
      );

      expect(
        (await repos.ideas.findById('i1'))!.tags.map((Tag t) => t.value),
        <String>['CS', 'Books'],
      );
      expect(
        (await repos.ideas.findById('i2'))!.tags.map((Tag t) => t.value),
        <String>['cs'],
        reason:
            'a shared vocabulary table would have forced one global casing '
            'on both (§11.5.1)',
      );
    });

    test('free text is stored exactly as typed, not trimmed', () async {
      const String context = '  Two paragraphs.\n\n    Indented.  ';
      await repos.ideas.create(anIdea(context: context));

      expect(
        (await repos.ideas.findById('idea-1'))!.context.value,
        context,
        reason: 'unlike a name, §3.2 free text is the user\'s to format',
      );
    });
  });

  group('§11.4.6: an entity survives the round trip field for field', () {
    test('a fully populated Task', () async {
      final Task task = aTask(
        id: 't1',
        named: 'Everything at once',
        status: TaskStatus.done,
        description: 'A description',
        tags: <Tag>[tag('home'), tag('Errand')],
        subtasks: <Subtask>[
          aSubtask(id: 's1', named: 'One', status: TaskStatus.done),
          aSubtask(id: 's2', named: 'Two', status: TaskStatus.done),
        ],
        createdAt: base,
        updatedAt: at(10),
        completedAt: at(10),
        sourceIdeaId: 'idea-1',
        sourceIdeaCreatedAt: at(-60),
      );

      await repos.tasks.create(task);

      expect((await repos.tasks.findById('t1')), task);
    });

    test('a fully populated Idea', () async {
      final Idea idea = anIdea(
        id: 'i1',
        named: 'Everything at once',
        timeframe: Timeframe.distant,
        tags: <Tag>[tag('cs')],
        context: 'Some context',
        createdAt: base,
        updatedAt: at(10),
      );

      await repos.ideas.create(idea);

      expect(await repos.ideas.findById('i1'), idea);
    });
  });
}

/// Re-derives `normalizeName` for every stored row and compares it with the
/// `name_normalized` column, for both kinds and for the tag tables' own
/// `value_normalized`.
Future<int> _rowCount(TestRepositories repos, String table) async {
  final QueryRow row = await repos.db
      .customSelect('SELECT count(*) AS c FROM $table')
      .getSingle();
  return row.data['c']! as int;
}

Future<void> _expectNormalizedColumnsAgree(TestRepositories repos) async {
  for (final (String table, String source, String derived)
      in <(String, String, String)>[
        ('ideas', 'name', 'name_normalized'),
        ('tasks', 'name', 'name_normalized'),
      ]) {
    final List<QueryRow> rows = await repos.db
        .customSelect('SELECT id, $source, $derived FROM $table')
        .get();
    for (final QueryRow row in rows) {
      expect(
        row.data[derived],
        normalizeName(row.data[source]! as String),
        reason: '$table row ${row.data['id']} has a stale $derived',
      );
    }
  }

  for (final String table in <String>['idea_tags', 'task_tags']) {
    final List<QueryRow> rows = await repos.db
        .customSelect('SELECT owner_id, value, value_normalized FROM $table')
        .get();
    for (final QueryRow row in rows) {
      expect(
        row.data['value_normalized'],
        normalizeTag(row.data['value']! as String),
        reason: '$table row ${row.data['owner_id']} has a stale normalization',
      );
    }
  }
}

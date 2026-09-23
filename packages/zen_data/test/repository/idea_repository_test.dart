/// §11.4.6, §11.5. The Idea repository, and DEL-3's tombstone.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zen_domain/zen_domain.dart';

import '../support/harness.dart';

void main() {
  late TestRepositories repos;

  setUp(() => repos = TestRepositories());

  group('CREATE-1, CREATE-4: creating', () {
    test('an Idea is persisted with its tags in order', () async {
      final Idea idea = anIdea(
        timeframe: Timeframe.soon,
        tags: <Tag>[tag('cs'), tag('Books')],
        context: 'A longer context',
      );

      expect((await repos.ideas.create(idea)).isOk, isTrue);

      expect(await repos.ideas.findById(idea.id), idea);
      expect(
        (await repos.ideas.findById(idea.id))!.tags.map((Tag t) => t.value),
        <String>['cs', 'Books'],
      );
    });

    test('NAME-6: a colliding name is refused by the index', () async {
      await repos.ideas.create(anIdea(id: 'i1', named: 'Read SICP'));

      final Result<Idea, RuleViolation> result = await repos.ideas.create(
        anIdea(id: 'i2', named: 'read  SICP'),
      );

      expect(result.errorOrNull, const IdeaNameCollision());
      expect(
        result.errorOrNull!.message,
        'An idea with this name already exists.',
      );
      expect(await repos.ideas.findById('i2'), isNull);
    });

    test('a refused create leaves no tags behind', () async {
      await repos.ideas.create(anIdea(id: 'i1', named: 'Read SICP'));
      await repos.ideas.create(
        anIdea(id: 'i2', named: 'Read SICP', tags: <Tag>[tag('cs')]),
      );

      expect(await _count(repos, 'idea_tags'), 0);
    });

    test('INV-7: an Idea cannot be created under a tombstoned id', () async {
      await repos.ideas.create(anIdea(id: 'i1'));
      await repos.ideas.delete('i1', at(10));

      await expectLater(
        repos.ideas.create(anIdea(id: 'i1', named: 'A different name')),
        throwsA(isA<Object>()),
        reason: 'the INV-7 trigger, not something the user can reach',
      );
    });
  });

  group('§11.4.6: editing', () {
    test('an edit replaces the tag list wholesale', () async {
      final Idea idea = anIdea(tags: <Tag>[tag('cs'), tag('books')]);
      await repos.ideas.create(idea);

      await repos.ideas.update(
        idea.copyWith(tags: <Tag>[tag('Books')], updatedAt: at(10)),
      );

      final Idea stored = (await repos.ideas.findById(idea.id))!;
      expect(
        stored.tags.map((Tag t) => t.value),
        <String>['Books'],
        reason:
            'TAG-4 keys on the normalized value, so a case-only change would '
            'collide with its own old row if the list were not replaced',
      );
    });

    test('renaming onto another Idea is refused and rolls back', () async {
      await repos.ideas.create(anIdea(id: 'i1', named: 'Read SICP'));
      final Idea other = anIdea(id: 'i2', named: 'Call the bank');
      await repos.ideas.create(other);

      final Result<Idea, RuleViolation> result = await repos.ideas.update(
        other.copyWith(name: name('Read SICP'), updatedAt: at(10)),
      );

      expect(result.errorOrNull, const IdeaNameCollision());
      expect((await repos.ideas.findById('i2'))!.name.value, 'Call the bank');
    });

    test('updating an Idea that does not exist is programmer error', () async {
      await expectLater(
        repos.ideas.update(anIdea()),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('DEL-3: deleting', () {
    test('the Idea is gone and a tombstone remains', () async {
      await repos.ideas.create(anIdea(id: 'i1', tags: <Tag>[tag('cs')]));

      await repos.ideas.delete('i1', at(10));

      expect(await repos.ideas.findById('i1'), isNull);
      expect(await _count(repos, 'idea_tags'), 0, reason: 'ON DELETE CASCADE');

      final List<IdeaTombstone> tombstones = await repos.tombstones.all();
      expect(tombstones, hasLength(1));
      expect(tombstones.single.id, 'i1');
      expect(tombstones.single.deletedAt, at(10));
      expect(tombstones.single.reason, TombstoneReason.deleted);
    });

    test('deleting an Idea that is already gone is a no-op', () async {
      await repos.ideas.create(anIdea(id: 'i1'));
      await repos.ideas.delete('i1', at(10));
      await repos.ideas.delete('i1', at(20));

      final List<IdeaTombstone> tombstones = await repos.tombstones.all();
      expect(tombstones, hasLength(1));
      expect(tombstones.single.deletedAt, at(10), reason: 'the first one wins');
    });

    test('AC-18: the freed name may be taken by a new Idea', () async {
      await repos.ideas.create(anIdea(id: 'x', named: 'Call bank'));
      await repos.ideas.delete('x', at(10));

      final Result<Idea, RuleViolation> fresh = await repos.ideas.create(
        anIdea(id: 'y', named: 'Call bank', createdAt: at(20)),
      );

      expect(fresh.isOk, isTrue);
      expect((await repos.ideas.watchAll().first).single.id, 'y');
    });
  });

  group('IDEAS-4: the list', () {
    test('watchAll is oldest first', () async {
      await repos.ideas.create(
        anIdea(id: 'i2', named: 'Second', createdAt: at(20)),
      );
      await repos.ideas.create(
        anIdea(id: 'i1', named: 'First', createdAt: at(10)),
      );

      expect(
        (await repos.ideas.watchAll().first).map((Idea i) => i.id),
        <String>['i1', 'i2'],
      );
    });

    test('the stream re-emits when a tag changes', () async {
      final Idea idea = anIdea(tags: <Tag>[tag('cs')]);
      await repos.ideas.create(idea);

      // Drained before the write: drift runs the first query asynchronously,
      // so a `skip(1)` taken beforehand could skip the new value itself.
      final List<List<Idea>> seen = <List<Idea>>[];
      final StreamSubscription<List<Idea>> subscription = repos.ideas
          .watchAll()
          .listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await repos.ideas.update(
        idea.copyWith(tags: const <Tag>[], updatedAt: at(10)),
      );
      await pumpEventQueue();

      expect(seen.first.single.tags, hasLength(1));
      expect(seen.last.single.tags, isEmpty);
    });

    test('an Idea with no tags survives the left join', () async {
      await repos.ideas.create(anIdea(id: 'i1', named: 'No tags'));
      await repos.ideas.create(
        anIdea(
          id: 'i2',
          named: 'Tagged',
          tags: <Tag>[tag('cs')],
          createdAt: at(10),
        ),
      );

      final List<Idea> all = await repos.ideas.watchAll().first;
      expect(all.map((Idea i) => i.id), <String>['i1', 'i2']);
      expect(all.first.tags, isEmpty);
      expect(all.last.tags, hasLength(1));
    });
  });

  group('§11.4.6: lookups for the UI', () {
    test('findActiveByNormalizedName matches AC-8 normalization', () async {
      await repos.ideas.create(anIdea(id: 'i1', named: 'Read SICP'));

      expect(
        (await repos.ideas.findActiveByNormalizedName(
          normalizeName('read  sicp '),
        ))!.id,
        'i1',
      );
    });

    test('TAG-6: autocomplete de-duplicates case-insensitively', () async {
      await repos.ideas.create(
        anIdea(id: 'i1', named: 'First', tags: <Tag>[tag('CS')]),
      );
      await repos.ideas.create(
        anIdea(id: 'i2', named: 'Second', tags: <Tag>[tag('cs'), tag('books')]),
      );

      final List<Tag> values = await repos.ideas.activeTagValues();
      expect(values.map((Tag t) => t.normalized), <String>['books', 'cs']);
    });
  });
}

Future<int> _count(TestRepositories repos, String table) async {
  final row = await repos.db
      .customSelect('SELECT count(*) AS c FROM $table')
      .getSingle();
  return row.data['c']! as int;
}

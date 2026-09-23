/// §3.6, HIST-2, §11.5.1. Settings, the event log and the replica row.
library;

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
// `Settings` is both §3.6's record and the name drift gives the settings
// table's class; only the companion is needed from the latter.
import 'package:zen_data/src/database.dart' show EventsCompanion;
import 'package:zen_data/zen_data.dart';
import 'package:zen_domain/zen_domain.dart';

import '../support/harness.dart';

void main() {
  late TestRepositories repos;

  setUp(() => repos = TestRepositories());

  group('§3.6, SET-2: settings', () {
    test('an empty table reads as the factory defaults', () async {
      final Settings settings = await repos.settings.read();

      expect(settings.defaultIdeaTimeframe, Timeframe.now);
      expect(settings.expandedIdeaGroups, <Timeframe>{
        Timeframe.now,
        Timeframe.soon,
        Timeframe.later,
      });
      expect(settings.strikethroughDone, isTrue);
      expect(settings.endOfDay, const LocalTime(2, 0));
      expect(settings.theme, ThemeMode.system);
      expect(settings.decor, 'Basic');
      expect(settings.confirmDestructive, isTrue);
    });

    test('every field round-trips', () async {
      final Settings settings = Settings(
        defaultIdeaTimeframe: Timeframe.later,
        expandedIdeaGroups: const <Timeframe>{Timeframe.distant},
        strikethroughDone: false,
        endOfDay: const LocalTime(23, 45),
        theme: ThemeMode.dark,
        decor: 'Basic',
        confirmDestructive: false,
      );

      await repos.settings.write(settings);

      expect(await repos.settings.read(), settings);
    });

    test(
      'IDEAS-2: every group collapsed is a value, not a missing one',
      () async {
        await repos.settings.write(
          Settings(expandedIdeaGroups: const <Timeframe>{}),
        );

        expect((await repos.settings.read()).expandedIdeaGroups, isEmpty);
      },
    );

    test('§11.5.5: a malformed value falls back to its default', () async {
      await repos.db.customStatement(
        "INSERT INTO settings VALUES ('endOfDay', '25:99')",
      );
      await repos.db.customStatement(
        "INSERT INTO settings VALUES ('theme', 'chartreuse')",
      );
      await repos.db.customStatement(
        "INSERT INTO settings VALUES ('strikethroughDone', 'yes')",
      );

      final Settings settings = await repos.settings.read();

      expect(settings.endOfDay, const LocalTime(2, 0));
      expect(settings.theme, ThemeMode.system);
      expect(settings.strikethroughDone, isTrue);
    });

    test(
      '§11.5.5: an unrecognised group is dropped, not the whole set',
      () async {
        await repos.db.customStatement(
          "INSERT INTO settings VALUES ('expandedIdeaGroups', 'now,someday')",
        );

        expect((await repos.settings.read()).expandedIdeaGroups, <Timeframe>{
          Timeframe.now,
        });
      },
    );

    test('SET-2: the stream emits the new value', () async {
      // Subscribed and drained before the write, because drift runs the first
      // query asynchronously: a `skip(1)` taken before that query has run
      // would skip the *new* value and wait forever for a third.
      final List<Settings> seen = <Settings>[];
      final StreamSubscription<Settings> subscription = repos.settings
          .watch()
          .listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await repos.settings.write(Settings(theme: ThemeMode.light));
      await pumpEventQueue();

      expect(seen.first.theme, ThemeMode.system);
      expect(seen.last.theme, ThemeMode.light);
    });
  });

  group('HIST-2: the event log', () {
    test('a create is logged, oldest first', () async {
      await repos.ideas.create(anIdea(id: 'i1'));

      final List<ItemEvent> events = await repos.events.forItem('i1');
      expect(events.single.type, ItemEventType.created);
      expect(events.single.itemKind, ItemKind.idea);
      expect(events.single.timestamp, base);
    });

    test('an edit logs only what actually changed', () async {
      final Idea idea = anIdea(id: 'i1', tags: <Tag>[tag('cs')]);
      await repos.ideas.create(idea);

      await repos.ideas.update(
        idea.copyWith(
          name: name('A different name'),
          timeframe: Timeframe.later,
          updatedAt: at(10),
        ),
      );

      final List<ItemEventType> types = (await repos.events.forItem('i1'))
          .map((ItemEvent e) => e.type)
          .toList();
      expect(types, <ItemEventType>[
        ItemEventType.created,
        ItemEventType.renamed,
        ItemEventType.timeframeChanged,
      ]);
      expect(types, isNot(contains(ItemEventType.tagsChanged)));
      expect(types, isNot(contains(ItemEventType.contextChanged)));
    });

    test('an edit that changes nothing logs nothing', () async {
      final Idea idea = anIdea(id: 'i1');
      await repos.ideas.create(idea);

      await repos.ideas.update(idea);

      expect(await repos.events.forItem('i1'), hasLength(1));
    });

    test(
      'subtask adds, changes, removals and reorders are distinguished',
      () async {
        final Task task = aTask(
          id: 't1',
          subtasks: <Subtask>[
            aSubtask(id: 's1', named: 'One'),
            aSubtask(id: 's2', named: 'Two'),
          ],
        );
        await repos.tasks.create(task);

        // A reorder alone.
        await repos.tasks.update(
          task.copyWith(
            subtasks: <Subtask>[task.subtasks[1], task.subtasks[0]],
            updatedAt: at(10),
          ),
        );
        // A removal and an add.
        await repos.tasks.update(
          task.copyWith(
            subtasks: <Subtask>[
              task.subtasks[0],
              aSubtask(id: 's3', named: 'Three'),
            ],
            updatedAt: at(20),
          ),
        );

        final List<ItemEventType> types = (await repos.events.forItem('t1'))
            .map((ItemEvent e) => e.type)
            .toList();
        expect(types, contains(ItemEventType.subtasksReordered));
        expect(types, contains(ItemEventType.subtaskAdded));
        expect(types, contains(ItemEventType.subtaskRemoved));
      },
    );

    test(
      'the entry commits with the change it records, or not at all',
      () async {
        await repos.tasks.create(aTask(id: 't1', named: 'Buy milk'));

        // A refused create rolls the whole transaction back, log included.
        await repos.tasks.create(aTask(id: 't2', named: 'buy MILK'));

        expect(await repos.events.forItem('t2'), isEmpty);
      },
    );

    test(
      '§11.5.1: the cap keeps the most recent entries whatever their age',
      () async {
        // Fewer entries than the floor, all far older than the window.
        await repos.ideas.create(
          anIdea(id: 'i1', createdAt: at(-60 * 24 * 400)),
        );

        expect(await repos.events.prune(at(0)), 0);
        expect(await repos.events.forItem('i1'), hasLength(1));
      },
    );

    test('§11.5.1: nothing inside the retention window is pruned', () async {
      await _seedEvents(repos, count: EventLogCap.floor + 10, ageInDays: 1);

      expect(await repos.events.prune(base), 0);
    });

    test(
      '§11.5.1: entries past the window and past the floor are deleted',
      () async {
        // The floor is what saves the newest 5,000; everything older than it
        // *and* older than 365 days goes.
        await _seedEvents(repos, count: EventLogCap.floor, ageInDays: 1);
        await _seedEvents(repos, count: 25, ageInDays: 400, prefix: 'ancient');

        expect(await repos.events.prune(base), 25);
        expect(await _eventCount(repos), EventLogCap.floor);
      },
    );
  });

  group('§11.5.1: the replica row', () {
    test('it is created on first read and then stable', () async {
      final String first = await repos.replica.replicaId();
      final String second = await repos.replica.replicaId();

      expect(first, isNotEmpty);
      expect(second, first);
      expect(await repos.replica.deviceName(), 'test-device');
    });

    test('renaming the device keeps the id', () async {
      final String id = await repos.replica.replicaId();

      await repos.replica.setDeviceName('desktop');

      expect(await repos.replica.deviceName(), 'desktop');
      expect(await repos.replica.replicaId(), id);
    });
  });

  group('§9.3 step 1: the tombstone store', () {
    test(
      'tombstones come back sorted by id, as a snapshot wants them',
      () async {
        for (final String id in <String>['c', 'a', 'b']) {
          await repos.tombstones.add(
            IdeaTombstone(
              id: id,
              deletedAt: base,
              reason: TombstoneReason.deleted,
            ),
          );
        }

        expect(
          (await repos.tombstones.all()).map((IdeaTombstone t) => t.id),
          <String>['a', 'b', 'c'],
        );
        expect(await repos.tombstones.tombstonedIdeaIds(), <String>{
          'a',
          'b',
          'c',
        });
      },
    );

    test('adding one that is already present is ignored', () async {
      await repos.tombstones.add(
        IdeaTombstone(
          id: 'x',
          deletedAt: base,
          reason: TombstoneReason.deleted,
        ),
      );
      await repos.tombstones.add(
        IdeaTombstone(
          id: 'x',
          deletedAt: at(10),
          reason: TombstoneReason.converted,
        ),
      );

      final IdeaTombstone stored = (await repos.tombstones.all()).single;
      expect(stored.deletedAt, base, reason: 'the first one wins');
      expect(stored.reason, TombstoneReason.deleted);
    });
  });
}

/// Writes [count] log entries dated [ageInDays] before [base], straight to the
/// table: the cap is about volume, and driving it through the repositories
/// would take thousands of Ideas to reach.
Future<void> _seedEvents(
  TestRepositories repos, {
  required int count,
  required int ageInDays,
  String prefix = 'e',
}) async {
  final DateTime when = base.subtract(Duration(days: ageInDays));
  await repos.db.batch((Batch batch) {
    batch.insertAll(repos.db.events, <EventsCompanion>[
      for (int i = 0; i < count; i++)
        EventsCompanion.insert(
          eventId: '$prefix-$i',
          itemId: 'item-1',
          itemKind: ItemKind.idea.name,
          type: ItemEventType.created.name,
          timestamp: encodeInstant(when.add(Duration(milliseconds: i))),
        ),
    ]);
  });
}

Future<int> _eventCount(TestRepositories repos) async {
  final row = await repos.db
      .customSelect('SELECT count(*) AS c FROM events')
      .getSingle();
  return row.data['c']! as int;
}

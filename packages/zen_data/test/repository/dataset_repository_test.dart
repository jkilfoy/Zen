/// §11.4.6, STORE-3, STORE-4. `DatasetRepository.replaceAll` against a real
/// database.
///
/// The point of these tests is the *order* STORE-4 fixes. Every one of them
/// would pass against an in-memory fake; they are here because the schema's
/// triggers, foreign keys and partial unique indexes are the only enforcement
/// that ships (§11.5.2), and getting the order wrong aborts a transaction
/// rather than failing a unit test.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zen_data/zen_data.dart';
import 'package:zen_domain/zen_domain.dart';

import '../support/harness.dart';

void main() {
  late TestRepositories repos;
  late DriftDatasetRepository dataset;

  setUp(() {
    repos = TestRepositories();
    dataset = DriftDatasetRepository(repos.db);
  });

  Future<List<Idea>> ideasNow() => repos.ideas.watchAll().first;
  Future<List<Task>> tasksNow() => repos.tasks.watchAll().first;

  group('§11.6.5 step 6: wholesale replacement', () {
    test('replaces Ideas, Tasks and tombstones together', () async {
      await repos.ideas.create(anIdea(id: 'idea-old', named: 'Old idea'));
      await repos.tasks.create(aTask(id: 'task-old', named: 'Old task'));

      await dataset.replaceAll(
        ReplicaSnapshot(
          replicaId: 'replica-a',
          ideas: <Idea>[anIdea(id: 'idea-new', named: 'New idea')],
          tasks: <Task>[aTask(id: 'task-new', named: 'New task')],
          tombstones: <IdeaTombstone>[
            IdeaTombstone(
              id: 'idea-gone',
              deletedAt: base,
              reason: TombstoneReason.deleted,
            ),
          ],
        ),
      );

      expect((await ideasNow()).map((Idea i) => i.id), <String>['idea-new']);
      expect((await tasksNow()).map((Task t) => t.id), <String>['task-new']);
      expect(
        (await repos.tombstones.all()).map((IdeaTombstone t) => t.id),
        <String>['idea-gone'],
      );
    });

    test('an empty snapshot empties the dataset', () async {
      await repos.ideas.create(anIdea());
      await repos.tasks.create(aTask());

      await dataset.replaceAll(ReplicaSnapshot(replicaId: 'replica-a'));

      expect(await ideasNow(), isEmpty);
      expect(await tasksNow(), isEmpty);
    });

    test('subtasks and tags come back in their original order', () async {
      // MERGE-3A: both are sequences, not sets. "A merge that reorders them has
      // changed the user's data."
      await dataset.replaceAll(
        ReplicaSnapshot(
          replicaId: 'replica-a',
          tasks: <Task>[
            aTask(
              id: 'task-1',
              tags: <Tag>[tag('zulu'), tag('alpha'), tag('mike')],
              subtasks: <Subtask>[
                aSubtask(id: 'sub-3', named: 'Third'),
                aSubtask(id: 'sub-1', named: 'First'),
                aSubtask(id: 'sub-2', named: 'Second'),
              ],
            ),
          ],
        ),
      );

      final Task stored = (await tasksNow()).single;
      expect(stored.subtasks.map((Subtask s) => s.id), <String>[
        'sub-3',
        'sub-1',
        'sub-2',
      ]);
      expect(stored.tags.map((Tag t) => t.value), <String>[
        'zulu',
        'alpha',
        'mike',
      ]);
    });

    test('§11.6.5: two Tasks may swap names, which an upsert could not do', () async {
      // The reason the specification insists on delete-then-insert: "SQLite
      // evaluates unique indexes per statement and has no deferrable
      // constraints, so a row-by-row application transiently collides whenever
      // two Tasks swap names."
      await repos.tasks.create(aTask(id: 'task-1', named: 'Alpha'));
      await repos.tasks.create(aTask(id: 'task-2', named: 'Bravo'));

      await dataset.replaceAll(
        ReplicaSnapshot(
          replicaId: 'replica-a',
          tasks: <Task>[
            aTask(id: 'task-1', named: 'Bravo'),
            aTask(id: 'task-2', named: 'Alpha'),
          ],
        ),
      );

      final Map<String, String> names = <String, String>{
        for (final Task t in await tasksNow()) t.id: t.name.value,
      };
      expect(names, <String, String>{'task-1': 'Bravo', 'task-2': 'Alpha'});
    });
  });

  group('STORE-4: the order the schema forces', () {
    test('an Idea may take the name a tombstoned Idea no longer holds', () async {
      // Deleting `idea_tombstones` before `ideas` is what makes this work:
      // `inv7_tombstone_insert` aborts when the tombstoned Idea's row is still
      // present, and `inv7_idea_insert` aborts when the Idea's id is already
      // tombstoned. Only one order satisfies both.
      await repos.ideas.create(anIdea(id: 'idea-1', named: 'Water the plants'));
      await repos.ideas.delete('idea-1', base);

      await dataset.replaceAll(
        ReplicaSnapshot(
          replicaId: 'replica-a',
          ideas: <Idea>[anIdea(id: 'idea-2', named: 'Water the plants')],
          tombstones: <IdeaTombstone>[
            IdeaTombstone(
              id: 'idea-1',
              deletedAt: base,
              reason: TombstoneReason.deleted,
            ),
          ],
        ),
      );

      expect((await ideasNow()).single.id, 'idea-2');
    });

    test('a tombstone that an incoming Idea contradicts is refused', () async {
      // INV-7 is the database's, not the repository's. The merge cannot produce
      // this — §9.3 step 1 drops every tombstoned Idea — so if it fires, the
      // merge is broken and rolling back is the point.
      expect(
        dataset.replaceAll(
          ReplicaSnapshot(
            replicaId: 'replica-a',
            ideas: <Idea>[anIdea(id: 'idea-1')],
            tombstones: <IdeaTombstone>[
              IdeaTombstone(
                id: 'idea-1',
                deletedAt: base,
                reason: TombstoneReason.deleted,
              ),
            ],
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'a Done Task with a Done subtask lands, INV-2 notwithstanding',
      () async {
        // Tasks must be inserted before their subtasks — the foreign key needs
        // the owner row — and `inv2_subtask_insert` then checks each subtask
        // against the already-inserted Task.
        await dataset.replaceAll(
          ReplicaSnapshot(
            replicaId: 'replica-a',
            tasks: <Task>[
              aTask(
                id: 'task-1',
                status: TaskStatus.done,
                completedAt: at(5),
                subtasks: <Subtask>[
                  aSubtask(id: 'sub-1', status: TaskStatus.done),
                ],
              ),
            ],
          ),
        );

        expect((await tasksNow()).single.status, TaskStatus.done);
      },
    );
  });

  group('STORE-3: one transaction', () {
    test('a refused snapshot leaves the previous dataset untouched', () async {
      await repos.ideas.create(anIdea(id: 'idea-1', named: 'Keep me'));
      await repos.tasks.create(aTask(id: 'task-1', named: 'Keep me too'));

      // Two active Ideas sharing a normalized name: the partial unique index of
      // §11.5.2 rejects the second insert, and the whole transaction rolls back.
      await expectLater(
        dataset.replaceAll(
          ReplicaSnapshot(
            replicaId: 'replica-a',
            ideas: <Idea>[
              anIdea(id: 'idea-2', named: 'Duplicate'),
              anIdea(id: 'idea-3', named: 'DUPLICATE'),
            ],
          ),
        ),
        throwsA(isA<Exception>()),
      );

      expect((await ideasNow()).map((Idea i) => i.id), <String>['idea-1']);
      expect((await tasksNow()).map((Task t) => t.id), <String>['task-1']);
    });
  });

  group('STORE-4: what a replace must not touch', () {
    test('the event log survives, because it carries no foreign key', () async {
      // "The history of how the data got here survives the data being
      // replaced." A cascade here would be silent data loss of the audit trail.
      await repos.events.append(
        ItemEvent(
          eventId: 'event-1',
          itemId: 'task-1',
          itemKind: ItemKind.task,
          type: ItemEventType.created,
          timestamp: base,
        ),
      );

      await dataset.replaceAll(ReplicaSnapshot(replicaId: 'replica-a'));

      expect(await repos.events.forItem('task-1'), hasLength(1));
    });

    test('settings survive, because they are per replica (MERGE-3)', () async {
      await repos.settings.write(
        Settings(syncFolderEnabled: true, syncFolderLocation: r'D:\Sync\Zen'),
      );

      await dataset.replaceAll(ReplicaSnapshot(replicaId: 'replica-a'));

      final Settings after = await repos.settings.read();
      expect(after.syncFolderEnabled, isTrue);
      expect(after.syncFolderLocation, r'D:\Sync\Zen');
    });

    test('this replica\'s identity survives', () async {
      // §11.5.1: the replica row is this installation's, not the snapshot's.
      final String before = await repos.replica.replicaId();

      await dataset.replaceAll(ReplicaSnapshot(replicaId: 'someone-else'));

      expect(await repos.replica.replicaId(), before);
    });

    test('orphaned tag and subtask rows are not left behind', () async {
      await repos.tasks.create(
        aTask(
          id: 'task-1',
          tags: <Tag>[tag('work')],
          subtasks: <Subtask>[aSubtask(id: 'sub-1')],
        ),
      );
      await repos.ideas.create(anIdea(id: 'idea-1', tags: <Tag>[tag('home')]));

      await dataset.replaceAll(ReplicaSnapshot(replicaId: 'replica-a'));

      expect(await repos.db.select(repos.db.subtasks).get(), isEmpty);
      expect(await repos.db.select(repos.db.taskTags).get(), isEmpty);
      expect(await repos.db.select(repos.db.ideaTags).get(), isEmpty);
    });
  });
}

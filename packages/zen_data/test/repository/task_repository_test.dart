/// §11.4.6, §11.5. The Task repository, including AC-8, AC-9 and AC-10.
///
/// M3's definition of done requires AC-8, AC-9 and AC-10 to pass "against a
/// real in-memory database, AC-8/9/10 exercising the partial unique index
/// rather than an application check". That is why nothing here pre-checks a
/// name: the repositories attempt the write and translate the failure
/// (§11.5.2), so these tests would fail if the index were dropped.
/// `constraints_test.dart` attacks the index directly as well, from raw SQL.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zen_domain/zen_domain.dart';

import '../support/harness.dart';

void main() {
  late TestRepositories repos;

  setUp(() => repos = TestRepositories());

  group('CREATE-2, CREATE-4: creating', () {
    test('a Task is persisted with its subtasks and tags in order', () async {
      final Task task = aTask(
        subtasks: <Subtask>[
          aSubtask(id: 's1', named: 'Pack'),
          aSubtask(id: 's2', named: 'Clean'),
        ],
        tags: <Tag>[tag('home'), tag('Errand')],
      );

      expect((await repos.tasks.create(task)).isOk, isTrue);

      final Task stored = (await repos.tasks.findById(task.id))!;
      expect(stored, task, reason: 'CREATE-4: durable, and unchanged by it');
      expect(stored.subtasks.map((Subtask s) => s.name.value), <String>[
        'Pack',
        'Clean',
      ], reason: '§3.3: subtask order is user-controlled and visible');
      expect(stored.tags.map((Tag t) => t.value), <String>[
        'home',
        'Errand',
      ], reason: 'TAG-4: the case the user typed, in the order they typed it');
    });

    test('AC-8: a colliding name is refused by the index', () async {
      await repos.tasks.create(aTask(id: 't1', named: 'Buy milk'));

      final Result<Task, RuleViolation> result = await repos.tasks.create(
        // AC-8's exact input: different case, doubled internal space.
        aTask(id: 't2', named: 'buy  MILK'),
      );

      expect(result.errorOrNull, const TaskNameCollision());
      expect(
        result.errorOrNull!.message,
        'A task with this name already exists.',
      );
      expect(await _count(repos), 1, reason: 'the second write rolled back');
    });

    test('AC-8: an Idea may take the same name as a Task', () async {
      await repos.tasks.create(aTask(named: 'Buy milk'));
      final Result<Idea, RuleViolation> idea = await repos.ideas.create(
        anIdea(named: 'Buy milk'),
      );
      expect(idea.isOk, isTrue, reason: 'independent namespaces (NAME-6)');
    });

    test('a refused create leaves no subtasks or tags behind', () async {
      await repos.tasks.create(aTask(id: 't1', named: 'Buy milk'));

      await repos.tasks.create(
        aTask(
          id: 't2',
          named: 'Buy milk',
          subtasks: <Subtask>[aSubtask()],
          tags: <Tag>[tag('home')],
        ),
      );

      expect(await repos.tasks.findById('t2'), isNull);
      expect(await _countTable(repos, 'subtasks'), 0);
      expect(await _countTable(repos, 'task_tags'), 0);
    });
  });

  group('AC-9: name reuse after archive', () {
    test('an archived Task does not reserve its name', () async {
      await repos.tasks.create(
        aTask(
          id: 't1',
          named: 'Water the plants',
          status: TaskStatus.done,
          isArchived: true,
          archivedAt: at(600),
        ),
      );

      final Result<Task, RuleViolation> fresh = await repos.tasks.create(
        aTask(id: 't2', named: 'Water the plants', createdAt: at(700)),
      );

      expect(fresh.isOk, isTrue);
      expect(await _count(repos), 2, reason: 'one archived, one active');
    });

    test('a soft-deleted Task does not reserve its name either', () async {
      await repos.tasks.create(aTask(id: 't1', named: 'Water the plants'));
      await repos.tasks.softDelete('t1', at(10));

      expect(
        (await repos.tasks.create(
          aTask(id: 't2', named: 'Water the plants', createdAt: at(20)),
        )).isOk,
        isTrue,
      );
    });
  });

  group('AC-10: reactivation is blocked by the index', () {
    test('unarchiving into a held name is refused with the NAME-9 copy', () async {
      // Continuing AC-9.
      await repos.tasks.create(
        aTask(
          id: 't1',
          named: 'Water the plants',
          status: TaskStatus.done,
          isArchived: true,
          archivedAt: at(600),
        ),
      );
      await repos.tasks.create(
        aTask(id: 't2', named: 'Water the plants', createdAt: at(700)),
      );

      final Result<Task, RuleViolation> result = await repos.tasks.unarchive(
        't1',
        at(800),
      );

      expect(result.errorOrNull, const ActiveTaskHoldsName());
      expect(
        result.errorOrNull!.message,
        'There is already an active task with this name in your To Do list. '
        'Complete and archive the active task in order to restore this one to '
        'your To Do list.',
      );

      final Task unchanged = (await repos.tasks.findById('t1'))!;
      expect(unchanged.isArchived, isTrue, reason: 'the write rolled back');
      expect(unchanged.archivedAt, at(600));
      expect(unchanged.status, TaskStatus.done);
    });

    test('the same applies to restoring a deleted Task', () async {
      await repos.tasks.create(aTask(id: 't1', named: 'Water the plants'));
      await repos.tasks.softDelete('t1', at(10));
      await repos.tasks.create(
        aTask(id: 't2', named: 'Water the plants', createdAt: at(20)),
      );

      final Result<Task, RuleViolation> result = await repos.tasks.restore(
        't1',
        at(30),
      );

      expect(result.errorOrNull, const ActiveTaskHoldsName());
      expect((await repos.tasks.findById('t1'))!.isDeleted, isTrue);
    });

    test('ARCH-3: unarchiving succeeds when the name is free', () async {
      await repos.tasks.create(
        aTask(
          id: 't1',
          named: 'Water the plants',
          status: TaskStatus.done,
          subtasks: <Subtask>[aSubtask(status: TaskStatus.done)],
          isArchived: true,
          archivedAt: at(600),
        ),
      );

      final Task result = (await repos.tasks.unarchive('t1', at(800))).unwrap();

      expect(result.isArchived, isFalse);
      expect(result.archivedAt, isNull);
      expect(result.status, TaskStatus.todo, reason: 'ARCH-3');
      expect(result.completedAt, isNull);
      expect(result.updatedAt, at(800), reason: 'ARCH-3 is a user action');
      expect((await repos.tasks.findById('t1')), result);
    });

    test(
      'D-M1-10: a Task that is both archived and deleted reserves no name',
      () async {
        await repos.tasks.create(
          aTask(
            id: 't1',
            named: 'Water the plants',
            status: TaskStatus.done,
            isArchived: true,
            archivedAt: at(600),
            isDeleted: true,
            deletedAt: at(600),
          ),
        );
        await repos.tasks.create(
          aTask(id: 't2', named: 'Water the plants', createdAt: at(700)),
        );

        // Unarchiving lands it back in the deleted set, not the To Do list, so
        // the partial index never sees it.
        final Result<Task, RuleViolation> result = await repos.tasks.unarchive(
          't1',
          at(800),
        );

        expect(result.isOk, isTrue);
        expect(result.unwrap().isActive, isFalse);
      },
    );
  });

  group('§11.4.6: editing', () {
    test('AC-5: reopening a Done Task and adding a subtask', () async {
      final Task done = aTask(
        status: TaskStatus.done,
        subtasks: <Subtask>[aSubtask(id: 's1', status: TaskStatus.done)],
      );
      await repos.tasks.create(done);

      // The INV-2 triggers make this the interesting case: the Task must stop
      // being Done before an open subtask can exist under it.
      final Task reopened = reopenTask(done, at(10)).unwrap();
      final Task withNew = addSubtask(
        reopened,
        subtaskName('Proofread'),
        at(10),
        SequentialIds(),
      ).unwrap();

      expect((await repos.tasks.update(withNew)).isOk, isTrue);

      final Task stored = (await repos.tasks.findById(done.id))!;
      expect(stored.status, TaskStatus.todo);
      expect(stored.completedAt, isNull);
      expect(stored.subtasks, hasLength(2));
    });

    test('completing a Task whose subtasks are all Done', () async {
      final Task task = aTask(
        subtasks: <Subtask>[aSubtask(id: 's1', status: TaskStatus.done)],
      );
      await repos.tasks.create(task);

      final Task completed = completeTask(task, at(10)).unwrap();
      expect((await repos.tasks.update(completed)).isOk, isTrue);

      expect((await repos.tasks.findById(task.id))!.status, TaskStatus.done);
    });

    test('a removed subtask is really gone, and order is rewritten', () async {
      final Task task = aTask(
        subtasks: <Subtask>[
          aSubtask(id: 's1', named: 'First'),
          aSubtask(id: 's2', named: 'Second'),
          aSubtask(id: 's3', named: 'Third'),
        ],
      );
      await repos.tasks.create(task);

      await repos.tasks.update(
        task.copyWith(
          subtasks: <Subtask>[task.subtasks[2], task.subtasks[0]],
          updatedAt: at(10),
        ),
      );

      final Task stored = (await repos.tasks.findById(task.id))!;
      expect(stored.subtasks.map((Subtask s) => s.name.value), <String>[
        'Third',
        'First',
      ]);
    });

    test('renaming onto another active Task is refused', () async {
      await repos.tasks.create(aTask(id: 't1', named: 'Buy milk'));
      final Task other = aTask(id: 't2', named: 'Buy bread');
      await repos.tasks.create(other);

      final Result<Task, RuleViolation> result = await repos.tasks.update(
        other.copyWith(name: name('Buy milk'), updatedAt: at(10)),
      );

      expect(result.errorOrNull, const TaskNameCollision());
      expect(
        (await repos.tasks.findById('t2'))!.name.value,
        'Buy bread',
        reason: 'the delete-and-reinsert rolled back whole',
      );
    });

    test(
      'NAME-8: renaming a Task to its own name is not a collision',
      () async {
        final Task task = aTask(id: 't1', named: 'Buy milk');
        await repos.tasks.create(task);

        final Result<Task, RuleViolation> result = await repos.tasks.update(
          task.copyWith(name: name('BUY  milk'), updatedAt: at(10)),
        );

        expect(result.isOk, isTrue);
        expect((await repos.tasks.findById('t1'))!.name.value, 'BUY  milk');
      },
    );

    test('updating a Task that does not exist is programmer error', () async {
      await expectLater(
        repos.tasks.update(aTask()),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('TODO-1, TODO-2, ARCH-1: the lists', () {
    test('watchActive is the To Do list, oldest first', () async {
      await repos.tasks.create(
        aTask(id: 't2', named: 'Second', createdAt: at(20)),
      );
      await repos.tasks.create(
        aTask(id: 't1', named: 'First', createdAt: at(10)),
      );
      await repos.tasks.create(
        aTask(
          id: 't3',
          named: 'Archived',
          createdAt: at(5),
          status: TaskStatus.done,
          isArchived: true,
          archivedAt: at(600),
        ),
      );
      await repos.tasks.create(
        aTask(id: 't4', named: 'Deleted', createdAt: at(1), isDeleted: true),
      );

      final List<Task> active = await repos.tasks.watchActive().first;

      expect(
        active.map((Task t) => t.id),
        <String>['t1', 't2'],
        reason:
            'TODO-1 excludes archived and deleted; TODO-2 orders by '
            'createdAt ascending',
      );
    });

    test('TODO-2: completing a Task does not move it', () async {
      final Task first = aTask(id: 't1', named: 'First', createdAt: at(10));
      await repos.tasks.create(first);
      await repos.tasks.create(
        aTask(id: 't2', named: 'Second', createdAt: at(20)),
      );

      await repos.tasks.update(completeTask(first, at(30)).unwrap());

      expect(
        (await repos.tasks.watchActive().first).map((Task t) => t.id),
        <String>['t1', 't2'],
      );
    });

    test('watchArchived is the archive, newest completion first', () async {
      for (final (String id, int minute) in <(String, int)>[
        ('t1', 10),
        ('t2', 30),
        ('t3', 20),
      ]) {
        await repos.tasks.create(
          aTask(
            id: id,
            named: 'Task $id',
            status: TaskStatus.done,
            createdAt: at(minute),
            completedAt: at(minute),
            isArchived: true,
            archivedAt: at(600),
          ),
        );
      }

      expect(
        (await repos.tasks.watchArchived().first).map((Task t) => t.id),
        <String>['t2', 't3', 't1'],
      );
    });

    test('the list stream re-emits when a subtask changes', () async {
      final Task task = aTask(subtasks: <Subtask>[aSubtask(id: 's1')]);
      await repos.tasks.create(task);

      final Future<List<Task>> second = repos.tasks.watchActive().skip(1).first;
      await repos.tasks.update(
        task.copyWith(subtasks: const <Subtask>[], updatedAt: at(10)),
      );

      expect((await second).single.subtasks, isEmpty);
    });
  });

  group('§11.4.6: name lookups for the UI', () {
    test('findActiveByNormalizedName ignores archived and deleted', () async {
      await repos.tasks.create(
        aTask(
          id: 't1',
          named: 'Water the plants',
          status: TaskStatus.done,
          isArchived: true,
          archivedAt: at(600),
        ),
      );

      expect(
        await repos.tasks.findActiveByNormalizedName(
          normalizeName('Water the plants'),
        ),
        isNull,
      );

      await repos.tasks.create(
        aTask(id: 't2', named: 'Water the plants', createdAt: at(700)),
      );
      expect(
        (await repos.tasks.findActiveByNormalizedName(
          normalizeName('water  THE plants'),
        ))!.id,
        't2',
      );
    });

    test('activeNormalizedNames is what NAME-8 checks against', () async {
      await repos.tasks.create(aTask(id: 't1', named: 'Buy milk'));
      await repos.tasks.create(
        aTask(id: 't2', named: 'Gone', isDeleted: true, deletedAt: at(10)),
      );

      expect(await repos.tasks.activeNormalizedNames(), <String>{'buy milk'});
    });

    test('TAG-6: autocomplete draws only from active Tasks', () async {
      await repos.tasks.create(
        aTask(id: 't1', named: 'Active', tags: <Tag>[tag('Home')]),
      );
      await repos.tasks.create(
        aTask(
          id: 't2',
          named: 'Gone',
          tags: <Tag>[tag('secret')],
          isDeleted: true,
          deletedAt: at(10),
        ),
      );

      expect(
        (await repos.tasks.activeTagValues()).map((Tag t) => t.value),
        <String>['Home'],
      );
    });
  });
}

/// A trivial [IdGenerator] for the one test that adds a subtask.
final class SequentialIds implements IdGenerator {
  int _next = 0;

  @override
  String newId() => 'new-${_next++}';
}

Future<int> _count(TestRepositories repos) => _countTable(repos, 'tasks');

Future<int> _countTable(TestRepositories repos, String table) async {
  final row = await repos.db
      .customSelect('SELECT count(*) AS c FROM $table')
      .getSingle();
  return row.data['c']! as int;
}

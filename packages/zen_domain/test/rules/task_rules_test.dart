import 'package:test/test.dart';
import 'package:zen_domain/testing.dart';
import 'package:zen_domain/zen_domain.dart';

import '../support/fixtures.dart';

/// §4.1, §4.2, §4.5, §4.6. Every rule that acts on a whole Task.
void main() {
  late SequentialIdGenerator ids;

  setUp(() => ids = SequentialIdGenerator(prefix: 'task'));

  group('§4.1 CREATE-2, CREATE-3: creating a Task', () {
    test('CREATE-2: a Task is created from a valid name alone', () {
      final Task task = createTask(
        name: name('Buy milk'),
        now: base,
        ids: ids,
      ).unwrap();

      expect(task.name.value, 'Buy milk');
      expect(task.status, TaskStatus.todo);
      expect(task.tags, isEmpty);
      expect(task.description, ItemText.empty);
      expect(task.subtasks, isEmpty);
      expect(task.createdAt, base);
      expect(task.updatedAt, base);
      expect(task.completedAt, isNull);
      expect(task.isArchived, isFalse);
      expect(task.isDeleted, isFalse);
    });

    test('CREATE-2: tags, description and subtasks are optional extras', () {
      final Task task = createTask(
        name: name('Buy milk'),
        now: base,
        ids: ids,
        tags: <Tag>[tag('errands'), tag('ERRANDS'), tag('food')],
        description: description('Two litres'),
        subtasks: <Subtask>[aSubtask()],
      ).unwrap();

      // TAG-4: the duplicate is dropped, keeping the first case typed.
      expect(task.tags.map((Tag t) => t.value), <String>['errands', 'food']);
      expect(task.description.value, 'Two litres');
      expect(task.subtasks, hasLength(1));
    });

    test('CREATE-3: creation is blocked on a name collision', () {
      final Result<Task, RuleViolation> result = createTask(
        name: name('Buy milk'),
        now: base,
        ids: ids,
        activeTaskNormalizedNames: <String>{'buy milk'},
      );

      expect(result.errorOrNull, const TaskNameCollision());
      expect(
        result.errorOrNull!.message,
        'A task with this name already exists.',
      );
    });

    test('§3: each Task gets a fresh id', () {
      final Task a = createTask(
        name: name('One'),
        now: base,
        ids: ids,
      ).unwrap();
      final Task b = createTask(
        name: name('Two'),
        now: base,
        ids: ids,
      ).unwrap();
      expect(a.id, isNot(b.id));
    });
  });

  group('§4.2: the completion circle', () {
    test('row 1: Todo with no subtasks completes and stamps completedAt', () {
      final Task result = toggleTaskCompletion(aTask(), at(5)).unwrap();

      expect(result.status, TaskStatus.done);
      expect(result.completedAt, at(5));
      expect(result.updatedAt, at(5));
    });

    test('row 1: Todo with all subtasks Done completes', () {
      final Task task = aTask(
        subtasks: <Subtask>[
          aSubtask(id: 's1', status: TaskStatus.done),
          aSubtask(id: 's2', status: TaskStatus.done),
        ],
      );

      expect(
        toggleTaskCompletion(task, at(5)).unwrap().status,
        TaskStatus.done,
      );
    });

    test('row 2: Todo with an incomplete subtask does not change', () {
      final Task task = aTask(
        subtasks: <Subtask>[
          aSubtask(id: 's1', status: TaskStatus.done),
          aSubtask(id: 's2'),
        ],
      );
      final Result<Task, RuleViolation> result = toggleTaskCompletion(
        task,
        at(5),
      );

      expect(result.errorOrNull, const IncompleteSubtasks());
      expect(
        result.errorOrNull!.message,
        'This task has incomplete subtasks. Complete the subtasks before '
        'finishing this task.',
      );
    });

    test('row 2: a Blocked subtask also blocks completion', () {
      final Task task = aTask(
        subtasks: <Subtask>[aSubtask(status: TaskStatus.blocked)],
      );
      expect(
        toggleTaskCompletion(task, at(5)).errorOrNull,
        const IncompleteSubtasks(),
      );
    });

    test('row 3: Done reopens and clears completedAt', () {
      final Task done = aTask(status: TaskStatus.done);
      final Task result = toggleTaskCompletion(done, at(5)).unwrap();

      expect(result.status, TaskStatus.todo);
      expect(result.completedAt, isNull);
      expect(result.updatedAt, at(5));
    });

    test('row 3, SUB-3: reopening leaves subtask statuses as they were', () {
      final Task done = aTask(
        status: TaskStatus.done,
        subtasks: <Subtask>[aSubtask(status: TaskStatus.done)],
      );
      final Task result = toggleTaskCompletion(done, at(5)).unwrap();

      expect(result.subtasks.single.status, TaskStatus.done);
      expect(result.subtaskStatusesLocked, isFalse);
    });

    test(
      'row 4, STATUS-1, AC-7: Blocked does not toggle, and says nothing',
      () {
        final Task blocked = aTask(status: TaskStatus.blocked);
        final Result<Task, RuleViolation> result = toggleTaskCompletion(
          blocked,
          at(5),
        );

        expect(result.errorOrNull, const TaskBlocked());
        expect(result.errorOrNull!.hasMessage, isFalse);
      },
    );

    test('STATUS-1: the circle can never produce Blocked', () {
      for (final TaskStatus from in TaskStatus.values) {
        final Task task = aTask(
          status: from,
          // A Blocked task toggles to nothing; the others must not reach
          // Blocked either.
        );
        final Task? after = toggleTaskCompletion(task, at(5)).valueOrNull;
        if (after != null && from != TaskStatus.blocked) {
          expect(after.status, isNot(TaskStatus.blocked), reason: '$from');
        }
      }
    });

    test('completeTask on an already Done task is a no-op', () {
      final Task done = aTask(status: TaskStatus.done);
      expect(completeTask(done, at(5)).unwrap(), done);
    });

    test('reopenTask on an already Todo task is a no-op', () {
      final Task todo = aTask();
      expect(reopenTask(todo, at(5)).unwrap(), todo);
    });
  });

  group('§4.2 last row: the Edit screen status control', () {
    test('any status can be set directly, unlike the circle', () {
      final Task result = setTaskStatus(
        aTask(),
        TaskStatus.blocked,
        at(5),
      ).unwrap();

      expect(result.status, TaskStatus.blocked);
      expect(result.completedAt, isNull);
    });

    test('TASKFORM-4: setting Done with an open subtask is refused', () {
      final Task task = aTask(subtasks: <Subtask>[aSubtask()]);
      expect(
        setTaskStatus(task, TaskStatus.done, at(5)).errorOrNull,
        const IncompleteSubtasks(),
      );
    });

    test('INV-1: leaving Done clears completedAt', () {
      final Task done = aTask(status: TaskStatus.done);
      expect(
        setTaskStatus(done, TaskStatus.blocked, at(5)).unwrap().completedAt,
        isNull,
      );
    });

    test('INV-1: entering Done sets completedAt', () {
      expect(
        setTaskStatus(aTask(), TaskStatus.done, at(5)).unwrap().completedAt,
        at(5),
      );
    });

    test('setting the status it already has is a no-op', () {
      final Task task = aTask(status: TaskStatus.blocked);
      expect(setTaskStatus(task, TaskStatus.blocked, at(5)).unwrap(), task);
    });

    test('STATUS-3: nothing else changes as a side effect', () {
      final Task task = aTask(
        tags: <Tag>[tag('work')],
        describedAs: description('Notes'),
        subtasks: <Subtask>[aSubtask(status: TaskStatus.done)],
      );
      final Task result = setTaskStatus(task, TaskStatus.done, at(5)).unwrap();

      expect(result.name, task.name);
      expect(result.tags, task.tags);
      expect(result.description, task.description);
      expect(result.subtasks, task.subtasks);
      expect(result.createdAt, task.createdAt);
      expect(result.isArchived, isFalse);
      expect(result.isDeleted, isFalse);
    });
  });

  group('STATUS-4: an archived Task cannot change status', () {
    final Task archived = aTask(status: TaskStatus.done, isArchived: true);

    test('the completion circle refuses', () {
      expect(
        toggleTaskCompletion(archived, at(5)).errorOrNull,
        const ArchivedTaskImmutable(),
      );
    });

    test('the status control refuses', () {
      expect(
        setTaskStatus(archived, TaskStatus.todo, at(5)).errorOrNull,
        const ArchivedTaskImmutable(),
      );
    });
  });

  group('DEL-1, SEARCH-3: a deleted Task cannot change status', () {
    final Task deleted = aTask(isDeleted: true);

    test('the completion circle refuses', () {
      expect(
        toggleTaskCompletion(deleted, at(5)).errorOrNull,
        const DeletedTaskImmutable(),
      );
    });

    test('the status control refuses', () {
      expect(
        setTaskStatus(deleted, TaskStatus.done, at(5)).errorOrNull,
        const DeletedTaskImmutable(),
      );
    });
  });

  group('§4.5 EOD-2, EOD-6: archiving', () {
    test('archiving records the boundary, not the sweep instant', () {
      final Task done = aTask(status: TaskStatus.done, completedAt: at(5));
      final DateTime boundary = at(600);
      final Task archived = archiveTask(done, boundary);

      expect(archived.isArchived, isTrue);
      expect(archived.archivedAt, boundary);
      expect(archived.status, TaskStatus.done);
      expect(archived.completedAt, at(5));
    });

    test('EOD-2A: archiving does not move updatedAt', () {
      final Task done = aTask(
        status: TaskStatus.done,
        createdAt: at(0),
        updatedAt: at(5),
        completedAt: at(5),
      );

      final Task archived = archiveTask(done, at(600));

      expect(archived.updatedAt, at(5), reason: 'EOD-2A: a system action');
      expect(archived.archivedAt, at(600), reason: 'the audit trail instead');
    });

    test('EOD-2A: a late edit is not pushed backwards by a late sweep', () {
      // The app is running, the boundary passes, and the user renames the Task
      // before the sweep fires. Without EOD-2A the sweep would rewrite
      // updatedAt to the boundary instant, which is *earlier* than the rename,
      // and §9.3 step 4 would then let a peer holding pre-edit content win.
      final DateTime boundary = at(600);
      final Task renamedAfterBoundary = aTask(
        status: TaskStatus.done,
        createdAt: at(0),
        updatedAt: at(660),
        completedAt: at(5),
      );

      final Task archived = archiveTask(renamedAfterBoundary, boundary);

      expect(archived.updatedAt, at(660));
      expect(archived.updatedAt.isAfter(boundary), isTrue);
      expect(archived.invariantFailures, isEmpty);
    });

    test('ARCH-3: un-archiving is a user action and does move updatedAt', () {
      final Task archived = aTask(
        status: TaskStatus.done,
        createdAt: at(0),
        updatedAt: at(5),
        completedAt: at(5),
        isArchived: true,
        archivedAt: at(600),
      );

      final Task result = unarchiveTask(archived, at(700)).unwrap();

      expect(result.updatedAt, at(700));
    });

    test('EOD-6: an archived Task leaves the active set', () {
      expect(
        archiveTask(aTask(status: TaskStatus.done), at(600)).isActive,
        isFalse,
      );
    });

    test('INV-3: archiving a Todo task is programmer error', () {
      expect(
        () => archiveTask(aTask(), at(600)),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('ARCH-3, ARCH-4: unarchiving', () {
    final Task archived = aTask(
      named: 'Water the plants',
      status: TaskStatus.done,
      completedAt: at(5),
      isArchived: true,
      archivedAt: at(600),
      subtasks: <Subtask>[aSubtask(status: TaskStatus.done)],
    );

    test('ARCH-3: it returns to Todo with completedAt cleared', () {
      final Task result = unarchiveTask(archived, at(700)).unwrap();

      expect(result.isArchived, isFalse);
      expect(result.archivedAt, isNull);
      expect(result.status, TaskStatus.todo);
      expect(result.completedAt, isNull);
      expect(result.isActive, isTrue);
    });

    test('ARCH-3: its subtask statuses are unlocked, keeping their values', () {
      final Task result = unarchiveTask(archived, at(700)).unwrap();

      expect(result.subtaskStatusesLocked, isFalse);
      expect(result.subtasks.single.status, TaskStatus.done);
    });

    test('ARCH-4, NAME-9, AC-10: blocked when an active Task holds the name', () {
      final Result<Task, RuleViolation> result = unarchiveTask(
        archived,
        at(700),
        activeTaskNormalizedNames: <String>{'water the plants'},
      );

      expect(result.errorOrNull, const ActiveTaskHoldsName());
      expect(
        result.errorOrNull!.message,
        'There is already an active task with this name in your To Do list. '
        'Complete and archive the active task in order to restore this one to '
        'your To Do list.',
      );
    });

    test(
      'a Task that is archived and deleted reserves no name, so it passes',
      () {
        final Task both = aTask(
          named: 'Water the plants',
          status: TaskStatus.done,
          completedAt: at(5),
          isArchived: true,
          archivedAt: at(600),
          isDeleted: true,
          deletedAt: at(650),
        );

        expect(
          unarchiveTask(
            both,
            at(700),
            activeTaskNormalizedNames: <String>{'water the plants'},
          ).isOk,
          isTrue,
        );
      },
    );

    test('unarchiving a Task that is not archived is a no-op', () {
      final Task task = aTask();
      expect(unarchiveTask(task, at(700)).unwrap(), task);
    });
  });

  group('§4.6 DEL-1, DEL-2: deleting and restoring a Task', () {
    test('DEL-1: deleting is a soft delete', () {
      final Task result = softDeleteTask(aTask(), at(5)).unwrap();

      expect(result.isDeleted, isTrue);
      expect(result.deletedAt, at(5));
      expect(result.isActive, isFalse);
    });

    test('DEL-1: a soft delete leaves everything else alone', () {
      final Task task = aTask(status: TaskStatus.blocked);
      final Task result = softDeleteTask(task, at(5)).unwrap();

      expect(result.status, TaskStatus.blocked);
      expect(result.name, task.name);
      expect(result.createdAt, task.createdAt);
    });

    test('deleting an already-deleted Task is a no-op', () {
      final Task deleted = aTask(isDeleted: true);
      expect(softDeleteTask(deleted, at(5)).unwrap(), deleted);
    });

    test(
      'DEL-2: restoring clears the flag and leaves the status as it was',
      () {
        final Task deleted = aTask(
          status: TaskStatus.done,
          completedAt: at(1),
          isDeleted: true,
          deletedAt: at(5),
        );
        final Task result = restoreTask(deleted, at(9)).unwrap();

        expect(result.isDeleted, isFalse);
        expect(result.deletedAt, isNull);
        expect(result.status, TaskStatus.done);
        expect(result.completedAt, at(1));
      },
    );

    test('DEL-2, NAME-9, AC-10: restoring into a held name is prohibited', () {
      final Task deleted = aTask(named: 'Buy milk', isDeleted: true);

      expect(
        restoreTask(
          deleted,
          at(9),
          activeTaskNormalizedNames: <String>{'buy milk'},
        ).errorOrNull,
        const ActiveTaskHoldsName(),
      );
    });

    test(
      'restoring an archived Task returns it to the archive, not the list',
      () {
        final Task both = aTask(
          named: 'Buy milk',
          status: TaskStatus.done,
          completedAt: at(1),
          isArchived: true,
          archivedAt: at(3),
          isDeleted: true,
          deletedAt: at(5),
        );
        final Task result = restoreTask(
          both,
          at(9),
          activeTaskNormalizedNames: <String>{'buy milk'},
        ).unwrap();

        expect(result.isDeleted, isFalse);
        expect(result.isArchived, isTrue);
        expect(result.isActive, isFalse);
      },
    );

    test('restoring a Task that is not deleted is a no-op', () {
      final Task task = aTask();
      expect(restoreTask(task, at(9)).unwrap(), task);
    });
  });
}

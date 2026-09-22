import 'package:test/test.dart';
import 'package:zen_domain/testing.dart';
import 'package:zen_domain/zen_domain.dart';

import '../support/fixtures.dart';

/// §4.3. SUB-1 through SUB-9.
void main() {
  late SequentialIdGenerator ids;

  setUp(() => ids = SequentialIdGenerator(prefix: 'sub'));

  /// A Todo task with one open subtask and one done one.
  Task twoSubtasks() => aTask(
    subtasks: <Subtask>[
      aSubtask(id: 's1', named: 'Draft', status: TaskStatus.done),
      aSubtask(id: 's2', named: 'Proofread'),
    ],
  );

  /// A Done task whose single subtask is Done, so INV-2 holds.
  Task doneWithDoneSubtask() => aTask(
    status: TaskStatus.done,
    subtasks: <Subtask>[aSubtask(id: 's1', status: TaskStatus.done)],
  );

  group('SUB-1, SUB-2: statuses lock while the parent is Done', () {
    test('SUB-1: a locked subtask\'s status cannot be set', () {
      final Result<Task, RuleViolation> result = setSubtaskStatus(
        doneWithDoneSubtask(),
        's1',
        TaskStatus.todo,
        at(5),
      );

      expect(result.errorOrNull, const SubtasksLocked());
    });

    test('SUB-2: the refusal carries the one-line hint', () {
      expect(
        toggleSubtaskCompletion(
          doneWithDoneSubtask(),
          's1',
          at(5),
        ).errorOrNull!.message,
        "Set the task back to Todo to change its subtasks' status.",
      );
    });

    test('SUB-2: neither the subtask nor the Task changes', () {
      final Task task = doneWithDoneSubtask();
      expect(toggleSubtaskCompletion(task, 's1', at(5)).isErr, isTrue);
      expect(task.status, TaskStatus.done);
      expect(task.subtasks.single.status, TaskStatus.done);
    });

    test(
      'SUB-6: only Done locks; a Blocked parent\'s subtasks still toggle',
      () {
        final Task blocked = aTask(
          status: TaskStatus.blocked,
          subtasks: <Subtask>[aSubtask(id: 's1')],
        );
        final Task result = toggleSubtaskCompletion(
          blocked,
          's1',
          at(5),
        ).unwrap();

        expect(result.subtasks.single.status, TaskStatus.done);
        expect(result.status, TaskStatus.blocked);
      },
    );

    test('SUB-3: leaving Done unlocks statuses, keeping their values', () {
      final Task reopened = reopenTask(doneWithDoneSubtask(), at(5)).unwrap();

      expect(reopened.subtaskStatusesLocked, isFalse);
      expect(reopened.subtasks.single.status, TaskStatus.done);
      expect(
        toggleSubtaskCompletion(
          reopened,
          's1',
          at(9),
        ).unwrap().subtasks.single.status,
        TaskStatus.todo,
      );
    });
  });

  group('SUB-4: the subtask completion circle', () {
    test('Todo toggles to Done and stamps completedAt', () {
      final Task result = toggleSubtaskCompletion(
        twoSubtasks(),
        's2',
        at(5),
      ).unwrap();
      final Subtask subtask = result.subtaskById('s2')!;

      expect(subtask.status, TaskStatus.done);
      expect(subtask.completedAt, at(5));
    });

    test('Done toggles back to Todo and clears completedAt', () {
      final Task result = toggleSubtaskCompletion(
        twoSubtasks(),
        's1',
        at(5),
      ).unwrap();
      final Subtask subtask = result.subtaskById('s1')!;

      expect(subtask.status, TaskStatus.todo);
      expect(subtask.completedAt, isNull);
    });

    test('a Blocked subtask does not toggle, and says nothing', () {
      final Task task = aTask(
        subtasks: <Subtask>[aSubtask(id: 's1', status: TaskStatus.blocked)],
      );
      final Result<Task, RuleViolation> result = toggleSubtaskCompletion(
        task,
        's1',
        at(5),
      );

      expect(result.errorOrNull, const SubtaskBlocked());
      expect(result.errorOrNull!.hasMessage, isFalse);
    });

    test('STATUS-2: completing the last open subtask does not complete the '
        'parent', () {
      final Task result = toggleSubtaskCompletion(
        twoSubtasks(),
        's2',
        at(5),
      ).unwrap();

      expect(result.allSubtasksDone, isTrue);
      expect(result.status, TaskStatus.todo);
      expect(result.completedAt, isNull);
    });

    test('§3.3: a subtask change moves the parent\'s updatedAt', () {
      final Task result = toggleSubtaskCompletion(
        twoSubtasks(),
        's2',
        at(5),
      ).unwrap();
      expect(result.updatedAt, at(5));
    });
  });

  group('SUB-5: the Edit screen sets any of the three values', () {
    test('a subtask can be set to Blocked', () {
      final Task result = setSubtaskStatus(
        twoSubtasks(),
        's2',
        TaskStatus.blocked,
        at(5),
      ).unwrap();

      expect(result.subtaskById('s2')!.status, TaskStatus.blocked);
      expect(result.subtaskById('s2')!.completedAt, isNull);
    });

    test('setting the status it already has is a no-op', () {
      final Task task = twoSubtasks();
      expect(
        setSubtaskStatus(task, 's2', TaskStatus.todo, at(5)).unwrap(),
        task,
      );
    });

    test('an unknown subtask id is programmer error', () {
      expect(
        () => setSubtaskStatus(twoSubtasks(), 'nope', TaskStatus.done, at(5)),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('SUB-8: adding a subtask', () {
    test('a Todo task accepts one, appended at the end and always Todo', () {
      final Task result = addSubtask(
        twoSubtasks(),
        subtaskName('Publish'),
        at(5),
        ids,
      ).unwrap();

      expect(result.subtasks, hasLength(3));
      expect(result.subtasks.last.name.value, 'Publish');
      expect(result.subtasks.last.status, TaskStatus.todo);
      expect(result.subtasks.last.createdAt, at(5));
    });

    test('a Blocked task accepts one', () {
      final Task blocked = aTask(status: TaskStatus.blocked);
      expect(
        addSubtask(blocked, subtaskName('Later'), at(5), ids).isOk,
        isTrue,
      );
    });

    test('SUB-8: adding a subtask to a Done task is rejected', () {
      final Result<Task, RuleViolation> result = addSubtask(
        doneWithDoneSubtask(),
        subtaskName('Extra'),
        at(5),
        ids,
      );

      expect(result.errorOrNull, const SubtaskAddForbiddenWhileDone());
    });

    test('SUB-8 with SUB-1 makes INV-2 unbreakable by a subtask edit', () {
      // The only way to make a Done Task incomplete is to change its own status
      // first: statuses are locked, and no new subtask can appear.
      final Task done = doneWithDoneSubtask();
      expect(addSubtask(done, subtaskName('X'), at(5), ids).isErr, isTrue);
      expect(
        setSubtaskStatus(done, 's1', TaskStatus.todo, at(5)).isErr,
        isTrue,
      );
      expect(done.invariantFailures, isEmpty);
    });

    test('§3: each subtask gets a fresh id', () {
      Task task = aTask();
      task = addSubtask(task, subtaskName('One'), at(5), ids).unwrap();
      task = addSubtask(task, subtaskName('Two'), at(6), ids).unwrap();

      expect(task.subtasks.first.id, isNot(task.subtasks.last.id));
    });
  });

  group('SUB-1, TASKFORM-5: renaming, deleting and reordering stay available', () {
    test('a Done task\'s subtask can still be renamed', () {
      final Task result = renameSubtask(
        doneWithDoneSubtask(),
        's1',
        subtaskName('Renamed'),
        at(5),
      ).unwrap();

      expect(result.subtasks.single.name.value, 'Renamed');
      expect(result.subtasks.single.status, TaskStatus.done);
    });

    test('SUB-7: deleting a subtask is a hard delete', () {
      final Task result = removeSubtask(twoSubtasks(), 's1', at(5)).unwrap();

      expect(result.subtasks, hasLength(1));
      expect(result.subtaskById('s1'), isNull);
    });

    test('a Done task\'s subtask can still be deleted', () {
      final Task result = removeSubtask(
        doneWithDoneSubtask(),
        's1',
        at(5),
      ).unwrap();

      expect(result.subtasks, isEmpty);
      // STATUS-3: removing the last subtask does not change the Task's status.
      expect(result.status, TaskStatus.done);
    });

    test('a Done task\'s subtasks can still be reordered', () {
      final Task done = aTask(
        status: TaskStatus.done,
        subtasks: <Subtask>[
          aSubtask(id: 's1', named: 'First', status: TaskStatus.done),
          aSubtask(id: 's2', named: 'Second', status: TaskStatus.done),
        ],
      );
      final Task result = reorderSubtasks(done, 0, 1, at(5)).unwrap();

      expect(result.subtasks.map((Subtask s) => s.id), <String>['s2', 's1']);
    });

    test('reordering moves the parent\'s updatedAt but not the subtasks\'', () {
      final Task task = twoSubtasks();
      final Task result = reorderSubtasks(task, 0, 1, at(5)).unwrap();

      expect(result.updatedAt, at(5));
      expect(
        result.subtaskById('s1')!.updatedAt,
        task.subtaskById('s1')!.updatedAt,
      );
    });

    test('reordering to the same index is a no-op', () {
      final Task task = twoSubtasks();
      expect(reorderSubtasks(task, 1, 1, at(5)).unwrap(), task);
    });

    test('an out-of-range index is programmer error', () {
      expect(
        () => reorderSubtasks(twoSubtasks(), 0, 5, at(5)),
        throwsA(isA<RangeError>()),
      );
    });

    test('renaming moves both the subtask\'s and the parent\'s updatedAt', () {
      final Task result = renameSubtask(
        twoSubtasks(),
        's2',
        subtaskName('Proof'),
        at(5),
      ).unwrap();

      expect(result.updatedAt, at(5));
      expect(result.subtaskById('s2')!.updatedAt, at(5));
    });

    test('NAME-11: two subtasks may share a name', () {
      Task task = aTask();
      task = addSubtask(task, subtaskName('Set'), at(5), ids).unwrap();
      task = addSubtask(task, subtaskName('Set'), at(6), ids).unwrap();

      expect(task.subtasks, hasLength(2));
      expect(task.invariantFailures, isEmpty);
    });
  });

  group('STATUS-4, DEL-1: archived and deleted Tasks refuse subtask edits', () {
    test('an archived Task refuses', () {
      final Task archived = aTask(
        status: TaskStatus.done,
        isArchived: true,
        subtasks: <Subtask>[aSubtask(id: 's1', status: TaskStatus.done)],
      );

      expect(
        renameSubtask(archived, 's1', subtaskName('X'), at(5)).errorOrNull,
        const ArchivedTaskImmutable(),
      );
      expect(
        removeSubtask(archived, 's1', at(5)).errorOrNull,
        const ArchivedTaskImmutable(),
      );
    });

    test('a deleted Task refuses', () {
      final Task deleted = aTask(
        isDeleted: true,
        subtasks: <Subtask>[aSubtask(id: 's1')],
      );

      expect(
        toggleSubtaskCompletion(deleted, 's1', at(5)).errorOrNull,
        const DeletedTaskImmutable(),
      );
      expect(
        addSubtask(deleted, subtaskName('X'), at(5), ids).errorOrNull,
        const DeletedTaskImmutable(),
      );
    });
  });
}

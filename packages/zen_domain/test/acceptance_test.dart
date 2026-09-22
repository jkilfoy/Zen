import 'package:test/test.dart';
import 'package:zen_domain/zen_domain.dart';

import 'support/fixtures.dart';

/// §10, §11.13 M1. The acceptance scenarios M1 is responsible for, written as
/// close to the specification's own wording as a pure domain test can get.
///
/// Each scenario has a UI half and a domain half. AC-2 asks for "a green check
/// shows and the name is struck through"; AC-3 asks for a hint to be "shown".
/// Those are rendering, and §11.13 re-runs all four as widget tests in M4.
/// What is asserted here is everything the domain is answerable for: the
/// status, the timestamps, and the exact copy the UI is required to render.
void main() {
  group('AC-1: complete blocked by subtasks', () {
    // "Given Task "Write report" with subtasks [Draft: Done, Proofread: Todo]."
    Task writeReport() => aTask(
      named: 'Write report',
      subtasks: <Subtask>[
        aSubtask(id: 'draft', named: 'Draft', status: TaskStatus.done),
        aSubtask(id: 'proofread', named: 'Proofread'),
      ],
    );

    test('the status stays Todo when the circle is tapped', () {
      final Task task = writeReport();
      final Result<Task, RuleViolation> result = toggleTaskCompletion(
        task,
        at(5),
      );

      expect(result.isErr, isTrue);
      expect(task.status, TaskStatus.todo);
      expect(task.completedAt, isNull);
    });

    test('the incomplete-subtasks popup copy is returned verbatim', () {
      final RuleViolation violation = toggleTaskCompletion(
        writeReport(),
        at(5),
      ).errorOrNull!;

      expect(violation, const IncompleteSubtasks());
      expect(
        violation.message,
        'This task has incomplete subtasks. Complete the subtasks before '
        'finishing this task.',
      );
    });
  });

  group('AC-2: complete', () {
    // "Given the same task with both subtasks Done."
    Task writeReportReady() => aTask(
      named: 'Write report',
      subtasks: <Subtask>[
        aSubtask(id: 'draft', named: 'Draft', status: TaskStatus.done),
        aSubtask(id: 'proofread', named: 'Proofread', status: TaskStatus.done),
      ],
    );

    test('the status becomes Done and completedAt is set', () {
      final Task result = toggleTaskCompletion(
        writeReportReady(),
        at(5),
      ).unwrap();

      expect(result.status, TaskStatus.done);
      expect(result.completedAt, at(5));
    });

    test('the default settings ask for a struck-through name', () {
      // The green check and the strikethrough are rendering, verified as a
      // widget test in M4 (§11.13). What the domain owns is the setting the
      // renderer reads, and that the Task is in the state TODO-3 draws as Done.
      expect(Settings().strikethroughDone, isTrue);
      expect(
        toggleTaskCompletion(writeReportReady(), at(5)).unwrap().status,
        TaskStatus.done,
      );
    });

    test('the Task stays in the To Do list until End of Day', () {
      // TODO-1: visible tasks are those not deleted and not archived, which
      // includes Done ones not yet archived.
      final Task result = toggleTaskCompletion(
        writeReportReady(),
        at(5),
      ).unwrap();

      expect(result.isArchived, isFalse);
      expect(result.isActive, isTrue);
    });
  });

  group('AC-3: subtask statuses lock when Done', () {
    // "Given a Done task with all subtasks Done."
    Task doneTask() => aTask(
      named: 'Write report',
      status: TaskStatus.done,
      completedAt: at(5),
      updatedAt: at(5),
      subtasks: <Subtask>[
        aSubtask(id: 'draft', named: 'Draft', status: TaskStatus.done),
      ],
    );

    test('tapping a subtask circle changes nothing', () {
      final Task task = doneTask();
      final Result<Task, RuleViolation> result = toggleSubtaskCompletion(
        task,
        'draft',
        at(9),
      );

      expect(result.isErr, isTrue);
      expect(task.status, TaskStatus.done);
      expect(task.subtaskById('draft')!.status, TaskStatus.done);
    });

    test('the hint copy is returned verbatim', () {
      expect(
        toggleSubtaskCompletion(
          doneTask(),
          'draft',
          at(9),
        ).errorOrNull!.message,
        "Set the task back to Todo to change its subtasks' status.",
      );
    });

    test('after the task goes to Todo, the subtask toggles', () {
      final Task reopened = toggleTaskCompletion(doneTask(), at(9)).unwrap();
      expect(reopened.status, TaskStatus.todo);

      final Task afterSubtask = toggleSubtaskCompletion(
        reopened,
        'draft',
        at(12),
      ).unwrap();

      expect(afterSubtask.subtaskById('draft')!.status, TaskStatus.todo);
      expect(afterSubtask.subtaskById('draft')!.completedAt, isNull);
      // STATUS-2, STATUS-3: the parent does not follow the subtask anywhere.
      expect(afterSubtask.status, TaskStatus.todo);
    });
  });

  group('AC-7: blocked not toggleable', () {
    // "Given a Blocked task."
    Task blockedTask() => aTask(
      named: 'Ship the thing',
      status: TaskStatus.blocked,
      subtasks: <Subtask>[
        aSubtask(id: 'test', named: 'Test'),
        aSubtask(id: 'docs', named: 'Docs', status: TaskStatus.done),
      ],
    );

    test('tapping its circle changes nothing', () {
      final Task task = blockedTask();
      final Result<Task, RuleViolation> result = toggleTaskCompletion(
        task,
        at(5),
      );

      expect(result.errorOrNull, const TaskBlocked());
      expect(task.status, TaskStatus.blocked);
      expect(task.completedAt, isNull);
    });

    test('the refusal is silent: §4.2 allows a nudge and no copy', () {
      expect(
        toggleTaskCompletion(blockedTask(), at(5)).errorOrNull!.hasMessage,
        isFalse,
      );
    });

    test('SUB-6: its subtasks remain toggleable', () {
      final Task task = blockedTask();

      final Task afterTest = toggleSubtaskCompletion(
        task,
        'test',
        at(5),
      ).unwrap();
      expect(afterTest.subtaskById('test')!.status, TaskStatus.done);
      expect(afterTest.status, TaskStatus.blocked);

      final Task afterDocs = toggleSubtaskCompletion(
        afterTest,
        'docs',
        at(9),
      ).unwrap();
      expect(afterDocs.subtaskById('docs')!.status, TaskStatus.todo);
      expect(afterDocs.status, TaskStatus.blocked);
    });

    test('STATUS-1: completing every subtask still does not unblock it', () {
      // STATUS-2 and STATUS-3 together: no status changes as a side effect.
      Task task = blockedTask();
      task = toggleSubtaskCompletion(task, 'test', at(5)).unwrap();

      expect(task.allSubtasksDone, isTrue);
      expect(task.status, TaskStatus.blocked);
      expect(
        toggleTaskCompletion(task, at(9)).errorOrNull,
        const TaskBlocked(),
      );
    });
  });
}

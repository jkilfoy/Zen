/// §4.1, §4.2, TASKFORM-3, TASKFORM-6. `updateTask`, the Edit Task screen's
/// save.
///
/// D-M4-5: one call that applies every field the form offers, so that the name
/// check, the INV-2 check and the `updatedAt` bump cannot be forgotten.
library;

import 'package:test/test.dart';
import 'package:zen_domain/zen_domain.dart';

import '../support/fixtures.dart';

void main() {
  final DateTime later = at(60);

  group('updateTask', () {
    test('§3.3: every edit moves updatedAt and leaves createdAt alone', () {
      final Task before = aTask(named: 'Write report');
      final Task after = updateTask(
        before,
        now: later,
        name: name('Write the report'),
      ).unwrap();

      expect(after.name.value, 'Write the report');
      expect(after.createdAt, before.createdAt);
      expect(after.updatedAt, later);
      expect(after.id, before.id);
    });

    test('NAME-8: a name held by another active task is refused', () {
      final Result<Task, RuleViolation> result = updateTask(
        aTask(named: 'Write report'),
        now: later,
        name: name('Buy milk'),
        activeTaskNormalizedNames: <String>{'buy milk'},
      );

      expect(result.errorOrNull, const TaskNameCollision());
    });

    test(
      'NAME-8: renaming an item to its own current name is not a collision',
      () {
        final Task before = aTask(named: 'Write report');
        final Result<Task, RuleViolation> result = updateTask(
          before,
          now: later,
          name: before.name,
          activeTaskNormalizedNames: <String>{before.name.normalized},
        );

        expect(result.isOk, isTrue);
      },
    );

    test('§2: the collision check uses the normalized name', () {
      final Result<Task, RuleViolation> result = updateTask(
        aTask(named: 'Write report'),
        now: later,
        name: name('buy  MILK'),
        activeTaskNormalizedNames: <String>{'buy milk'},
      );

      expect(result.errorOrNull, const TaskNameCollision());
    });

    test('TASKFORM-6: Done with an incomplete subtask is refused', () {
      final Result<Task, RuleViolation> result = updateTask(
        aTask(named: 'Write report'),
        now: later,
        status: TaskStatus.done,
        subtasks: <Subtask>[aSubtask(named: 'Proofread')],
      );

      expect(result.errorOrNull, const IncompleteSubtasks());
    });

    test(
      "TASKFORM-6: the check runs against the form's subtasks, not the stored "
      'ones',
      () {
        // The Task is already Done with one Done subtask. The form adds a
        // second, still Todo, and leaves the status control alone. TASKFORM-5
        // should make that unreachable through the UI; the check exists so that
        // no path can persist a violation of INV-2 anyway.
        final Task done = aTask(
          named: 'Ship it',
          status: TaskStatus.done,
          subtasks: <Subtask>[aSubtask(named: 'Test', status: TaskStatus.done)],
        );
        final Result<Task, RuleViolation> result = updateTask(
          done,
          now: later,
          subtasks: <Subtask>[
            aSubtask(named: 'Test', status: TaskStatus.done),
            aSubtask(id: 'sub-2', named: 'Docs'),
          ],
        );

        expect(result.errorOrNull, const IncompleteSubtasks());
      },
    );

    test('INV-1: becoming Done sets completedAt to now', () {
      final Task after = updateTask(
        aTask(named: 'Write report'),
        now: later,
        status: TaskStatus.done,
      ).unwrap();

      expect(after.status, TaskStatus.done);
      expect(after.completedAt, later);
    });

    test('INV-1: leaving Done clears completedAt', () {
      final Task done = aTask(
        named: 'Ship it',
        status: TaskStatus.done,
        completedAt: at(10),
      );
      final Task after = updateTask(
        done,
        now: later,
        status: TaskStatus.todo,
      ).unwrap();

      expect(after.status, TaskStatus.todo);
      expect(after.completedAt, isNull);
    });

    test(
      'INV-1: a status that did not change keeps the instant it was completed '
      'at',
      () {
        final Task done = aTask(
          named: 'Ship it',
          status: TaskStatus.done,
          completedAt: at(10),
        );
        final Task after = updateTask(
          done,
          now: later,
          name: name('Ship it now'),
        ).unwrap();

        expect(after.status, TaskStatus.done);
        // EOD-2 derives the archive boundary from `completedAt`, so an edit
        // that is not a completion must not move it.
        expect(after.completedAt, at(10));
      },
    );

    test('INV-2: changing status and subtasks together builds no invalid '
        'intermediate', () {
      // Done with one Done subtask becomes Todo with an added Todo one, in
      // one call. Either ordering of two `copyWith`es would violate INV-2 in
      // between, and `Task`'s constructor asserts; this is why the rule
      // constructs the result in a single step.
      final Task done = aTask(
        named: 'Ship it',
        status: TaskStatus.done,
        subtasks: <Subtask>[aSubtask(named: 'Test', status: TaskStatus.done)],
      );
      final Task after = updateTask(
        done,
        now: later,
        status: TaskStatus.todo,
        subtasks: <Subtask>[
          aSubtask(named: 'Test', status: TaskStatus.done),
          aSubtask(id: 'sub-2', named: 'Docs'),
        ],
      ).unwrap();

      expect(after.status, TaskStatus.todo);
      expect(after.completedAt, isNull);
      expect(after.subtasks.length, 2);
      expect(after.invariantFailures, isEmpty);
    });

    test('TAG-4: tags are deduplicated case-insensitively', () {
      final Task after = updateTask(
        aTask(named: 'Write report'),
        now: later,
        tags: <Tag>[tag('Work'), tag('work'), tag('home')],
      ).unwrap();

      expect(after.tags.map((Tag t) => t.value).toList(), <String>[
        'Work',
        'home',
      ]);
    });

    test('an omitted field is left exactly as it was', () {
      final Task before = aTask(
        named: 'Write report',
        tags: <Tag>[tag('work')],
        subtasks: <Subtask>[aSubtask(named: 'Draft')],
      );
      final Task after = updateTask(before, now: later).unwrap();

      expect(after.name, before.name);
      expect(after.tags, before.tags);
      expect(after.description, before.description);
      expect(after.status, before.status);
      expect(after.subtasks, before.subtasks);
    });

    test('INV-8: the source-idea pair survives an edit', () {
      final Task converted = aTask(
        named: 'Learn Rust',
        sourceIdeaId: 'idea-1',
        sourceIdeaCreatedAt: at(1),
      );
      final Task after = updateTask(
        converted,
        now: later,
        name: name('Learn Rust properly'),
      ).unwrap();

      expect(after.sourceIdeaId, 'idea-1');
      expect(after.sourceIdeaCreatedAt, at(1));
      expect(after.invariantFailures, isEmpty);
    });

    test('STATUS-4: an archived task cannot be edited', () {
      final Task archived = aTask(
        named: 'Water the plants',
        status: TaskStatus.done,
        completedAt: at(10),
        isArchived: true,
        archivedAt: at(20),
      );

      expect(
        updateTask(archived, now: later, name: name('Water them')).errorOrNull,
        const ArchivedTaskImmutable(),
      );
    });

    test('DEL-1: a deleted task cannot be edited', () {
      final Task deleted = aTask(
        named: 'Write report',
        isDeleted: true,
        deletedAt: at(20),
      );

      expect(
        updateTask(deleted, now: later, name: name('Renamed')).errorOrNull,
        const DeletedTaskImmutable(),
      );
    });
  });
}

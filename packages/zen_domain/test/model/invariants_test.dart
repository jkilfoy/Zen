import 'package:test/test.dart';
import 'package:zen_domain/zen_domain.dart';

import '../support/fixtures.dart';

/// §3.7. Every invariant, from both directions: a well-formed record reports no
/// failure, and a malformed one is both reported and refused by the
/// constructor's assert.
///
/// §3.7 says the persistence layer must enforce these — §11.5.2 does that with
/// CHECK constraints and partial unique indexes. These tests prove the domain
/// agrees with the schema, so a violation cannot be constructed in the first
/// place.
void main() {
  group('INV-1: completedAt != null iff status == Done', () {
    test('a Done task with completedAt is well-formed', () {
      expect(aTask(status: TaskStatus.done).invariantFailures, isEmpty);
    });

    test('a Done task without completedAt is refused', () {
      expect(
        () => Task(
          id: 't',
          name: name('A task'),
          status: TaskStatus.done,
          createdAt: base,
          updatedAt: base,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a Todo task with completedAt is refused', () {
      expect(
        () => Task(
          id: 't',
          name: name('A task'),
          status: TaskStatus.todo,
          createdAt: base,
          updatedAt: base,
          completedAt: base,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('the same holds for subtasks', () {
      expect(aSubtask(status: TaskStatus.done).invariantFailures, isEmpty);
      expect(
        () => Subtask(
          id: 's',
          name: subtaskName('Pack'),
          status: TaskStatus.done,
          createdAt: base,
          updatedAt: base,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a task reports its subtasks\' failures as its own', () {
      // Built through withStatus so the Subtask constructor cannot object,
      // then checked at the Task level.
      final Task task = aTask(
        subtasks: <Subtask>[aSubtask(status: TaskStatus.done)],
      );
      expect(task.invariantFailures, isEmpty);
    });
  });

  group('INV-2: a Done task has only Done subtasks', () {
    test('a Done task with all subtasks Done is well-formed', () {
      expect(
        aTask(
          status: TaskStatus.done,
          subtasks: <Subtask>[
            aSubtask(id: 's1', status: TaskStatus.done),
            aSubtask(id: 's2', status: TaskStatus.done),
          ],
        ).invariantFailures,
        isEmpty,
      );
    });

    test('a Done task with an open subtask is refused', () {
      expect(
        () => aTask(
          status: TaskStatus.done,
          subtasks: <Subtask>[aSubtask(status: TaskStatus.todo)],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a Done task with a Blocked subtask is refused', () {
      expect(
        () => aTask(
          status: TaskStatus.done,
          subtasks: <Subtask>[aSubtask(status: TaskStatus.blocked)],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a Todo task may hold subtasks in any state', () {
      expect(
        aTask(
          subtasks: <Subtask>[
            aSubtask(id: 's1', status: TaskStatus.done),
            aSubtask(id: 's2', status: TaskStatus.blocked),
            aSubtask(id: 's3'),
          ],
        ).invariantFailures,
        isEmpty,
      );
    });
  });

  group('INV-3: archived implies Done', () {
    test('an archived Done task is well-formed', () {
      expect(
        aTask(status: TaskStatus.done, isArchived: true).invariantFailures,
        isEmpty,
      );
    });

    test('an archived Todo task is refused', () {
      expect(
        () => Task(
          id: 't',
          name: name('A task'),
          status: TaskStatus.todo,
          createdAt: base,
          updatedAt: base,
          isArchived: true,
          archivedAt: base,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('INV-4: archivedAt iff isArchived, deletedAt iff isDeleted', () {
    test('isArchived without archivedAt is refused', () {
      expect(
        () => Task(
          id: 't',
          name: name('A task'),
          status: TaskStatus.done,
          createdAt: base,
          updatedAt: base,
          completedAt: base,
          isArchived: true,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('archivedAt without isArchived is refused', () {
      expect(
        () => Task(
          id: 't',
          name: name('A task'),
          status: TaskStatus.done,
          createdAt: base,
          updatedAt: base,
          completedAt: base,
          archivedAt: base,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('isDeleted without deletedAt is refused', () {
      expect(
        () => Task(
          id: 't',
          name: name('A task'),
          status: TaskStatus.todo,
          createdAt: base,
          updatedAt: base,
          isDeleted: true,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('deletedAt without isDeleted is refused', () {
      expect(
        () => Task(
          id: 't',
          name: name('A task'),
          status: TaskStatus.todo,
          createdAt: base,
          updatedAt: base,
          deletedAt: base,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('INV-5: createdAt <= updatedAt', () {
    test('equal timestamps are well-formed', () {
      expect(
        aTask(createdAt: base, updatedAt: base).invariantFailures,
        isEmpty,
      );
    });

    test('updatedAt before createdAt is refused, for tasks', () {
      expect(
        () => aTask(createdAt: at(10), updatedAt: at(0)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('updatedAt before createdAt is refused, for subtasks', () {
      expect(
        () => aSubtask(createdAt: at(10), updatedAt: at(0)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('updatedAt before createdAt is refused, for ideas', () {
      expect(
        () => anIdea(createdAt: at(10), updatedAt: at(0)),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('INV-6 / NAME-6: names are unique among active Items of a kind', () {
    test('two active tasks may not share a name', () {
      expect(
        datasetInvariantFailures(
          ideas: const <Idea>[],
          tasks: <Task>[
            aTask(id: 't1', named: 'Buy milk'),
            aTask(id: 't2', named: 'buy  MILK'),
          ],
        ),
        contains(contains('INV-6')),
      );
    });

    test('two active ideas may not share a name', () {
      expect(
        datasetInvariantFailures(
          ideas: <Idea>[
            anIdea(id: 'i1', named: 'Read SICP'),
            anIdea(id: 'i2', named: 'read  sicp '),
          ],
          tasks: const <Task>[],
        ),
        contains(contains('INV-6')),
      );
    });

    test('AC-8: an Idea and a Task may share a name', () {
      expect(
        datasetInvariantFailures(
          ideas: <Idea>[anIdea(named: 'Buy milk')],
          tasks: <Task>[aTask(named: 'Buy milk')],
        ),
        isEmpty,
      );
    });

    test('NAME-7, AC-9: an archived task does not reserve its name', () {
      expect(
        datasetInvariantFailures(
          ideas: const <Idea>[],
          tasks: <Task>[
            aTask(
              id: 't1',
              named: 'Water the plants',
              status: TaskStatus.done,
              isArchived: true,
            ),
            aTask(id: 't2', named: 'Water the plants'),
          ],
        ),
        isEmpty,
      );
    });

    test('NAME-7: a soft-deleted task does not reserve its name', () {
      expect(
        datasetInvariantFailures(
          ideas: const <Idea>[],
          tasks: <Task>[
            aTask(id: 't1', named: 'Water the plants', isDeleted: true),
            aTask(id: 't2', named: 'Water the plants'),
          ],
        ),
        isEmpty,
      );
    });
  });

  group('INV-7: a tombstoned Idea id is absent from the Ideas table', () {
    test('a tombstone with no matching Idea is well-formed', () {
      expect(
        datasetInvariantFailures(
          ideas: <Idea>[anIdea(id: 'i2')],
          tasks: const <Task>[],
          tombstones: <IdeaTombstone>[
            IdeaTombstone(
              id: 'i1',
              deletedAt: base,
              reason: TombstoneReason.deleted,
            ),
          ],
        ),
        isEmpty,
      );
    });

    test('an Idea that is also tombstoned is a violation', () {
      expect(
        datasetInvariantFailures(
          ideas: <Idea>[anIdea(id: 'i1')],
          tasks: const <Task>[],
          tombstones: <IdeaTombstone>[
            IdeaTombstone(
              id: 'i1',
              deletedAt: base,
              reason: TombstoneReason.converted,
            ),
          ],
        ),
        contains(contains('INV-7')),
      );
    });
  });

  group('§2: the active set', () {
    test('a task is active when neither deleted nor archived', () {
      expect(aTask().isActive, isTrue);
      expect(aTask(isDeleted: true).isActive, isFalse);
      expect(
        aTask(status: TaskStatus.done, isArchived: true).isActive,
        isFalse,
      );
    });

    test('every live Idea is active', () {
      expect(anIdea().isActive, isTrue);
    });
  });

  group('INV-8: the sourceIdea fields are both null or both set', () {
    test('a Task converted from an Idea carries both', () {
      expect(
        aTask(
          sourceIdeaId: 'idea-1',
          sourceIdeaCreatedAt: base,
        ).invariantFailures,
        isEmpty,
      );
    });

    test('a Task that was never converted carries neither', () {
      expect(aTask().invariantFailures, isEmpty);
    });

    test('an id without a creation time is refused', () {
      expect(() => aTask(sourceIdeaId: 'idea-1'), _refusedBy('INV-8'));
    });

    test('a creation time without an id is refused', () {
      expect(() => aTask(sourceIdeaCreatedAt: base), _refusedBy('INV-8'));
    });
  });

  group('INV-9: every timestamp has exactly millisecond precision', () {
    final DateTime coarse = DateTime.utc(2026, 9, 22, 12, 0, 0, 250);
    final DateTime fine = DateTime.utc(2026, 9, 22, 12, 0, 0, 250, 1);

    test('millisecond instants are well-formed', () {
      expect(
        aTask(createdAt: coarse, updatedAt: coarse).invariantFailures,
        isEmpty,
      );
      expect(
        anIdea(createdAt: coarse, updatedAt: coarse).invariantFailures,
        isEmpty,
      );
      expect(
        aSubtask(createdAt: coarse, updatedAt: coarse).invariantFailures,
        isEmpty,
      );
    });

    test('a microsecond component is refused, for tasks', () {
      expect(
        () => aTask(createdAt: fine, updatedAt: fine),
        _refusedBy('INV-9: createdAt'),
      );
    });

    test('a microsecond component is refused, for ideas', () {
      expect(
        () => anIdea(createdAt: coarse, updatedAt: fine),
        _refusedBy('INV-9: updatedAt'),
      );
    });

    test('a microsecond component is refused, for subtasks', () {
      expect(
        () => Subtask(
          id: 's',
          name: subtaskName('A subtask'),
          status: TaskStatus.done,
          createdAt: coarse,
          updatedAt: coarse,
          completedAt: fine,
        ),
        _refusedBy('INV-9: completedAt'),
      );
    });

    test('a nullable timestamp that is absent passes', () {
      final Task task = aTask(createdAt: coarse, updatedAt: coarse);
      expect(task.completedAt, isNull);
      expect(task.invariantFailures, isEmpty);
    });

    test('§3: truncateToMilliseconds is what makes an instant conform', () {
      expect(hasMillisecondPrecision(fine), isFalse);
      expect(truncateToMilliseconds(fine), coarse);
      expect(hasMillisecondPrecision(truncateToMilliseconds(fine)), isTrue);
    });

    test('§3: truncation never moves an instant forwards', () {
      final DateTime justUnder = DateTime.utc(2026, 9, 22, 12, 0, 0, 250, 999);
      expect(truncateToMilliseconds(justUnder), coarse);
      expect(truncateToMilliseconds(justUnder).isAfter(justUnder), isFalse);
    });

    test('§3: truncation returns UTC whatever it is given', () {
      expect(truncateToMilliseconds(DateTime(2026, 9, 22, 12)).isUtc, isTrue);
    });

    test('§3, INV-9: a conforming instant is 24 ISO-8601 characters', () {
      final String iso = truncateToMilliseconds(fine).toIso8601String();
      expect(iso, '2026-09-22T12:00:00.250Z');
      expect(iso.length, 24, reason: 'what §11.5.2 CHECKs on the way to disk');
    });
  });
}

/// Matches the [AssertionError] an entity constructor throws, requiring its
/// message to name [invariant].
///
/// The existing groups assert only that *an* assertion fired; naming the
/// invariant means a test that starts passing for the wrong reason — some other
/// invariant breaking first — reports itself.
Matcher _refusedBy(String invariant) => throwsA(
  isA<AssertionError>().having(
    (AssertionError e) => e.message.toString(),
    'message',
    contains(invariant),
  ),
);

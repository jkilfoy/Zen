/// §10, AC-13 through AC-19. The merge acceptance scenarios, as pure domain
/// tests (§11.13's M2 row).
library;

import 'package:test/test.dart';
import 'package:zen_domain/zen_domain.dart';

import '../support/fixtures.dart';

void main() {
  const NameUnionMergeStrategy merge = NameUnionMergeStrategy();

  test('AC-13: two Ideas with the same name merge into one', () {
    final Idea onA = anIdea(
      id: '0190-a',
      named: 'Read SICP',
      tags: <Tag>[tag('cs')],
      contextText: context('short'),
      timeframe: Timeframe.later,
    );
    final Idea onB = anIdea(
      id: '0190-b',
      named: 'read  sicp ',
      tags: <Tag>[tag('books'), tag('CS')],
      contextText: context('a longer context'),
      timeframe: Timeframe.soon,
    );

    final MergeResult result = merge.merge(<ReplicaSnapshot>[
      aSnapshot(replicaId: 'A', ideas: <Idea>[onA]),
      aSnapshot(replicaId: 'B', ideas: <Idea>[onB]),
    ]);

    expect(result.ideas, hasLength(1));
    final Idea merged = result.ideas.single;
    expect(merged.id, '0190-a');
    expect(merged.name.value, 'Read SICP');
    // Union, de-duplicated case-insensitively, primary record's tags first.
    expect(merged.tags.map((Tag t) => t.value), <String>['cs', 'books']);
    expect(merged.timeframe, Timeframe.soon, reason: 'most urgent wins');
    expect(merged.context.value, 'a longer context', reason: 'longest wins');
  });

  test('AC-14: merging Tasks unions their subtasks', () {
    final Task onA = aTask(
      id: 'task-a',
      named: 'Move',
      subtasks: <Subtask>[
        aSubtask(id: 'a-1', named: 'Pack', status: TaskStatus.done),
        aSubtask(id: 'a-2', named: 'Clean'),
      ],
    );
    final Task onB = aTask(
      id: 'task-b',
      named: 'Move',
      subtasks: <Subtask>[
        aSubtask(id: 'b-1', named: 'Pack'),
        aSubtask(id: 'b-2', named: 'Clean', status: TaskStatus.blocked),
        aSubtask(id: 'b-3', named: 'Keys'),
      ],
    );

    final MergeResult result = merge.merge(<ReplicaSnapshot>[
      aSnapshot(replicaId: 'A', tasks: <Task>[onA]),
      aSnapshot(replicaId: 'B', tasks: <Task>[onB]),
    ]);

    expect(result.tasks, hasLength(1));
    final Task merged = result.tasks.single;
    expect(merged.status, TaskStatus.todo);
    expect(
      merged.subtasks.map((Subtask s) => '${s.name.value}:${s.status.name}'),
      <String>['Pack:done', 'Clean:blocked', 'Keys:todo'],
    );
  });

  test('AC-15: duplicate subtask names match by position within the name', () {
    final Task onA = aTask(
      id: 'task-a',
      named: 'Gym',
      subtasks: <Subtask>[
        aSubtask(id: 'a-1', named: 'Set', status: TaskStatus.done),
        aSubtask(id: 'a-2', named: 'Set'),
      ],
    );
    final Task onB = aTask(
      id: 'task-b',
      named: 'Gym',
      subtasks: <Subtask>[
        aSubtask(id: 'b-1', named: 'Set'),
        aSubtask(id: 'b-2', named: 'Set', status: TaskStatus.done),
        aSubtask(id: 'b-3', named: 'Set'),
      ],
    );

    final MergeResult result = merge.merge(<ReplicaSnapshot>[
      aSnapshot(replicaId: 'A', tasks: <Task>[onA]),
      aSnapshot(replicaId: 'B', tasks: <Task>[onB]),
    ]);

    expect(
      result.tasks.single.subtasks.map((Subtask s) => s.status),
      <TaskStatus>[TaskStatus.done, TaskStatus.done, TaskStatus.todo],
    );
  });

  test('AC-16: a Done Task with a new open subtask is repaired to Todo', () {
    final Task onA = aTask(
      id: 'task-a',
      named: 'Ship',
      status: TaskStatus.done,
      subtasks: <Subtask>[
        aSubtask(id: 'a-1', named: 'Test', status: TaskStatus.done),
      ],
    );
    final Task onB = aTask(
      id: 'task-b',
      named: 'Ship',
      subtasks: <Subtask>[
        aSubtask(id: 'b-1', named: 'Test', status: TaskStatus.done),
        aSubtask(id: 'b-2', named: 'Docs'),
      ],
    );

    final MergeResult result = merge.merge(<ReplicaSnapshot>[
      aSnapshot(replicaId: 'A', tasks: <Task>[onA]),
      aSnapshot(replicaId: 'B', tasks: <Task>[onB]),
    ]);

    final Task merged = result.tasks.single;
    expect(merged.status, TaskStatus.todo);
    expect(merged.completedAt, isNull);
    expect(merged.subtasks, hasLength(2));
    expect(result.report.repairs, <MergeRepair>[
      const MergeRepair(
        kind: MergeRepairKind.reopenedForIncompleteSubtasks,
        itemId: 'task-a',
      ),
    ], reason: 'STATUS-3: the repair is never silent');
  });

  test('AC-17: a tombstoned Idea is not resurrected by a peer', () {
    final Idea onB = anIdea(id: 'idea-x', named: 'Call bank');

    final MergeResult result = merge.merge(<ReplicaSnapshot>[
      aSnapshot(
        replicaId: 'A',
        tombstones: <IdeaTombstone>[aTombstone(id: 'idea-x')],
      ),
      aSnapshot(replicaId: 'B', ideas: <Idea>[onB]),
    ]);

    expect(result.ideas, isEmpty);
    expect(result.tombstones.map((IdeaTombstone t) => t.id), <String>[
      'idea-x',
    ]);
  });

  test('AC-18: a name reused after a deletion survives the merge', () {
    // Tombstones carry no name (DEL-3), so the new Idea's fresh id saves it.
    final Idea recreated = anIdea(id: 'idea-y', named: 'Call bank');
    final Idea stale = anIdea(id: 'idea-x', named: 'Call bank');

    final MergeResult result = merge.merge(<ReplicaSnapshot>[
      aSnapshot(
        replicaId: 'A',
        ideas: <Idea>[recreated],
        tombstones: <IdeaTombstone>[aTombstone(id: 'idea-x')],
      ),
      aSnapshot(replicaId: 'B', ideas: <Idea>[stale]),
    ]);

    expect(result.ideas, hasLength(1));
    expect(result.ideas.single.id, 'idea-y');
    expect(result.ideas.single.name.value, 'Call bank');
  });

  group('AC-19: the merge is order-independent (MERGE-2)', () {
    /// A pair of snapshots exercising every field rule at once: an Idea that
    /// conflicts by name, a Task that conflicts by id and needs the INV-2
    /// repair, a tombstone, and a Task present on one replica only.
    (ReplicaSnapshot, ReplicaSnapshot) pair() {
      final ReplicaSnapshot a = aSnapshot(
        replicaId: 'A',
        ideas: <Idea>[
          anIdea(
            id: 'idea-a',
            named: 'Read SICP',
            tags: <Tag>[tag('cs')],
            contextText: context('short'),
            timeframe: Timeframe.later,
            updatedAt: at(10),
          ),
        ],
        tasks: <Task>[
          aTask(
            id: 'task-1',
            named: 'Ship it',
            status: TaskStatus.done,
            subtasks: <Subtask>[
              aSubtask(id: 's-1', named: 'Test', status: TaskStatus.done),
            ],
            updatedAt: at(20),
          ),
          aTask(id: 'task-only-a', named: 'Solo task'),
        ],
        tombstones: <IdeaTombstone>[aTombstone(id: 'idea-gone')],
      );
      final ReplicaSnapshot b = aSnapshot(
        replicaId: 'B',
        ideas: <Idea>[
          anIdea(
            id: 'idea-b',
            named: 'read  sicp',
            tags: <Tag>[tag('books'), tag('CS')],
            contextText: context('a longer context'),
            timeframe: Timeframe.soon,
            updatedAt: at(30),
          ),
          anIdea(id: 'idea-gone', named: 'Already deleted'),
        ],
        tasks: <Task>[
          aTask(
            id: 'task-1',
            named: 'Ship it now',
            subtasks: <Subtask>[
              aSubtask(id: 's-1', named: 'Test', status: TaskStatus.done),
              aSubtask(id: 's-2', named: 'Docs'),
            ],
            updatedAt: at(40),
          ),
        ],
      );
      return (a, b);
    }

    test('field for field, including subtask order and the report', () {
      final (ReplicaSnapshot a, ReplicaSnapshot b) = pair();

      final MergeResult forwards = merge.merge(<ReplicaSnapshot>[a, b]);
      final MergeResult backwards = merge.merge(<ReplicaSnapshot>[b, a]);

      expect(forwards, backwards);
      expect(forwards.report, backwards.report);
    });

    test('and the result is a fixed point (§11.12 idempotence)', () {
      final (ReplicaSnapshot a, ReplicaSnapshot b) = pair();
      final MergeResult once = merge.merge(<ReplicaSnapshot>[a, b]);

      final MergeResult twice = merge.merge(<ReplicaSnapshot>[
        once.asSnapshot('merged'),
      ]);

      expect(twice.ideas, once.ideas);
      expect(twice.tasks, once.tasks);
      expect(twice.tombstones, once.tombstones);
      expect(
        twice.report.isEmpty,
        isTrue,
        reason: 'a merged dataset holds no conflicts left to resolve',
      );
    });
  });
}

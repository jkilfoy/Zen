/// §9.3, "Record order". The comparator every tie-break in the merge rests on.
///
/// §9.3 needs a deterministic order over records *including records that share
/// an `id`*, which is why "sorted by `id`" was not enough. These tests pin the
/// comparison sequence and the one property that makes the whole thing
/// defensible: a tie means the records are interchangeable.
library;

import 'package:test/test.dart';
import 'package:zen_domain/zen_domain.dart';

import '../support/fixtures.dart';
import '../support/snapshot_generators.dart';

void main() {
  group('§9.3: the comparison sequence for Ideas', () {
    test('id comes first', () {
      expect(
        compareIdeaRecords(
          anIdea(id: 'a', updatedAt: at(99)),
          anIdea(id: 'b', updatedAt: at(1)),
        ),
        isNegative,
      );
    });

    test('then updatedAt', () {
      expect(
        compareIdeaRecords(
          anIdea(id: 'a', named: 'Zulu', updatedAt: at(1)),
          anIdea(id: 'a', named: 'Alpha', updatedAt: at(2)),
        ),
        isNegative,
      );
    });

    test('then the normalized name, then the raw name', () {
      expect(
        compareIdeaRecords(
          anIdea(id: 'a', named: 'Alpha'),
          anIdea(id: 'a', named: 'Bravo'),
        ),
        isNegative,
      );
      // Same normalized name, different case: the raw name breaks the tie, so
      // two spellings of one name never compare equal.
      expect(
        compareIdeaRecords(
          anIdea(id: 'a', named: 'ALPHA'),
          anIdea(id: 'a', named: 'alpha'),
        ),
        isNot(0),
      );
    });

    test('then createdAt, then the §3.2 fields in declaration order', () {
      expect(
        compareIdeaRecords(
          anIdea(id: 'a', createdAt: at(1), updatedAt: at(9)),
          anIdea(id: 'a', createdAt: at(2), updatedAt: at(9)),
        ),
        isNegative,
      );
      expect(
        compareIdeaRecords(
          anIdea(id: 'a', timeframe: Timeframe.now),
          anIdea(id: 'a', timeframe: Timeframe.soon),
        ),
        isNegative,
        reason: 'timeframe is the last §3.2 field',
      );
    });
  });

  group('§9.3: the comparison sequence for Tasks', () {
    test('id, then updatedAt, then the name', () {
      expect(
        compareTaskRecords(
          aTask(id: 'a', updatedAt: at(9)),
          aTask(id: 'b', updatedAt: at(1)),
        ),
        isNegative,
      );
      expect(
        compareTaskRecords(
          aTask(id: 'a', named: 'Zulu task', updatedAt: at(1)),
          aTask(id: 'a', named: 'Alpha task', updatedAt: at(2)),
        ),
        isNegative,
      );
    });

    test('the subtask list comes last, by length then element-wise', () {
      expect(
        compareTaskRecords(
          aTask(
            id: 'a',
            subtasks: <Subtask>[aSubtask(id: 's1')],
          ),
          aTask(
            id: 'a',
            subtasks: <Subtask>[
              aSubtask(id: 's1'),
              aSubtask(id: 's2'),
            ],
          ),
        ),
        isNegative,
      );
      expect(
        compareTaskRecords(
          aTask(
            id: 'a',
            subtasks: <Subtask>[aSubtask(id: 's1')],
          ),
          aTask(
            id: 'a',
            subtasks: <Subtask>[aSubtask(id: 's2')],
          ),
        ),
        isNegative,
      );
    });
  });

  group('§9.3: a total order up to field-for-field equality', () {
    test('an Idea tie means the two are equal in every field', () {
      // For Ideas the comparator covers every §3.2 field, so the claim is an
      // equivalence and can be checked directly.
      for (int seed = 0; seed < 200; seed++) {
        final List<ReplicaSnapshot> inputs = SnapshotGenerator(seed)
            .replicas(count: 2);
        final List<Idea> ideas = <Idea>[
          for (final ReplicaSnapshot input in inputs) ...input.ideas,
        ];

        for (final Idea a in ideas) {
          for (final Idea b in ideas) {
            expect(
              compareIdeaRecords(a, b) == 0,
              a == b,
              reason: 'seed $seed: $a vs $b',
            );
          }
        }
      }
    });

    test('a Task tie means the two are interchangeable to the merge', () {
      // §9.3 names four subtask fields for the element-wise comparison, so two
      // Tasks can tie while differing in a subtask's `createdAt` or
      // `completedAt`. That cannot change the output: step 5(d) resolves both
      // by earliest over the whole group, and the group holds both records
      // whichever one is called the primary. Demonstrated rather than argued.
      final Task early = aTask(
        id: 't',
        named: 'Same task',
        subtasks: <Subtask>[
          aSubtask(id: 's1', createdAt: at(1), updatedAt: at(9)),
        ],
      );
      final Task late = aTask(
        id: 't',
        named: 'Same task',
        subtasks: <Subtask>[
          aSubtask(id: 's1', createdAt: at(5), updatedAt: at(9)),
        ],
      );

      expect(compareTaskRecords(early, late), 0);
      expect(early, isNot(late), reason: 'they are not equal records');

      const NameUnionMergeStrategy merge = NameUnionMergeStrategy();
      expect(
        merge.merge(<ReplicaSnapshot>[
          aSnapshot(tasks: <Task>[early]),
          aSnapshot(tasks: <Task>[late]),
        ]),
        merge.merge(<ReplicaSnapshot>[
          aSnapshot(tasks: <Task>[late]),
          aSnapshot(tasks: <Task>[early]),
        ]),
      );
    });

    test('sorting by record order is stable against input order', () {
      for (int seed = 0; seed < 200; seed++) {
        final List<Idea> ideas = <Idea>[
          for (final ReplicaSnapshot input in SnapshotGenerator(
            seed,
          ).replicas(count: 2))
            ...input.ideas,
        ];

        final List<Idea> forwards = ideas.toList()..sort(compareIdeaRecords);
        final List<Idea> backwards = ideas.reversed.toList()
          ..sort(compareIdeaRecords);

        expect(forwards, backwards, reason: 'seed $seed');
      }
    });
  });
}

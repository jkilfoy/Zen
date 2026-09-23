/// §9.3. One test per rule of `NameUnionMergeStrategy`, numbered as §9.3
/// numbers its steps.
library;

import 'package:test/test.dart';
import 'package:zen_domain/zen_domain.dart';

import '../support/fixtures.dart';

const NameUnionMergeStrategy merge = NameUnionMergeStrategy();

/// Merges [snapshots] and returns the result. Named for readability at the
/// call sites, which are all two or three lines.
MergeResult mergeOf(List<ReplicaSnapshot> snapshots) => merge.merge(snapshots);

void main() {
  group('§9.3 step 1: tombstones first', () {
    test('tombstones reduce to one per Idea id', () {
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          tombstones: <IdeaTombstone>[aTombstone(id: 'x', deletedAt: at(10))],
        ),
        aSnapshot(
          tombstones: <IdeaTombstone>[
            aTombstone(
              id: 'x',
              deletedAt: at(20),
              reason: TombstoneReason.converted,
            ),
          ],
        ),
      ]);

      expect(result.tombstones, hasLength(1));
      expect(
        result.tombstones.single.deletedAt,
        at(10),
        reason: 'earliest deletedAt wins',
      );
    });

    test('on an equal deletedAt, converted beats deleted', () {
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          tombstones: <IdeaTombstone>[aTombstone(id: 'x', deletedAt: at(10))],
        ),
        aSnapshot(
          tombstones: <IdeaTombstone>[
            aTombstone(
              id: 'x',
              deletedAt: at(10),
              reason: TombstoneReason.converted,
            ),
          ],
        ),
      ]);

      expect(result.tombstones.single.reason, TombstoneReason.converted);
    });

    test('INV-7: a tombstoned Idea is dropped before grouping', () {
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          ideas: <Idea>[anIdea(id: 'x', named: 'Gone')],
          tombstones: <IdeaTombstone>[aTombstone(id: 'x')],
        ),
      ]);

      expect(result.ideas, isEmpty);
    });
  });

  group('§9.2 MERGE-5, MERGE-6: what conflicts', () {
    test('MERGE-6: an archived Task does not match an active one by name', () {
      // NAME-7: archiving frees the name, so last week's "Water the plants"
      // and today's are different Items (AC-9).
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          tasks: <Task>[
            aTask(
              id: 'old',
              named: 'Water the plants',
              status: TaskStatus.done,
              isArchived: true,
            ),
            aTask(id: 'new', named: 'Water the plants'),
          ],
        ),
      ]);

      expect(result.tasks, hasLength(2));
    });

    test('MERGE-6: a soft-deleted Task conflicts by id only', () {
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          tasks: <Task>[
            aTask(id: 'gone', named: 'Buy milk', isDeleted: true),
            aTask(id: 'live', named: 'Buy milk'),
          ],
        ),
      ]);

      expect(result.tasks, hasLength(2));
    });

    test('MERGE-5: conflict is transitive across id and name', () {
      // `archived` joins `live` by id; `live` joins `other` by name.
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          tasks: <Task>[
            aTask(
              id: 'a',
              named: 'Old name',
              status: TaskStatus.done,
              isArchived: true,
            ),
          ],
        ),
        aSnapshot(
          tasks: <Task>[aTask(id: 'a', named: 'Shared name')],
        ),
        aSnapshot(
          tasks: <Task>[aTask(id: 'b', named: 'shared  NAME')],
        ),
      ]);

      expect(result.tasks, hasLength(1));
      expect(result.report.components.single.inputIds, <String>['a', 'b']);
    });

    test('an Idea and a Task never conflict (NAME-6)', () {
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          ideas: <Idea>[anIdea(id: 'same-id', named: 'Buy milk')],
          tasks: <Task>[aTask(id: 'same-id', named: 'Buy milk')],
        ),
      ]);

      expect(result.ideas, hasLength(1));
      expect(result.tasks, hasLength(1));
      expect(result.report.isEmpty, isTrue);
    });
  });

  group('§9.3 step 4: the primary record', () {
    test('the latest updatedAt wins, so a rename survives the merge', () {
      // The specification's own example: renamed on the phone, stale on the
      // desktop. Without this rule the merge would undo the rename, and being
      // deterministic it would undo it again after every future sync.
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          ideas: <Idea>[
            anIdea(id: 'i', named: 'groceries list', updatedAt: at(10)),
          ],
        ),
        aSnapshot(
          ideas: <Idea>[anIdea(id: 'i', named: 'Groceries', updatedAt: at(20))],
        ),
      ]);

      expect(result.ideas.single.name.value, 'Groceries');
    });

    test('on an equal updatedAt, the normalized name sorting first wins', () {
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          ideas: <Idea>[anIdea(id: 'i', named: 'Beta', updatedAt: at(10))],
        ),
        aSnapshot(
          ideas: <Idea>[anIdea(id: 'i', named: 'Alpha', updatedAt: at(10))],
        ),
      ]);

      expect(result.ideas.single.name.value, 'Alpha');
    });

    test('the id is the smallest in the component, and always a real one', () {
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          ideas: <Idea>[anIdea(id: 'zzz', named: 'Same name')],
        ),
        aSnapshot(
          ideas: <Idea>[anIdea(id: 'aaa', named: 'Same name')],
        ),
      ]);

      expect(result.ideas.single.id, 'aaa');
    });

    test('tags union case-insensitively, the primary record first', () {
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          ideas: <Idea>[
            anIdea(
              id: 'i',
              named: 'Tagged',
              tags: <Tag>[tag('home'), tag('Errand')],
              updatedAt: at(20),
            ),
          ],
        ),
        aSnapshot(
          ideas: <Idea>[
            anIdea(
              id: 'i',
              named: 'Tagged',
              tags: <Tag>[tag('ERRAND'), tag('urgent')],
              updatedAt: at(10),
            ),
          ],
        ),
      ]);

      expect(result.ideas.single.tags.map((Tag t) => t.value), <String>[
        'home',
        'Errand',
        'urgent',
      ]);
    });

    test('the longest text wins, measured in grapheme clusters', () {
      // "ee" with two combining acute accents: four code units, but only two
      // grapheme clusters, which is the unit NAME-2 and ItemText count. So it
      // is shorter than 'abc' and must lose. Counting code units would pick it.
      final ItemText decomposed = context(
        String.fromCharCodes(<int>[0x65, 0x0301, 0x65, 0x0301]),
      );
      expect(decomposed.value.length, 4);

      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          ideas: <Idea>[
            anIdea(id: 'i', named: 'Text', contextText: decomposed),
          ],
        ),
        aSnapshot(
          ideas: <Idea>[
            anIdea(id: 'i', named: 'Text', contextText: context('abc')),
          ],
        ),
      ]);

      expect(result.ideas.single.context.value, 'abc');
    });

    test('the most urgent timeframe wins', () {
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          ideas: <Idea>[
            anIdea(id: 'i', named: 'Urgent', timeframe: Timeframe.distant),
          ],
        ),
        aSnapshot(
          ideas: <Idea>[
            anIdea(id: 'i', named: 'Urgent', timeframe: Timeframe.soon),
          ],
        ),
      ]);

      expect(result.ideas.single.timeframe, Timeframe.soon);
    });

    test('createdAt is the earliest and updatedAt the latest', () {
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          ideas: <Idea>[
            anIdea(
              id: 'i',
              named: 'Timed',
              createdAt: at(10),
              updatedAt: at(20),
            ),
          ],
        ),
        aSnapshot(
          ideas: <Idea>[
            anIdea(
              id: 'i',
              named: 'Timed',
              createdAt: at(5),
              updatedAt: at(15),
            ),
          ],
        ),
      ]);

      expect(result.ideas.single.createdAt, at(5));
      expect(result.ideas.single.updatedAt, at(20));
    });

    test('§9.4: Done, isDeleted and isArchived are all sticky', () {
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          tasks: <Task>[
            aTask(
              id: 't',
              named: 'Sticky',
              status: TaskStatus.done,
              isArchived: true,
              isDeleted: true,
              updatedAt: at(10),
            ),
          ],
        ),
        // The user un-completed, un-archived and restored it on this replica.
        aSnapshot(
          tasks: <Task>[aTask(id: 't', named: 'Sticky', updatedAt: at(99))],
        ),
      ]);

      final Task merged = result.tasks.single;
      expect(merged.status, TaskStatus.done);
      expect(merged.isArchived, isTrue);
      expect(merged.isDeleted, isTrue);
    });

    test('the sourceIdea fields resolve as a pair, never independently', () {
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        // The primary: latest updatedAt, but no source of its own.
        aSnapshot(
          tasks: <Task>[aTask(id: 't', named: 'Converted', updatedAt: at(99))],
        ),
        aSnapshot(
          tasks: <Task>[
            aTask(
              id: 't',
              named: 'Converted',
              updatedAt: at(10),
              sourceIdeaId: 'idea-1',
              sourceIdeaCreatedAt: at(1),
            ),
          ],
        ),
        aSnapshot(
          tasks: <Task>[
            aTask(
              id: 't',
              named: 'Converted',
              updatedAt: at(20),
              sourceIdeaId: 'idea-2',
              sourceIdeaCreatedAt: at(2),
            ),
          ],
        ),
      ]);

      final Task merged = result.tasks.single;
      expect(merged.sourceIdeaId, 'idea-1');
      expect(
        merged.sourceIdeaCreatedAt,
        at(1),
        reason: '§3.3: one fact about one Idea',
      );
    });
  });

  group('§9.3 step 5: subtask resolution', () {
    test('id matches before name-position, so a rename loses no subtask', () {
      // The bug this ordering exists to prevent. Combined into one "shares an
      // id OR shares a key" relation, the two relations chain: A1~B1 by id,
      // A2~B2 by id, and A1~B2 by the key (set, 0) — one component, and two
      // subtasks silently become one (principle 1.2.4).
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          tasks: <Task>[
            aTask(
              id: 't',
              named: 'Workout',
              subtasks: <Subtask>[
                aSubtask(id: 's1', named: 'Set'),
                aSubtask(id: 's2', named: 'Set'),
              ],
            ),
          ],
        ),
        aSnapshot(
          tasks: <Task>[
            aTask(
              id: 't',
              named: 'Workout',
              updatedAt: at(10),
              subtasks: <Subtask>[
                aSubtask(id: 's1', named: 'Warmup', updatedAt: at(10)),
                aSubtask(id: 's2', named: 'Set'),
              ],
            ),
          ],
        ),
      ]);

      expect(
        result.tasks.single.subtasks.map((Subtask s) => s.name.value),
        <String>['Warmup', 'Set'],
      );
    });

    test('reordering same-named subtasks loses none either', () {
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          tasks: <Task>[
            aTask(
              id: 't',
              named: 'Workout',
              subtasks: <Subtask>[
                aSubtask(id: 's1', named: 'Set', status: TaskStatus.done),
                aSubtask(id: 's2', named: 'Set'),
              ],
            ),
          ],
        ),
        aSnapshot(
          tasks: <Task>[
            aTask(
              id: 't',
              named: 'Workout',
              subtasks: <Subtask>[
                aSubtask(id: 's2', named: 'Set'),
                aSubtask(id: 's1', named: 'Set', status: TaskStatus.done),
              ],
            ),
          ],
        ),
      ]);

      expect(result.tasks.single.subtasks, hasLength(2));
    });

    test('a renamed subtask keeps its new name (latest updatedAt)', () {
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          tasks: <Task>[
            aTask(
              id: 't',
              named: 'Task',
              subtasks: <Subtask>[aSubtask(id: 's1', named: 'Old name')],
            ),
          ],
        ),
        aSnapshot(
          tasks: <Task>[
            aTask(
              id: 't',
              named: 'Task',
              updatedAt: at(10),
              subtasks: <Subtask>[
                aSubtask(id: 's1', named: 'New name', updatedAt: at(10)),
              ],
            ),
          ],
        ),
      ]);

      expect(result.tasks.single.subtasks.single.name.value, 'New name');
    });

    test('a subtask group takes the smallest id and highest status', () {
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          tasks: <Task>[
            aTask(
              id: 'a',
              named: 'Same name',
              subtasks: <Subtask>[aSubtask(id: 'zzz', named: 'Step')],
            ),
          ],
        ),
        aSnapshot(
          tasks: <Task>[
            aTask(
              id: 'b',
              named: 'Same name',
              subtasks: <Subtask>[
                aSubtask(id: 'aaa', named: 'Step', status: TaskStatus.blocked),
              ],
            ),
          ],
        ),
      ]);

      final Subtask merged = result.tasks.single.subtasks.single;
      expect(merged.id, 'aaa');
      expect(merged.status, TaskStatus.blocked);
    });

    test('order: the primary record first, then the rest in record order', () {
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          tasks: <Task>[
            aTask(
              id: 'a',
              named: 'Same name',
              subtasks: <Subtask>[
                aSubtask(id: 'a1', named: 'First'),
                aSubtask(id: 'a2', named: 'Second'),
              ],
            ),
          ],
        ),
        aSnapshot(
          tasks: <Task>[
            aTask(
              id: 'b',
              named: 'Same name',
              subtasks: <Subtask>[
                aSubtask(id: 'b1', named: 'Third'),
                aSubtask(id: 'b2', named: 'Fourth'),
              ],
            ),
          ],
        ),
      ]);

      expect(
        result.tasks.single.subtasks.map((Subtask s) => s.name.value),
        <String>['First', 'Second', 'Third', 'Fourth'],
      );
    });
  });

  group('§9.3 step 6: re-establishing the invariants', () {
    test('INV-2, INV-4: the repair clears completedAt, isArchived and '
        'archivedAt together', () {
      // One replica archived the Task; the other added an open subtask to it.
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          tasks: <Task>[
            aTask(
              id: 't',
              named: 'Tidy up',
              status: TaskStatus.done,
              isArchived: true,
              archivedAt: at(50),
              updatedAt: at(50),
              subtasks: <Subtask>[
                aSubtask(id: 's1', named: 'Sweep', status: TaskStatus.done),
              ],
            ),
          ],
        ),
        aSnapshot(
          tasks: <Task>[
            aTask(
              id: 't',
              named: 'Tidy up',
              updatedAt: at(10),
              subtasks: <Subtask>[
                aSubtask(id: 's1', named: 'Sweep', status: TaskStatus.done),
                aSubtask(id: 's2', named: 'Mop'),
              ],
            ),
          ],
        ),
      ]);

      final Task merged = result.tasks.single;
      expect(merged.status, TaskStatus.todo);
      expect(merged.completedAt, isNull);
      expect(merged.isArchived, isFalse);
      expect(
        merged.archivedAt,
        isNull,
        reason: 'INV-4: archivedAt is conditional on the flag',
      );
      expect(merged.invariantFailures, isEmpty);
    });

    test('a repaired Task that lands on a live name is merged again', () {
      // The step-6 second bullet, and the only way to reach it: the archived
      // record becomes the primary by id, carries its name out, and the repair
      // makes the result active again — onto a name another component holds.
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          tasks: <Task>[
            aTask(
              id: 't1',
              named: 'Water the plants',
              status: TaskStatus.done,
              isArchived: true,
              archivedAt: at(50),
              updatedAt: at(50),
              subtasks: <Subtask>[
                aSubtask(id: 's1', named: 'Fill can', status: TaskStatus.done),
              ],
            ),
          ],
        ),
        aSnapshot(
          tasks: <Task>[
            aTask(
              id: 't1',
              named: 'Water the plants again',
              updatedAt: at(10),
              subtasks: <Subtask>[
                aSubtask(id: 's1', named: 'Fill can', status: TaskStatus.done),
                aSubtask(id: 's2', named: 'Water them'),
              ],
            ),
            aTask(id: 't2', named: 'water  the  PLANTS', updatedAt: at(20)),
          ],
        ),
      ]);

      expect(result.tasks, hasLength(1));
      expect(result.tasks.single.id, 't1');
      expect(
        datasetInvariantFailures(
          ideas: result.ideas,
          tasks: result.tasks,
          tombstones: result.tombstones,
        ),
        isEmpty,
      );
      expect(
        result.report.components.map((MergedComponent c) => c.pass),
        contains(1),
        reason: 'the name re-pass is recorded as its own pass',
      );
    });

    test('for Ideas the name re-pass provably never fires', () {
      // Every Idea is active (§2), so two components resolving to the same
      // name would have shared a MERGE-5 name edge in step 3.
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          ideas: <Idea>[
            anIdea(id: 'i1', named: 'Alpha', updatedAt: at(10)),
            anIdea(id: 'i2', named: 'Beta', updatedAt: at(10)),
          ],
        ),
        aSnapshot(
          ideas: <Idea>[
            anIdea(id: 'i1', named: 'Beta', updatedAt: at(20)),
            anIdea(id: 'i2', named: 'Alpha', updatedAt: at(20)),
          ],
        ),
      ]);

      expect(
        result.report.components
            .where((MergedComponent c) => c.kind == ItemKind.idea)
            .every((MergedComponent c) => c.pass == 0),
        isTrue,
      );
      expect(
        datasetInvariantFailures(ideas: result.ideas, tasks: result.tasks),
        isEmpty,
      );
    });
  });

  group('§9.3 step 8, MERGE-3A: canonical output order', () {
    test('ideas, tasks and tombstones come out sorted by id', () {
      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(
          ideas: <Idea>[
            anIdea(id: 'i-c', named: 'Third'),
            anIdea(id: 'i-a', named: 'First'),
          ],
          tasks: <Task>[
            aTask(id: 't-b', named: 'Second task'),
            aTask(id: 't-a', named: 'First task'),
          ],
          tombstones: <IdeaTombstone>[
            aTombstone(id: 'x-b'),
            aTombstone(id: 'x-a'),
          ],
        ),
      ]);

      expect(result.ideas.map((Idea i) => i.id), <String>['i-a', 'i-c']);
      expect(result.tasks.map((Task t) => t.id), <String>['t-a', 't-b']);
      expect(result.tombstones.map((IdeaTombstone t) => t.id), <String>[
        'x-a',
        'x-b',
      ]);
    });
  });

  group('§9.3: degenerate inputs', () {
    test('merging nothing yields an empty result', () {
      final MergeResult result = mergeOf(const <ReplicaSnapshot>[]);

      expect(result.ideas, isEmpty);
      expect(result.tasks, isEmpty);
      expect(result.tombstones, isEmpty);
      expect(result.report.isEmpty, isTrue);
    });

    test('a component of size 1 passes through unchanged (step 3)', () {
      final Idea idea = anIdea(
        id: 'i',
        named: 'Untouched',
        tags: <Tag>[tag('b'), tag('a')],
        contextText: context('some context'),
      );

      final MergeResult result = mergeOf(<ReplicaSnapshot>[
        aSnapshot(ideas: <Idea>[idea]),
      ]);

      expect(result.ideas.single, same(idea));
      expect(result.report.isEmpty, isTrue);
    });

    test('MERGE-2: replicaId never reaches the output', () {
      final Idea idea = anIdea(id: 'i', named: 'Same everywhere');

      expect(
        mergeOf(<ReplicaSnapshot>[
          aSnapshot(replicaId: 'zzz', ideas: <Idea>[idea]),
        ]),
        mergeOf(<ReplicaSnapshot>[
          aSnapshot(replicaId: 'aaa', ideas: <Idea>[idea]),
        ]),
      );
    });
  });
}

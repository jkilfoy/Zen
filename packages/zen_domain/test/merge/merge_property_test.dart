/// §11.12 item 2. Property tests for the merge, over many seeded random
/// snapshots.
///
/// Every failure message carries its seed, so a failing case reproduces by
/// passing that seed to [SnapshotGenerator] — which is the whole point of
/// §11.12's "a **seeded** `Random` so failures reproduce".
///
/// The convergence simulation (§11.12 item 3) is deliberately **not** here: it
/// needs the orchestrator, and belongs to M6.
library;

import 'dart:math';

import 'package:test/test.dart';
import 'package:zen_domain/zen_domain.dart';

import '../support/snapshot_generators.dart';

/// How many seeds each property runs over. Pure Dart and in-memory, so the
/// whole file is a fraction of a second; raise it when hunting something.
const int seedCount = 300;

void main() {
  const NameUnionMergeStrategy merge = NameUnionMergeStrategy();

  /// Runs [body] over [seedCount] seeds, prefixing any failure with the seed.
  void forEachSeed(void Function(int seed, List<ReplicaSnapshot> inputs) body) {
    for (int seed = 0; seed < seedCount; seed++) {
      final List<ReplicaSnapshot> inputs = SnapshotGenerator(seed)
          .replicas(count: 1 + Random(seed).nextInt(3));
      body(seed, inputs);
    }
  }

  test('the generators themselves produce valid datasets (§3.7)', () {
    // If this fails the fault is in the generator, not the merge — and the
    // properties below would otherwise report it as a merge bug.
    forEachSeed((int seed, List<ReplicaSnapshot> inputs) {
      for (final ReplicaSnapshot input in inputs) {
        expect(
          datasetInvariantFailures(
            ideas: input.ideas,
            tasks: input.tasks,
            tombstones: input.tombstones,
          ),
          isEmpty,
          reason: 'seed $seed, replica ${input.replicaId}',
        );
      }
    });
  });

  test('MERGE-2, AC-19: the merge is order-independent', () {
    forEachSeed((int seed, List<ReplicaSnapshot> inputs) {
      final MergeResult expected = merge.merge(inputs);

      // Every rotation, plus a seeded shuffle, so three-replica cases are not
      // only ever checked as a straight reversal.
      for (int rotation = 1; rotation < inputs.length; rotation++) {
        final List<ReplicaSnapshot> rotated = <ReplicaSnapshot>[
          ...inputs.sublist(rotation),
          ...inputs.sublist(0, rotation),
        ];
        expect(
          merge.merge(rotated),
          expected,
          reason: 'seed $seed, rotated by $rotation',
        );
      }

      final List<ReplicaSnapshot> shuffled = List<ReplicaSnapshot>.of(inputs)
        ..shuffle(Random(seed));
      expect(merge.merge(shuffled), expected, reason: 'seed $seed, shuffled');
    });
  });

  test('§11.12: the merge is idempotent', () {
    forEachSeed((int seed, List<ReplicaSnapshot> inputs) {
      final MergeResult once = merge.merge(inputs);
      final MergeResult twice = merge.merge(<ReplicaSnapshot>[
        once.asSnapshot('merged'),
      ]);

      expect(twice.ideas, once.ideas, reason: 'seed $seed');
      expect(twice.tasks, once.tasks, reason: 'seed $seed');
      expect(twice.tombstones, once.tombstones, reason: 'seed $seed');
      expect(
        twice.report.isEmpty,
        isTrue,
        reason: 'seed $seed: a merged dataset holds nothing left to resolve',
      );
    });
  });

  test('§3.7: the output satisfies every invariant', () {
    forEachSeed((int seed, List<ReplicaSnapshot> inputs) {
      final MergeResult result = merge.merge(inputs);

      expect(
        datasetInvariantFailures(
          ideas: result.ideas,
          tasks: result.tasks,
          tombstones: result.tombstones,
        ),
        isEmpty,
        reason: 'seed $seed',
      );
    });
  });

  test('AC-17: no tombstoned id appears in the output', () {
    forEachSeed((int seed, List<ReplicaSnapshot> inputs) {
      final MergeResult result = merge.merge(inputs);
      final Set<String> buried = <String>{
        for (final ReplicaSnapshot input in inputs)
          for (final IdeaTombstone tombstone in input.tombstones) tombstone.id,
      };

      expect(
        result.ideas.where((Idea i) => buried.contains(i.id)),
        isEmpty,
        reason: 'seed $seed',
      );
      expect(
        result.tombstones.map((IdeaTombstone t) => t.id).toSet(),
        buried,
        reason: 'seed $seed: the tombstone set is preserved exactly',
      );
    });
  });

  test('§9.3 step 4: every output id came from an input', () {
    // The merge never invents an id, and never keeps one whose record it
    // dropped: M3's foreign keys and M6's backup both depend on this.
    forEachSeed((int seed, List<ReplicaSnapshot> inputs) {
      final MergeResult result = merge.merge(inputs);
      final Set<String> ideaIds = <String>{
        for (final ReplicaSnapshot input in inputs)
          for (final Idea idea in input.ideas) idea.id,
      };
      final Set<String> taskIds = <String>{
        for (final ReplicaSnapshot input in inputs)
          for (final Task task in input.tasks) task.id,
      };

      expect(
        result.ideas.map((Idea i) => i.id).where((String id) {
          return !ideaIds.contains(id);
        }),
        isEmpty,
        reason: 'seed $seed',
      );
      expect(
        result.tasks.map((Task t) => t.id).where((String id) {
          return !taskIds.contains(id);
        }),
        isEmpty,
        reason: 'seed $seed',
      );
    });
  });

  test('§9.3 step 8: the output is sorted by id', () {
    forEachSeed((int seed, List<ReplicaSnapshot> inputs) {
      final MergeResult result = merge.merge(inputs);

      expect(
        result.ideas.map((Idea i) => i.id),
        orderedEquals(result.ideas.map((Idea i) => i.id).toList()..sort()),
        reason: 'seed $seed',
      );
      expect(
        result.tasks.map((Task t) => t.id),
        orderedEquals(result.tasks.map((Task t) => t.id).toList()..sort()),
        reason: 'seed $seed',
      );
    });
  });

  test('§9.3 step 6: the Idea name re-pass never fires', () {
    // Checked rather than trusted, as §9.3 asks. Every Idea is active (§2), so
    // two components resolving to the same name would have shared a MERGE-5
    // name edge in step 3 and been one component to begin with.
    forEachSeed((int seed, List<ReplicaSnapshot> inputs) {
      final MergeReport report = merge.merge(inputs).report;

      expect(
        report.components
            .where((MergedComponent c) => c.kind == ItemKind.idea)
            .where((MergedComponent c) => c.pass > 0),
        isEmpty,
        reason: 'seed $seed',
      );
    });
  });

  test('§9.3 step 5: no subtask is dropped without a match', () {
    // The union property. Every input subtask id must be represented in the
    // output — either as the resolved id, or by having been matched into a
    // group whose smallest id won.
    forEachSeed((int seed, List<ReplicaSnapshot> inputs) {
      final MergeResult result = merge.merge(inputs);

      for (final Task merged in result.tasks) {
        final int mostOnAnyReplica = inputs
            .expand((ReplicaSnapshot s) => s.tasks)
            .where((Task t) => t.id == merged.id)
            .map((Task t) => t.subtasks.length)
            .fold(0, (int a, int b) => a > b ? a : b);

        expect(
          merged.subtasks.length,
          greaterThanOrEqualTo(mostOnAnyReplica),
          reason:
              'seed $seed, task ${merged.id}: the union can only grow a list',
        );
      }
    });
  });

  group('§9.3 step 6: the name re-pass, over a generator that reaches it', () {
    // `replicas` produces this shape vanishingly rarely — measured over 300
    // seeds it never once produced all four preconditions at the same time —
    // so the properties above were covering the re-pass not at all. This
    // generator builds the shape and randomizes everything else.
    List<ReplicaSnapshot> inputsFor(int seed) =>
        SnapshotGenerator(seed).archivedNameCollisionReplicas();

    test('the generated inputs are valid datasets (§3.7)', () {
      for (int seed = 0; seed < seedCount; seed++) {
        for (final ReplicaSnapshot input in inputsFor(seed)) {
          expect(
            datasetInvariantFailures(ideas: input.ideas, tasks: input.tasks),
            isEmpty,
            reason: 'seed $seed, replica ${input.replicaId}',
          );
        }
      }
    });

    test('it really does reach the re-pass', () {
      // A coverage assertion, so this group cannot quietly become vacuous if
      // the generator or the merge changes underneath it.
      int reached = 0;
      for (int seed = 0; seed < seedCount; seed++) {
        final MergeReport report = merge.merge(inputsFor(seed)).report;
        if (report.components.any((MergedComponent c) => c.pass > 0)) reached++;
      }
      expect(
        reached,
        greaterThan(seedCount ~/ 2),
        reason: 'the step-6 name re-pass should fire in most seeds',
      );
    });

    test('MERGE-2: still order-independent', () {
      for (int seed = 0; seed < seedCount; seed++) {
        final List<ReplicaSnapshot> inputs = inputsFor(seed);
        expect(
          merge.merge(inputs.reversed.toList()),
          merge.merge(inputs),
          reason: 'seed $seed',
        );
      }
    });

    test('§3.7: still invariant-preserving, and NAME-6 is re-established', () {
      for (int seed = 0; seed < seedCount; seed++) {
        final MergeResult result = merge.merge(inputsFor(seed));
        expect(
          datasetInvariantFailures(ideas: result.ideas, tasks: result.tasks),
          isEmpty,
          reason: 'seed $seed',
        );
      }
    });

    test('§11.12: still idempotent, so the re-pass terminates at a fixed '
        'point', () {
      for (int seed = 0; seed < seedCount; seed++) {
        final MergeResult once = merge.merge(inputsFor(seed));
        final MergeResult twice = merge.merge(<ReplicaSnapshot>[
          once.asSnapshot('merged'),
        ]);
        expect(twice.tasks, once.tasks, reason: 'seed $seed');
        expect(twice.report.isEmpty, isTrue, reason: 'seed $seed');
      }
    });
  });
}

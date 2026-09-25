/// §11.12 item 3. The convergence simulation.
///
/// **This is not a widget test.** It lives in `zen_app` because it needs
/// `zen_data` and `zen_sync` together and §11.1's arrows give no other package
/// that has both: making `zen_data` a dev-dependency of `zen_sync` would drag
/// Flutter into `zen_sync` and break `dart test` on it. `zen_app` is the
/// composition root, already depends on both, and runs under `flutter test`, so
/// this costs no new dependency arrow.
///
/// Two replicas backed by **real databases**, a randomly generated script of
/// user operations interleaved with random sync points through a **real
/// transport** — an ordinary shared directory, which is what Syncthing or a
/// cloud drive presents. After a final mutual sync the two replicas must be
/// field for field identical and every §3.7 invariant must hold.
///
/// "This is the test most likely to find what §9.4 has not anticipated."
///
/// Everything here is deterministic given the seed, and the seed is in every
/// failure message, so a failing run reproduces by running that seed alone.
library;

import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_data/zen_data.dart';
import 'package:zen_domain/testing.dart';
import 'package:zen_domain/zen_domain.dart';
import 'package:zen_sync/zen_sync.dart';

/// How many seeds the suite runs. Enough to exercise the shapes below without
/// making `flutter test` slow enough that anyone is tempted to skip it.
const int _seedCount = 60;

/// How many user operations each seed performs before the replicas settle.
const int _operationsPerSeed = 40;

/// The instant the simulation starts from.
final DateTime _origin = DateTime.utc(2026, 9, 24, 9);

void main() {
  late Directory root;

  // Two `AppDatabase` instances in one isolate is exactly what this file is
  // for, and drift cannot tell that they hold *separate* in-memory executors —
  // its warning is about two databases sharing one. Silenced here rather than
  // tolerated, so that a real warning in another test is still visible.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUp(() => root = Directory.systemTemp.createTempSync('zen_convergence'));
  tearDown(() => root.deleteSync(recursive: true));

  group('§11.12 item 3: two replicas converge through a shared folder', () {
    for (int seed = 0; seed < _seedCount; seed++) {
      test('seed $seed', () async {
        await _runSimulation(seed: seed, root: root);
      });
    }
  });

  test('the script actually exercises every operation it claims to', () async {
    // A simulation that only ever created Ideas would pass for the wrong
    // reason. This keeps the generator honest, the same way D-M2-7's coverage
    // assertion does for the merge property tests.
    final Set<_Operation> seen = <_Operation>{};
    for (int seed = 0; seed < _seedCount; seed++) {
      seen.addAll(
        await _runSimulation(seed: seed, root: root, subdirectory: 'cov$seed'),
      );
    }

    expect(
      seen,
      unorderedEquals(_Operation.values),
      reason: 'every operation in §11.12 item 3 must occur across the seeds',
    );
  });
}

/// The user operations §11.12 item 3 names, plus the subtask edits that make
/// §9.3 step 5 and step 6 reachable.
enum _Operation {
  createIdea,
  editIdea,
  deleteIdea,
  convertIdea,
  createTask,
  renameTask,
  completeTask,
  reopenTask,
  blockTask,
  deleteTask,
  restoreTask,
  archiveTask,
  unarchiveTask,
  addSubtask,
  completeSubtask,
  renameSubtask,
}

/// Runs one seed and returns the operations that actually took effect.
Future<Set<_Operation>> _runSimulation({
  required int seed,
  required Directory root,
  String subdirectory = 'folder',
}) async {
  final Random random = Random(seed);
  final Directory folder = Directory('${root.path}/$subdirectory')
    ..createSync(recursive: true);

  // **One clock, shared.** Two independently drifting clocks put a Task's
  // `createdAt` on one replica ahead of its `updatedAt` on the other and break
  // INV-5 before any merge runs. That is not a merge bug, it is clock skew, and
  // nothing in §9 claims to survive it: §9.3 step 4 resolves by comparing
  // `updatedAt` across replicas, which only means anything if the two clocks
  // agree. Real devices agree to within seconds. So does this one.
  final FakeClock clock = FakeClock(_origin);

  final _Replica a = _Replica(
    replicaId: 'replica-a',
    folder: folder,
    backupRoot: '${root.path}/$subdirectory-backup-a',
    clock: clock,
  );
  final _Replica b = _Replica(
    replicaId: 'replica-b',
    folder: folder,
    backupRoot: '${root.path}/$subdirectory-backup-b',
    clock: clock,
  );

  final Set<_Operation> performed = <_Operation>{};
  try {
    for (int step = 0; step < _operationsPerSeed; step++) {
      final _Replica replica = random.nextBool() ? a : b;

      // Usually the clock moves before an operation, so `updatedAt` ordering is
      // fine-grained. Sometimes it does not, which is how two replicas come to
      // hold records with identical `updatedAt` — the case §9.3 step 4's
      // tie-breaks exist for, and one that would otherwise never occur.
      if (random.nextInt(6) != 0) {
        clock.advance(_step(random));
      }

      final _Operation? done = await replica.perform(random);
      if (done != null) {
        performed.add(done);
      }

      // Random sync points. One replica syncing alone is the common real case —
      // the phone writes, the desktop has not looked yet — so it is the common
      // case here too.
      if (random.nextInt(4) == 0) {
        await replica.sync();
      }
    }

    // "After a final mutual sync." Three rounds each, so that content can
    // travel A -> folder -> B -> folder -> A and settle even when the last user
    // operation landed on the replica that syncs second.
    for (int round = 0; round < 3; round++) {
      await a.sync();
      await b.sync();
    }

    final _Dataset left = await a.read();
    final _Dataset right = await b.read();

    expect(
      left.ideas,
      right.ideas,
      reason: 'seed $seed: the replicas hold different Ideas',
    );
    expect(
      left.tasks,
      right.tasks,
      reason: 'seed $seed: the replicas hold different Tasks',
    );
    expect(
      left.tombstones,
      right.tombstones,
      reason: 'seed $seed: the replicas hold different tombstones',
    );

    for (final (String label, _Dataset dataset) in <(String, _Dataset)>[
      ('A', left),
      ('B', right),
    ]) {
      expect(
        datasetInvariantFailures(
          ideas: dataset.ideas,
          tasks: dataset.tasks,
          tombstones: dataset.tombstones,
        ),
        isEmpty,
        reason: 'seed $seed: replica $label breaks §3.7',
      );
    }

    return performed;
  } finally {
    // Closed here rather than through `addTearDown`, because the coverage test
    // runs every seed inside one `test` and would otherwise hold a hundred and
    // twenty open databases until it finished.
    await a.close();
    await b.close();
  }
}

/// How far a clock moves between two operations.
///
/// Mostly minutes, so `updatedAt` ordering is fine-grained and ties are rare
/// but reachable. Every so often a jump of many hours, because **EOD-2 is
/// otherwise unreachable**: the archive sweep only retires a Done Task once its
/// End-of-Day boundary has passed, and forty one-to-five-minute steps never
/// cross 02:00. Without the jumps the simulation silently never archived
/// anything, which the coverage assertion in `main` is there to catch.
Duration _step(Random random) => random.nextInt(8) == 0
    ? Duration(hours: 6 + random.nextInt(30))
    : Duration(minutes: 1 + random.nextInt(5));

/// One replica's dataset, in canonical order so two can be compared directly.
final class _Dataset {
  _Dataset(List<Idea> ideas, List<Task> tasks, List<IdeaTombstone> tombstones)
    : ideas = (List<Idea>.of(ideas)..sort(_byIdeaId)),
      tasks = (List<Task>.of(tasks)..sort(_byTaskId)),
      tombstones = (List<IdeaTombstone>.of(tombstones)..sort(_byTombstoneId));

  final List<Idea> ideas;
  final List<Task> tasks;
  final List<IdeaTombstone> tombstones;

  // MERGE-3A: these three are sets, so the comparison sorts by `id` rather than
  // relying on the order a repository happened to return them in.
  static int _byIdeaId(Idea a, Idea b) => a.id.compareTo(b.id);
  static int _byTaskId(Task a, Task b) => a.id.compareTo(b.id);
  static int _byTombstoneId(IdeaTombstone a, IdeaTombstone b) =>
      a.id.compareTo(b.id);
}

/// One simulated device: a real database, the real repositories, and a real
/// `FileSnapshotTransport` over the shared folder.
final class _Replica {
  _Replica({
    required this.replicaId,
    required Directory folder,
    required String backupRoot,
    required FakeClock clock,
    // A named parameter may not begin with an underscore, so `this._clock` is
    // not available here.
    // ignore: prefer_initializing_formals
  }) : _clock = clock,
       _ids = SequentialIdGenerator(prefix: replicaId) {
    _db = AppDatabase(NativeDatabase.memory());
    _ideas = DriftIdeaRepository(_db, ids: _ids);
    _tasks = DriftTaskRepository(
      _db,
      ids: _ids,
      zone: const FixedOffsetTimeZoneRules(Duration.zero),
    );
    _tombstones = DriftTombstoneStore(_db);
    _conversions = DriftConversionService(_db, ids: _ids);

    _orchestrator = SyncOrchestrator(
      enabledTransports: () async => <SyncTransport>[
        FileSnapshotTransport(
          directory: IoSnapshotDirectory(folder.path),
          replicaId: replicaId,
        ),
      ],
      replicas: _FixedReplica(replicaId),
      ideas: _ideas,
      tasks: _tasks,
      tombstones: _tombstones,
      dataset: DriftDatasetRepository(_db),
      settings: DriftSettingsRepository(_db),
      events: DriftEventLog(_db),
      mergeStrategy: const NameUnionMergeStrategy(),
      backups: BackupStore(directoryPath: backupRoot),
      clock: _clock,
      ids: _ids,
      appVersion: '1.0.0',
    );
  }

  final String replicaId;
  final FakeClock _clock;
  final SequentialIdGenerator _ids;

  late final AppDatabase _db;
  late final DriftIdeaRepository _ideas;
  late final DriftTaskRepository _tasks;
  late final DriftTombstoneStore _tombstones;
  late final DriftConversionService _conversions;
  late final SyncOrchestrator _orchestrator;

  int _names = 0;

  Future<void> close() => _db.close();

  Future<void> sync() => _orchestrator.sync();

  Future<_Dataset> read() async => _Dataset(
    await _ideas.watchAll().first,
    await _tasks.watchAll().first,
    await _tombstones.all(),
  );

  /// A name from a small shared pool, so that two replicas independently
  /// inventing the same name — which is what MERGE-5's name matching and §9.3
  /// step 6's repair exist for — happens often rather than never.
  ItemName _freshName(Random random) {
    const List<String> stems = <String>[
      'Water the plants',
      'Groceries list',
      'Write report',
      'Call the bank',
      'Book flights',
      'Fix the tap',
    ];
    final String stem = stems[random.nextInt(stems.length)];
    // Half the time the bare stem, so collisions across replicas are frequent;
    // half the time a unique suffix, so the dataset actually grows.
    return random.nextBool()
        ? ItemName.parse(stem).unwrap()
        : ItemName.parse('$stem ${replicaId.substring(8)}${_names++}').unwrap();
  }

  /// Performs one random operation, returning which one actually took effect.
  ///
  /// A rule that refuses — a name collision, a Done Task that cannot gain a
  /// subtask — returns null. Refusals are part of the simulation, not a bug in
  /// it: they are what a real user hits, and the merge has to converge across
  /// replicas that refused different things.
  Future<_Operation?> perform(Random random) async {
    final DateTime now = _clock.nowUtc();
    final List<Idea> ideas = await _ideas.watchAll().first;
    final List<Task> tasks = await _tasks.watchAll().first;

    switch (random.nextInt(16)) {
      case 0:
        final Result<Idea, RuleViolation> draft = createIdea(
          name: _freshName(random),
          timeframe: Timeframe.values[random.nextInt(Timeframe.values.length)],
          now: now,
          ids: _ids,
          activeIdeaNormalizedNames: await _ideas.activeNormalizedNames(),
        );
        if (draft case Ok<Idea, RuleViolation>(value: final Idea idea)) {
          return (await _ideas.create(idea)).isOk
              ? _Operation.createIdea
              : null;
        }
        return null;

      case 1:
        final Idea? idea = _pick(ideas, random);
        if (idea == null) {
          return null;
        }
        final Result<Idea, RuleViolation> edited = await _ideas.update(
          idea.copyWith(
            timeframe:
                Timeframe.values[random.nextInt(Timeframe.values.length)],
            context: ItemText.parseContext('note ' * (1 + random.nextInt(4)))
                .unwrap(),
            updatedAt: now,
          ),
        );
        return edited.isOk ? _Operation.editIdea : null;

      case 2:
        final Idea? idea = _pick(ideas, random);
        if (idea == null) {
          return null;
        }
        await _ideas.delete(idea.id, now);
        return _Operation.deleteIdea;

      case 3:
        final Idea? idea = _pick(ideas, random);
        if (idea == null) {
          return null;
        }
        final Task draft = draftTaskFromIdea(idea, now, _ids);
        return (await _conversions.convert(idea, draft, now)).isOk
            ? _Operation.convertIdea
            : null;

      case 4:
      case 5:
        final Result<Task, RuleViolation> draft = createTask(
          name: _freshName(random),
          now: now,
          ids: _ids,
          activeTaskNormalizedNames: await _tasks.activeNormalizedNames(),
        );
        if (draft case Ok<Task, RuleViolation>(value: final Task task)) {
          return (await _tasks.create(task)).isOk
              ? _Operation.createTask
              : null;
        }
        return null;

      case 6:
        final Task? task = _pick(tasks, random);
        if (task == null) {
          return null;
        }
        final Result<Task, RuleViolation> renamed = await _tasks.update(
          task.copyWith(name: _freshName(random), updatedAt: now),
        );
        return renamed.isOk ? _Operation.renameTask : null;

      case 7:
      case 8:
        final Task? task = _pick(tasks, random);
        if (task == null) {
          return null;
        }
        final Result<Task, RuleViolation> toggled = toggleTaskCompletion(
          task,
          now,
        );
        if (toggled case Ok<Task, RuleViolation>(value: final Task next)) {
          if (!(await _tasks.update(next)).isOk) {
            return null;
          }
          return task.status == TaskStatus.done
              ? _Operation.reopenTask
              : _Operation.completeTask;
        }
        return null;

      case 9:
        final Task? task = _pick(tasks, random);
        if (task == null) {
          return null;
        }
        final Result<Task, RuleViolation> blocked = setTaskStatus(
          task,
          TaskStatus.blocked,
          now,
        );
        if (blocked case Ok<Task, RuleViolation>(value: final Task next)) {
          return (await _tasks.update(next)).isOk ? _Operation.blockTask : null;
        }
        return null;

      case 10:
        final Task? task = _pick(tasks, random);
        if (task == null || task.isDeleted) {
          return null;
        }
        return (await _tasks.softDelete(task.id, now)).isOk
            ? _Operation.deleteTask
            : null;

      case 11:
        final Task? task = _pick(
          tasks.where((Task t) => t.isDeleted).toList(),
          random,
        );
        if (task == null) {
          return null;
        }
        return (await _tasks.restore(task.id, now)).isOk
            ? _Operation.restoreTask
            : null;

      case 12:
        // EOD-2 through the real sweep, so archiving happens the way the app
        // does it rather than by writing the flag by hand.
        final List<Task> swept = await _tasks.runArchiveSweep(
          nowUtc: now,
          endOfDay: LocalTime.endOfDayDefault,
          zoneId: 'UTC',
        );
        return swept.isEmpty ? null : _Operation.archiveTask;

      case 13:
        final Task? task = _pick(
          tasks.where((Task t) => t.isArchived && !t.isDeleted).toList(),
          random,
        );
        if (task == null) {
          return null;
        }
        return (await _tasks.unarchive(task.id, now)).isOk
            ? _Operation.unarchiveTask
            : null;

      case 14:
        final Task? task = _pick(tasks, random);
        if (task == null) {
          return null;
        }
        final Result<Task, RuleViolation> added = addSubtask(
          task,
          SubtaskName.parse(
            random.nextBool() ? 'Set' : 'Step ${random.nextInt(3)}',
          ).unwrap(),
          now,
          _ids,
        );
        if (added case Ok<Task, RuleViolation>(value: final Task next)) {
          return (await _tasks.update(next)).isOk
              ? _Operation.addSubtask
              : null;
        }
        return null;

      default:
        final Task? task = _pick(
          tasks.where((Task t) => t.subtasks.isNotEmpty).toList(),
          random,
        );
        if (task == null) {
          return null;
        }
        final Subtask target =
            task.subtasks[random.nextInt(task.subtasks.length)];
        // Renaming a subtask while the other replica still holds the old name
        // is the case §9.3 step 5 was rewritten for — the one that used to
        // destroy a subtask.
        final Result<Task, RuleViolation> edited = random.nextBool()
            ? renameSubtask(
                task,
                target.id,
                SubtaskName.parse('Warmup ${random.nextInt(3)}').unwrap(),
                now,
              )
            : toggleSubtaskCompletion(task, target.id, now);
        if (edited case Ok<Task, RuleViolation>(value: final Task next)) {
          if (!(await _tasks.update(next)).isOk) {
            return null;
          }
          return next.subtaskById(target.id)?.name == target.name
              ? _Operation.completeSubtask
              : _Operation.renameSubtask;
        }
        return null;
    }
  }

  static T? _pick<T>(List<T> items, Random random) =>
      items.isEmpty ? null : items[random.nextInt(items.length)];
}

/// §11.5.1. A fixed identity, since the simulation names its replicas.
final class _FixedReplica implements ReplicaRepository {
  _FixedReplica(this.id);

  final String id;

  @override
  Future<String> replicaId() async => id;

  @override
  Future<String> deviceName() async => id;
}

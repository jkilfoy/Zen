/// Shared setup for `zen_app`'s widget tests.
///
/// The tests run the real screens over a real (in-memory) database, because
/// §11.13.1 puts M4 and M5's widget tests in the headless column and there is
/// nothing to gain from faking the repositories: the rules they call are
/// `zen_domain`'s, already tested there, and a fake would only prove that the
/// screen agrees with the fake.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_app/src/app.dart';
import 'package:zen_app/src/providers/app_providers.dart';
import 'package:zen_data/zen_data.dart';
import 'package:zen_domain/testing.dart';
import 'package:zen_domain/zen_domain.dart';

/// An arbitrary fixed instant, at millisecond precision (§3, INV-9).
final DateTime base = DateTime.utc(2026, 9, 22, 12);

/// The zone the tests run in, which has DST and so exercises EOD-5.
const String testZoneId = 'America/Toronto';

/// A test's database, providers and clock, wired together.
final class ZenHarness {
  /// Builds a harness over a fresh in-memory database.
  factory ZenHarness({Settings? settings, DateTime? now}) {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final FakeClock clock = FakeClock(now ?? base, zoneId: testZoneId);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        localZoneIdProvider.overrideWithValue(testZoneId),
        initialSettingsProvider.overrideWithValue(settings ?? Settings()),
        deviceNameProvider.overrideWithValue('test-device'),
        // §11.11. Even in `zen_app`, tests stand the clock where they need it.
        clockProvider.overrideWithValue(clock),
        // EOD-5 without pulling in the `timezone` database, which needs its own
        // initialization: the tests that care about DST use this zone's rules.
        timeZoneRulesProvider.overrideWithValue(const TorontoTimeZoneRules()),
      ],
    );
    addTearDown(container.dispose);
    return ZenHarness._(db: db, container: container, clock: clock);
  }

  ZenHarness._({
    required this.db,
    required this.container,
    required this.clock,
  });

  /// The in-memory database every repository in [container] shares.
  final AppDatabase db;

  /// The providers under test.
  final ProviderContainer container;

  /// The clock the app reads. Move it to reach a boundary (EOD-2).
  final FakeClock clock;

  /// Storage for Ideas.
  IdeaRepository get ideas => container.read(ideaRepositoryProvider);

  /// Storage for Tasks.
  TaskRepository get tasks => container.read(taskRepositoryProvider);

  /// The per-replica settings.
  SettingsRepository get settings => container.read(settingsRepositoryProvider);

  /// §9.3 step 1, CONVERT-4. The Idea tombstones.
  TombstoneStore get tombstones => container.read(tombstoneStoreProvider);

  /// Pumps the whole application, so the flows of §5.1 are exercised through
  /// the real router rather than by constructing a screen directly.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const ZenApp()),
    );
    await tester.pumpAndSettle();
  }

  /// Pumps one [child] inside the providers, for a widget tested on its own.
  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// Reads a repository stream's current value from inside a widget test.
///
/// `testWidgets` runs its body with a fake clock, and a Drift stream's first
/// emission is scheduled on a timer that the fake clock never fires while the
/// body is merely awaiting. `runAsync` steps outside the fake clock for the one
/// await, which is what it exists for. A plain `Future` — `findById` and
/// friends — needs none of this.
Future<T> readStream<T>(WidgetTester tester, Stream<T> stream) async =>
    (await tester.runAsync(() => stream.first)) as T;

/// Builds and stores an Idea, returning it.
Future<Idea> seedIdea(
  ZenHarness harness, {
  required String name,
  Timeframe timeframe = Timeframe.now,
  List<String> tags = const <String>[],
  String context = '',
  DateTime? createdAt,
}) async {
  final DateTime now = createdAt ?? harness.clock.nowUtc();
  final Idea idea = Idea(
    id: 'idea-$name',
    name: ItemName.parse(name).unwrap(),
    tags: <Tag>[for (final String tag in tags) Tag.parse(tag).unwrap()],
    context: ItemText.parseContext(context).unwrap(),
    timeframe: timeframe,
    createdAt: now,
    updatedAt: now,
  );
  return (await harness.ideas.create(idea)).unwrap();
}

/// Builds and stores a Task, returning it.
///
/// [subtasks] are `(name, status)` pairs, in order. The Task's own status is
/// applied last so that INV-1 and INV-2 hold as the object is constructed.
Future<Task> seedTask(
  ZenHarness harness, {
  required String name,
  TaskStatus status = TaskStatus.todo,
  List<(String, TaskStatus)> subtasks = const <(String, TaskStatus)>[],
  List<String> tags = const <String>[],
  String description = '',
  DateTime? createdAt,
  bool archived = false,
  bool deleted = false,
}) async {
  final DateTime now = createdAt ?? harness.clock.nowUtc();
  int index = 0;
  Task task = Task(
    id: 'task-$name',
    name: ItemName.parse(name).unwrap(),
    tags: <Tag>[for (final String tag in tags) Tag.parse(tag).unwrap()],
    description: ItemText.parseDescription(description).unwrap(),
    status: status,
    subtasks: <Subtask>[
      for (final (String subtaskName, TaskStatus subtaskStatus) in subtasks)
        Subtask(
          id: 'sub-$name-${index++}',
          name: SubtaskName.parse(subtaskName).unwrap(),
          status: subtaskStatus,
          createdAt: now,
          updatedAt: now,
          completedAt: subtaskStatus == TaskStatus.done ? now : null,
        ),
    ],
    createdAt: now,
    updatedAt: now,
    completedAt: status == TaskStatus.done ? now : null,
  );
  if (archived) {
    task = task.archived(now);
  }
  if (deleted) {
    task = task.softDeleted(now);
  }
  return (await harness.tasks.create(task)).unwrap();
}

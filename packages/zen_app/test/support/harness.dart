/// Shared setup for `zen_app`'s widget tests.
///
/// The tests run the real screens over a real (in-memory) database, because
/// §11.13.1 puts M4 and M5's widget tests in the headless column and there is
/// nothing to gain from faking the repositories: the rules they call are
/// `zen_domain`'s, already tested there, and a fake would only prove that the
/// screen agrees with the fake.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_app/src/app.dart';
import 'package:zen_app/src/providers/app_providers.dart';
import 'package:zen_app/src/providers/sync_providers.dart';
import 'package:zen_app/src/sync/snapshot_file_exchange.dart';
import 'package:zen_app/src/sync/sync_folder_picker.dart';
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
  /// A non-default [Settings] is written through `harness.settings` by the
  /// test, not passed here: `initialSettingsProvider` is only what the first
  /// frame reads, and `settingsProvider`'s stream — the stored value — wins as
  /// soon as it emits.
  factory ZenHarness({
    DateTime? now,
    FakeSyncFolderPicker? folderPicker,
    FakeSnapshotFileExchange? fileExchange,
  }) {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final FakeClock clock = FakeClock(now ?? base, zoneId: testZoneId);
    final Directory backups = Directory.systemTemp.createTempSync('zen_test');
    addTearDown(() => backups.deleteSync(recursive: true));
    // §11.6.3. A real directory for the file transport, so a test that turns
    // sync on exercises the transport rather than a stand-in.
    final Directory syncFolder = Directory.systemTemp.createTempSync(
      'zen_test_sync',
    );
    addTearDown(() => syncFolder.deleteSync(recursive: true));
    final FakeSyncFolderPicker picker = folderPicker ?? FakeSyncFolderPicker();
    final FakeSnapshotFileExchange exchange =
        fileExchange ?? FakeSnapshotFileExchange();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        // §11.6.1, §11.6.6. `main.dart` supplies these from `package_info_plus`
        // and `path_provider`; neither answers under `flutter test`.
        appVersionProvider.overrideWithValue('1.0.0+test'),
        backupDirectoryProvider.overrideWithValue(backups.path),
        // §11.7. The platform glue, which a headless test cannot invoke: both
        // open a native dialog. The screens are what these tests are about, and
        // the screens only ever see this interface (§11.6.3, §11.8).
        syncFolderPickerProvider.overrideWithValue(picker),
        snapshotFileExchangeProvider.overrideWithValue(exchange),
        databaseProvider.overrideWithValue(db),
        localZoneIdProvider.overrideWithValue(testZoneId),
        initialSettingsProvider.overrideWithValue(Settings()),
        deviceNameProvider.overrideWithValue('test-device'),
        // §11.11. Even in `zen_app`, tests stand the clock where they need it.
        clockProvider.overrideWithValue(clock),
        // EOD-5 without pulling in the `timezone` database, which needs its own
        // initialization: the tests that care about DST use this zone's rules.
        timeZoneRulesProvider.overrideWithValue(const TorontoTimeZoneRules()),
      ],
    );
    addTearDown(container.dispose);
    return ZenHarness._(
      db: db,
      container: container,
      clock: clock,
      folderPicker: picker,
      fileExchange: exchange,
      syncFolder: syncFolder,
    );
  }

  ZenHarness._({
    required this.db,
    required this.container,
    required this.clock,
    required this.folderPicker,
    required this.fileExchange,
    required this.syncFolder,
  });

  /// §11.6.3. A real, empty directory a test can point the file transport at.
  final Directory syncFolder;

  /// §11.6.3. The stand-in for the native folder dialog.
  final FakeSyncFolderPicker folderPicker;

  /// §11.8. The stand-in for the native file dialogs.
  final FakeSnapshotFileExchange fileExchange;

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

  /// A test viewport tall enough that a whole form screen fits on it.
  ///
  /// `ListView`'s child delegate is lazy: a control below the fold is not in
  /// the widget tree at all, so a finder for it matches nothing and the failure
  /// reads as "the screen does not have a Save button". The default 800 × 600
  /// view is shorter than either form. NFR-7's responsiveness is a separate
  /// concern and is not what these tests are about.
  static const Size viewportSize = Size(800, 2400);

  /// Pumps the whole application, so the flows of §5.1 are exercised through
  /// the real router rather than by constructing a screen directly.
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = viewportSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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

/// Scrolls [finder] into view, then taps it.
///
/// Both form screens are `ListView`s taller than the test viewport, so a
/// control near the bottom — Save, Delete, the Advanced details panel — is
/// built but off screen, and `tap` refuses to hit it.
Future<void> tapItem(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
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

/// Mints ids for the seeded items.
///
/// NAME-7 lets an archived Task and an active one share a name, which AC-9 and
/// AC-10 both rely on, so the id cannot be derived from the name.
final IdGenerator _seedIds = SequentialIdGenerator(prefix: 'seed');

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
    id: _seedIds.newId(),
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
    id: _seedIds.newId(),
    name: ItemName.parse(name).unwrap(),
    tags: <Tag>[for (final String tag in tags) Tag.parse(tag).unwrap()],
    description: ItemText.parseDescription(description).unwrap(),
    status: status,
    subtasks: <Subtask>[
      for (final (String subtaskName, TaskStatus subtaskStatus) in subtasks)
        Subtask(
          id: '${_seedIds.newId()}-sub-${index++}',
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

/// §11.6.3, §11.7. A [SyncFolderPicker] a test can drive.
///
/// The real ones open a native dialog — `file_selector` on Windows, SAF on
/// Android — which a headless test cannot answer. §11.13.1 puts the Android
/// half of that in the hardware column; this stands in for both so the screens
/// above the interface can be tested.
final class FakeSyncFolderPicker implements SyncFolderPicker {
  /// What [pick] returns. Null means the user cancelled.
  String? location = r'D:\Sync\Zen';

  /// What [stillGranted] reports.
  bool granted = true;

  /// The locations [release] was called with.
  final List<String> released = <String>[];

  @override
  Future<String?> pick() async => location;

  @override
  Future<bool> stillGranted(String location) async => granted;

  @override
  Future<void> release(String location) async => released.add(location);
}

/// §11.8. A [SnapshotFileExchange] a test can drive.
final class FakeSnapshotFileExchange implements SnapshotFileExchange {
  /// What [read] returns. Null means the user cancelled.
  String? incoming;

  /// What [write] was given, if anything.
  String? written;

  /// The name [write] was asked to suggest.
  String? suggestedName;

  @override
  Future<String?> read() async => incoming;

  @override
  Future<String?> write(String suggestedName, String contents) async {
    this.suggestedName = suggestedName;
    written = contents;
    return suggestedName;
  }
}

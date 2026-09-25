/// SET-4, §11.8. The `"Sync"` section of the Settings screen.
///
/// §11.13's M6 row: the transports "cannot be configured or invoked" without
/// this section, "without which the milestone ships unusable". These tests are
/// about that — the controls exist, they write the right settings, and the
/// actions that touch data behave the way §11.8 distinguishes them.
///
/// **Two kinds of test, deliberately split.** Anything that only reads or writes
/// settings is driven through the widgets, because the wiring is what can break
/// there. Anything that reaches `SyncOrchestrator` is driven through
/// `SyncController` inside `tester.runAsync`, for two reasons that compound: a
/// pass builds the local snapshot from `watchAll()`, and as the harness's
/// `readStream` records, "a Drift stream's first emission is scheduled on a
/// timer that the fake clock never fires"; and while a pass runs the section
/// shows an indeterminate progress indicator, so `pumpAndSettle` never settles
/// either (D-M6-15).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_app/src/providers/sync_actions.dart';
import 'package:zen_app/src/providers/app_providers.dart';
import 'package:zen_app/src/providers/sync_providers.dart';
import 'package:zen_domain/zen_domain.dart';
import 'package:zen_sync/zen_sync.dart';

import 'support/harness.dart';

void main() {
  /// Opens Settings through the gear on the Home screen (NAV-2) and scrolls the
  /// Sync section into view.
  Future<void> openSync(WidgetTester tester, ZenHarness harness) async {
    await harness.pumpApp(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sync'));
    await tester.pumpAndSettle();
  }

  /// The Sync section's commands, outside the widget tree.
  SyncController controllerOf(ZenHarness harness) =>
      harness.container.read(syncControllerProvider.notifier);

  Idea anIdea(String id, String name) => Idea(
    id: id,
    name: ItemName.parse(name).unwrap(),
    timeframe: Timeframe.now,
    createdAt: base,
    updatedAt: base,
  );

  /// A snapshot document as another replica would have written it.
  String snapshotFrom(String replicaId, List<Idea> ideas) =>
      const SnapshotCodec().encode(
        SnapshotEnvelope(
          replicaId: replicaId,
          deviceName: 'other-device',
          generatedAt: base,
          appVersion: '1.0.0',
          snapshot: ReplicaSnapshot(replicaId: replicaId, ideas: ideas),
        ),
      );

  /// Points the file transport at the harness's real temporary folder.
  Future<void> enableFolderSync(ZenHarness harness) => harness.settings.write(
    Settings(
      syncFolderEnabled: true,
      syncFolderLocation: harness.syncFolder.path,
    ),
  );

  /// Taps [finder] and lets the real file I/O behind it finish.
  ///
  /// `BackupStore` lists a real directory, and `testWidgets` runs with a fake
  /// clock that never completes that I/O while the body merely pumps —
  /// the same reason the harness's `readStream` exists. `runAsync` steps
  /// outside the fake clock for one real delay, then the dialog can build.
  Future<void> tapAndLoad(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pump();
    // Twice: the first cycle lets the directory read complete on the real event
    // loop, and the second lets the continuation that follows it — the one that
    // actually calls `showDialog` — run and get a frame. One cycle settles
    // before the dialog has been asked for.
    for (int cycle = 0; cycle < 2; cycle++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }
  }

  List<String> namesIn(Directory folder) => folder
      .listSync()
      .map((FileSystemEntity e) => e.uri.pathSegments.last)
      .toList();

  group('§11.8: the section shows what the table specifies', () {
    testWidgets('every control §11.8 names is present', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await openSync(tester, harness);

      expect(find.text('Sync through a shared folder'), findsOneWidget);
      expect(find.text('Sync over the local network'), findsOneWidget);
      expect(find.text('Sync when Zen opens'), findsOneWidget);
      expect(find.text('Sync every'), findsOneWidget);
      expect(find.text('Sync now'), findsOneWidget);
      expect(find.text('Export snapshot…'), findsOneWidget);
      expect(find.text('Import snapshot…'), findsOneWidget);
      expect(find.text('Restore from backup…'), findsOneWidget);
    });

    testWidgets('the LAN toggle is present and disabled until M7', (
      WidgetTester tester,
    ) async {
      // The same reasoning as D-M4-9: an absent control reads as a feature that
      // was forgotten rather than one that is coming.
      final ZenHarness harness = ZenHarness();
      await openSync(tester, harness);

      final SwitchListTile lan = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Sync over the local network'),
      );
      expect(lan.value, isFalse);
      expect(lan.onChanged, isNull);
    });

    testWidgets('the folder toggle waits for a folder to be chosen', (
      WidgetTester tester,
    ) async {
      // Switching a transport on with nowhere to write would be a setting that
      // does nothing and a status line that complains for no reason.
      final ZenHarness harness = ZenHarness();
      await openSync(tester, harness);

      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(
                SwitchListTile,
                'Sync through a shared folder',
              ),
            )
            .onChanged,
        isNull,
      );
      expect(find.text('No folder chosen yet'), findsOneWidget);
      expect(find.text('Choose folder…'), findsOneWidget);
    });

    testWidgets('"Sync now" is clear of the rule above it', (
      WidgetTester tester,
    ) async {
      // Reported on 2026-09-24 from a real Windows build: the button's top
      // border sat on the grey rule. A `Divider` leaves only its own 8 px below
      // the rule, and unlike the text-only buttons further down this one is
      // filled, so its surface reads as touching. Asserted rather than
      // eyeballed, the same way ROW-5's geometry is (D-M5-6) — a golden would
      // say the picture changed without saying which rule broke.
      final ZenHarness harness = ZenHarness();
      await openSync(tester, harness);

      final Rect buttonRect = tester.getRect(
        find.widgetWithText(FilledButton, 'Sync now'),
      );
      // The rule immediately above the button: of every divider whose bottom
      // edge is above it, the lowest.
      final Finder dividers = find.byType(Divider);
      double ruleBottom = double.negativeInfinity;
      for (int i = 0; i < tester.widgetList<Divider>(dividers).length; i++) {
        final double bottom = tester.getRect(dividers.at(i)).bottom;
        if (bottom <= buttonRect.top && bottom > ruleBottom) {
          ruleBottom = bottom;
        }
      }

      expect(
        ruleBottom,
        greaterThan(double.negativeInfinity),
        reason: 'there is a rule above the button',
      );
      // A literal minimum, **not** `SyncSection.dividerToButtonGap`. Asserting
      // against the constant the layout uses makes the test agree with whatever
      // that constant happens to be: written that way it passed with the gap set
      // to 0, which is the defect this test exists to catch. The number here is
      // the requirement; the constant is one way of meeting it and may exceed
      // it.
      expect(
        buttonRect.top - ruleBottom,
        greaterThanOrEqualTo(12),
        reason: 'the filled button must not sit on the rule above it',
      );
    });

    testWidgets(
      'the last sync time reads "Not synced yet" on a fresh replica',
      (WidgetTester tester) async {
        final ZenHarness harness = ZenHarness();
        await openSync(tester, harness);

        expect(find.textContaining('Not synced yet'), findsOneWidget);
      },
    );
  });

  group('§11.6.3: choosing the sync folder', () {
    testWidgets('picking a folder stores it and switches the transport on', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await openSync(tester, harness);

      await tapItem(tester, find.text('Choose folder…'));

      final Settings settings = await harness.settings.read();
      expect(settings.syncFolderLocation, r'D:\Sync\Zen');
      expect(settings.syncFolderEnabled, isTrue);
      expect(find.text(r'D:\Sync\Zen'), findsOneWidget);
    });

    testWidgets('cancelling the picker changes nothing', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness(
        folderPicker: FakeSyncFolderPicker()..location = null,
      );
      await openSync(tester, harness);

      await tapItem(tester, find.text('Choose folder…'));

      final Settings settings = await harness.settings.read();
      expect(settings.syncFolderLocation, isNull);
      expect(settings.syncFolderEnabled, isFalse);
    });

    testWidgets('forgetting the folder clears it and releases the grant', (
      WidgetTester tester,
    ) async {
      // On Android the released grant is the point: a persisted permission the
      // app holds and no longer uses is one the user did not ask it to keep.
      final ZenHarness harness = ZenHarness();
      await openSync(tester, harness);
      await tapItem(tester, find.text('Choose folder…'));

      await tapItem(tester, find.text('Forget folder'));

      final Settings settings = await harness.settings.read();
      expect(settings.syncFolderLocation, isNull);
      expect(settings.syncFolderEnabled, isFalse);
      expect(harness.folderPicker.released, <String>[r'D:\Sync\Zen']);
    });
  });

  group('§11.8: the interval and foreground settings', () {
    testWidgets('choosing "Never" stores 0, which disables the timer', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await openSync(tester, harness);

      await tapItem(tester, find.text('15 minutes').last);
      await tapItem(tester, find.text('Never').last);

      final Settings settings = await harness.settings.read();
      expect(settings.syncIntervalMinutes, 0);
      expect(settings.syncTimerEnabled, isFalse);
    });

    testWidgets('the foreground toggle writes through (SET-2)', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await openSync(tester, harness);

      await tapItem(
        tester,
        find.widgetWithText(SwitchListTile, 'Sync when Zen opens'),
      );

      expect((await harness.settings.read()).syncOnForeground, isFalse);
    });
  });

  group('§11.6.6: the restore dialog asks before it replaces', () {
    testWidgets('says so plainly when there are no backups', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await openSync(tester, harness);

      await tapAndLoad(tester, find.text('Restore from backup…'));

      expect(find.textContaining('no backups yet'), findsOneWidget);
    });

    testWidgets('choosing a backup asks first, and Cancel changes nothing', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await seedIdea(harness, name: 'Must survive a cancel');
      await tester.runAsync(
        () => harness.container
            .read(backupStoreProvider)
            .writeIfChanged(
              SnapshotEnvelope(
                replicaId: 'replica-local',
                deviceName: 'test-device',
                generatedAt: base,
                appVersion: '1.0.0',
                snapshot: ReplicaSnapshot(replicaId: 'replica-local'),
              ),
            ),
      );
      expect(
        (await tester.runAsync(controllerOf(harness).backups))!,
        hasLength(1),
        reason: 'the backup must exist before the dialog can list it',
      );
      await openSync(tester, harness);

      await tapAndLoad(tester, find.text('Restore from backup…'));
      expect(find.byType(SimpleDialog), findsOneWidget);
      await tapAndLoad(tester, find.byType(SimpleDialogOption).first);

      // §11.6.6: "after an explicit confirmation". This is the one replace in
      // the app, and it is not undoable.
      expect(find.text('Restore this backup?'), findsOneWidget);
      expect(find.textContaining('cannot be undone'), findsOneWidget);

      await tapItem(tester, find.widgetWithText(TextButton, 'Cancel'));

      final List<Idea> ideas = await readStream(
        tester,
        harness.ideas.watchAll(),
      );
      expect(ideas.map((Idea i) => i.name.value), <String>[
        'Must survive a cancel',
      ]);
    });
  });

  group('§11.8: what the commands do', () {
    testWidgets('export produces a readable snapshot of this replica', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await seedIdea(harness, name: 'Learn Dart');

      final String document = (await tester.runAsync(
        controllerOf(harness).exportSnapshot,
      ))!;

      expect(
        const SnapshotCodec()
            .decode(document)
            .unwrap()
            .snapshot
            .ideas
            .single
            .name
            .value,
        'Learn Dart',
      );
    });

    testWidgets('MERGE-3: an exported snapshot carries no settings', (
      WidgetTester tester,
    ) async {
      // The folder location is a per-replica setting. A snapshot carrying it
      // would point the other device at a path that may not exist there.
      final ZenHarness harness = ZenHarness();
      await harness.settings.write(
        Settings(syncFolderEnabled: true, syncFolderLocation: r'D:\Sync\Zen'),
      );

      final String document = (await tester.runAsync(
        controllerOf(harness).exportSnapshot,
      ))!;

      expect(document, isNot(contains('Sync')));
      expect(document, isNot(contains('syncFolderLocation')));
      expect(document, isNot(contains('endOfDay')));
    });

    testWidgets('import merges rather than replacing', (
      WidgetTester tester,
    ) async {
      // "**`"Import snapshot…"` is a merge, never a replace.**" The local Idea
      // must survive and the incoming one must arrive.
      final ZenHarness harness = ZenHarness();
      await seedIdea(harness, name: 'Local idea');

      await tester.runAsync(
        () => controllerOf(harness).importSnapshot(
          snapshotFrom('replica-elsewhere', <Idea>[
            anIdea('idea-incoming', 'Imported idea'),
          ]),
        ),
      );

      final List<Idea> ideas = (await tester.runAsync(
        () => harness.ideas.watchAll().first,
      ))!;
      // MERGE-3A makes Ideas a set; `watchAll` orders them by `createdAt`
      // (IDEAS-4), which is not what this test is about.
      expect(
        ideas.map((Idea i) => i.name.value),
        unorderedEquals(<String>['Local idea', 'Imported idea']),
      );
    });

    testWidgets('import takes a pre-merge backup on the way through', (
      WidgetTester tester,
    ) async {
      // §11.8: "run through the ordinary orchestration of §11.6.5, pre-merge
      // backup included."
      final ZenHarness harness = ZenHarness();
      await seedIdea(harness, name: 'Local idea');

      await tester.runAsync(
        () => controllerOf(harness).importSnapshot(
          snapshotFrom('replica-elsewhere', <Idea>[
            anIdea('idea-incoming', 'Imported idea'),
          ]),
        ),
      );

      expect(
        (await tester.runAsync(controllerOf(harness).backups))!,
        hasLength(1),
      );
    });

    testWidgets('an unreadable import is reported, not applied', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await seedIdea(harness, name: 'Local idea');

      final String message = (await tester.runAsync(
        () => controllerOf(harness).importSnapshot('{ not a snapshot'),
      ))!;

      expect(message, contains('not a Zen snapshot'));
      final List<Idea> ideas = (await tester.runAsync(
        () => harness.ideas.watchAll().first,
      ))!;
      expect(ideas, hasLength(1));
    });

    testWidgets('§11.6.1: an import from a newer format is refused', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await seedIdea(harness, name: 'Local idea');
      final String newer = snapshotFrom('replica-elsewhere', <Idea>[
        anIdea('idea-incoming', 'Imported idea'),
      ]).replaceFirst('"formatVersion": 1', '"formatVersion": 2');

      final String message = (await tester.runAsync(
        () => controllerOf(harness).importSnapshot(newer),
      ))!;

      expect(message, contains('newer version of Zen'));
      expect(
        (await tester.runAsync(() => harness.ideas.watchAll().first))!,
        hasLength(1),
      );
    });

    testWidgets('restoring a backup replaces the dataset', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await seedIdea(harness, name: 'Will be replaced');
      final BackupEntry entry = (await tester.runAsync<BackupEntry?>(
        () => harness.container
            .read(backupStoreProvider)
            .writeIfChanged(
              SnapshotEnvelope(
                replicaId: 'replica-local',
                deviceName: 'test-device',
                generatedAt: base,
                appVersion: '1.0.0',
                snapshot: ReplicaSnapshot(
                  replicaId: 'replica-local',
                  ideas: <Idea>[anIdea('idea-backed-up', 'From the backup')],
                ),
              ),
            ),
      ))!;

      await tester.runAsync(() => controllerOf(harness).restore(entry));

      final List<Idea> ideas = (await tester.runAsync(
        () => harness.ideas.watchAll().first,
      ))!;
      expect(ideas.map((Idea i) => i.name.value), <String>['From the backup']);
    });
  });

  group('§11.6.5: a pass over a real shared folder', () {
    testWidgets('publishes even when there are no peers', (
      WidgetTester tester,
    ) async {
      // The v1.11 correction: without it, "device A finds no peers and writes
      // nothing, device B does the same, and the two never discover each
      // other."
      final ZenHarness harness = ZenHarness();
      await seedIdea(harness, name: 'Learn Dart');
      await enableFolderSync(harness);

      final SyncOutcome outcome = (await tester.runAsync(
        controllerOf(harness).syncNow,
      ))!;

      expect(outcome.published, isTrue);
      expect(outcome.merged, isFalse);
      expect(
        namesIn(harness.syncFolder).where((String n) => n.endsWith('.json')),
        hasLength(1),
      );
    });

    testWidgets('merges a peer snapshot left in the folder', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await seedIdea(harness, name: 'Local idea');
      await enableFolderSync(harness);
      File('${harness.syncFolder.path}/zen-snapshot-replica-elsewhere.json')
          .writeAsStringSync(
            snapshotFrom('replica-elsewhere', <Idea>[
              anIdea('idea-incoming', 'Peer idea'),
            ]),
          );

      final SyncOutcome outcome = (await tester.runAsync(
        controllerOf(harness).syncNow,
      ))!;

      expect(outcome.merged, isTrue);
      expect(outcome.peersMerged, 1);
      expect(outcome.isHealthy, isTrue);
      final List<Idea> ideas = (await tester.runAsync(
        () => harness.ideas.watchAll().first,
      ))!;
      expect(
        ideas.map((Idea i) => i.name.value),
        unorderedEquals(<String>['Local idea', 'Peer idea']),
      );
    });

    testWidgets('§11.6.5 step 7: the published file holds the merged dataset', (
      WidgetTester tester,
    ) async {
      // "Build the envelope from the dataset *after* step 6 rather than from
      // the snapshot taken at step 2."
      final ZenHarness harness = ZenHarness();
      await seedIdea(harness, name: 'Local idea');
      await enableFolderSync(harness);
      File('${harness.syncFolder.path}/zen-snapshot-replica-elsewhere.json')
          .writeAsStringSync(
            snapshotFrom('replica-elsewhere', <Idea>[
              anIdea('idea-incoming', 'Peer idea'),
            ]),
          );

      await tester.runAsync(controllerOf(harness).syncNow);

      final String replicaId = await harness.container
          .read(replicaRepositoryProvider)
          .replicaId();
      final SnapshotEnvelope published = const SnapshotCodec()
          .decode(
            File(
              '${harness.syncFolder.path}/'
              '${FileSnapshotTransport.snapshotFileName(replicaId)}',
            ).readAsStringSync(),
          )
          .unwrap();
      expect(
        published.snapshot.ideas.map((Idea i) => i.name.value),
        unorderedEquals(<String>['Local idea', 'Peer idea']),
      );
    });

    testWidgets('§11.6.5 step 8: the pass records lastSyncAt', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();
      await enableFolderSync(harness);

      await tester.runAsync(controllerOf(harness).syncNow);

      expect(
        (await harness.settings.read()).lastSyncAt,
        harness.clock.nowUtc(),
      );
    });

    testWidgets('a pass with no transport enabled says so and writes nothing', (
      WidgetTester tester,
    ) async {
      final ZenHarness harness = ZenHarness();

      await tester.runAsync(controllerOf(harness).syncNow);

      expect(
        harness.container.read(syncControllerProvider).message,
        'Sync is switched off.',
      );
      expect(namesIn(harness.syncFolder), isEmpty);
    });
  });
}

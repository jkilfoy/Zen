/// §11.6.5. When a sync runs.
///
/// The triggers are easy to leave untested and expensive to get wrong: a timer
/// that silently never fires looks exactly like a folder nobody has touched.
/// `SyncScheduler` takes a callback rather than a `SyncOrchestrator` precisely
/// so the *timing* — the only thing it decides — can be checked here without a
/// database.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_app/src/providers/sync_scheduler.dart';
import 'package:zen_domain/zen_domain.dart';

void main() {
  late List<DateTime> passes;
  late _RecordingSettings settings;
  late SyncScheduler scheduler;

  /// Builds a scheduler over [initial], counting the passes it asks for.
  SyncScheduler schedulerFor(Settings initial) {
    settings = _RecordingSettings(initial);
    scheduler = SyncScheduler(
      sync: () async => passes.add(DateTime.now()),
      settings: settings,
    );
    // `dispose` is also called at the end of each body: `flutter_test` asserts
    // that no timer is pending *before* tearDowns run, so a tearDown alone
    // fails every test that arms one.
    addTearDown(scheduler.dispose);
    return scheduler;
  }

  setUp(() => passes = <DateTime>[]);

  group('§11.6.5: "on app foreground when syncOnForeground"', () {
    testWidgets('a start with the setting on syncs once', (
      WidgetTester tester,
    ) async {
      // The first foreground of a session is the launch.
      await schedulerFor(
        Settings(syncOnForeground: true, syncIntervalMinutes: 0),
      ).start();
      await tester.pump();

      expect(passes, hasLength(1));
    });

    testWidgets('a start with the setting off syncs not at all', (
      WidgetTester tester,
    ) async {
      await schedulerFor(
        Settings(syncOnForeground: false, syncIntervalMinutes: 0),
      ).start();
      await tester.pump();

      expect(passes, isEmpty);
    });

    testWidgets('returning to the foreground syncs again', (
      WidgetTester tester,
    ) async {
      // Through `paused`, because that is what leaving the foreground actually
      // looks like. A bare `resumed` is a focus change, and the group below is
      // about why that must not sync.
      await schedulerFor(
        Settings(syncOnForeground: true, syncIntervalMinutes: 0),
      ).start();
      await tester.pump();

      scheduler.didChangeAppLifecycleState(AppLifecycleState.paused);
      scheduler.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(passes, hasLength(2));
    });

    testWidgets('being backgrounded does not sync', (
      WidgetTester tester,
    ) async {
      await schedulerFor(
        Settings(syncOnForeground: true, syncIntervalMinutes: 0),
      ).start();
      await tester.pump();

      scheduler.didChangeAppLifecycleState(AppLifecycleState.paused);
      scheduler.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await tester.pump();

      // Leaving the foreground is not itself a trigger; only coming back is.
      expect(passes, hasLength(1));
    });

    testWidgets('the setting is re-read, not captured at start', (
      WidgetTester tester,
    ) async {
      // SET-2: a change applies immediately. Turning the trigger off in
      // Settings must stop the next foreground from syncing.
      await schedulerFor(
        Settings(syncOnForeground: true, syncIntervalMinutes: 0),
      ).start();
      await tester.pump();
      await settings.write(
        Settings(syncOnForeground: false, syncIntervalMinutes: 0),
      );

      scheduler.didChangeAppLifecycleState(AppLifecycleState.paused);
      scheduler.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(passes, hasLength(1));
    });
  });

  group('§11.6.5: "on a timer every syncIntervalMinutes"', () {
    testWidgets('the timer fires at the interval, repeatedly', (
      WidgetTester tester,
    ) async {
      await schedulerFor(
        Settings(syncOnForeground: false, syncIntervalMinutes: 15),
      ).start();

      await tester.pump(const Duration(minutes: 15));
      expect(passes, hasLength(1));

      await tester.pump(const Duration(minutes: 15));
      expect(passes, hasLength(2));
      scheduler.dispose();
    });

    testWidgets('nothing fires before the interval has elapsed', (
      WidgetTester tester,
    ) async {
      await schedulerFor(
        Settings(syncOnForeground: false, syncIntervalMinutes: 15),
      ).start();

      await tester.pump(const Duration(minutes: 14, seconds: 59));

      expect(passes, isEmpty);
      scheduler.dispose();
    });

    testWidgets('§11.8: an interval of 0 disables the timer', (
      WidgetTester tester,
    ) async {
      await schedulerFor(
        Settings(syncOnForeground: false, syncIntervalMinutes: 0),
      ).start();

      await tester.pump(const Duration(hours: 6));

      expect(passes, isEmpty);
    });

    testWidgets('changing the interval re-arms at once (SET-2)', (
      WidgetTester tester,
    ) async {
      // Without the re-arm, a new value would not take effect until the old
      // timer fired — up to an hour later, on the longest setting.
      await schedulerFor(
        Settings(syncOnForeground: false, syncIntervalMinutes: 60),
      ).start();

      await settings.write(
        Settings(syncOnForeground: false, syncIntervalMinutes: 5),
      );
      await tester.pump();
      await tester.pump(const Duration(minutes: 5));

      expect(passes, hasLength(1));
      scheduler.dispose();
    });

    testWidgets('setting the interval to 0 stops an armed timer', (
      WidgetTester tester,
    ) async {
      await schedulerFor(
        Settings(syncOnForeground: false, syncIntervalMinutes: 5),
      ).start();

      await settings.write(
        Settings(syncOnForeground: false, syncIntervalMinutes: 0),
      );
      await tester.pump();
      await tester.pump(const Duration(hours: 6));

      expect(passes, isEmpty);
    });

    testWidgets('dispose stops the timer', (WidgetTester tester) async {
      await schedulerFor(
        Settings(syncOnForeground: false, syncIntervalMinutes: 5),
      ).start();

      scheduler.dispose();
      await tester.pump(const Duration(hours: 6));

      expect(passes, isEmpty);
    });
  });

  group('a focus change is not a foreground', () {
    testWidgets('inactive then resumed does not sync', (
      WidgetTester tester,
    ) async {
      // Reported from a real Windows build on 2026-09-24: "the sync appeared to
      // be occurring without pressing Sync now very frequently (seems like all
      // the time)". On desktop, losing and regaining window focus produces
      // `inactive` then `resumed` — so every click back into the window was a
      // full pass. §11.6.5 means a genuine foreground, not a focus flicker.
      await schedulerFor(
        Settings(syncOnForeground: true, syncIntervalMinutes: 0),
      ).start();
      await tester.pump();
      expect(passes, hasLength(1), reason: 'the launch is a foreground');

      for (int flicker = 0; flicker < 5; flicker++) {
        scheduler.didChangeAppLifecycleState(AppLifecycleState.inactive);
        scheduler.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await tester.pump();
        await tester.pump();
      }

      expect(passes, hasLength(1));
    });

    testWidgets('being hidden and then resumed does sync', (
      WidgetTester tester,
    ) async {
      // Minimising on Windows, and backgrounding on Android, both pass through
      // `hidden`. That is a real foreground when it comes back.
      await schedulerFor(
        Settings(syncOnForeground: true, syncIntervalMinutes: 0),
      ).start();
      await tester.pump();

      scheduler.didChangeAppLifecycleState(AppLifecycleState.inactive);
      scheduler.didChangeAppLifecycleState(AppLifecycleState.hidden);
      scheduler.didChangeAppLifecycleState(AppLifecycleState.inactive);
      scheduler.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(passes, hasLength(2));
    });

    testWidgets('being paused and then resumed does sync', (
      WidgetTester tester,
    ) async {
      await schedulerFor(
        Settings(syncOnForeground: true, syncIntervalMinutes: 0),
      ).start();
      await tester.pump();

      scheduler.didChangeAppLifecycleState(AppLifecycleState.paused);
      scheduler.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(passes, hasLength(2));
    });
  });

  group('the interval timer is not reset by unrelated settings writes', () {
    testWidgets('a lastSyncAt write does not push the next pass back', (
      WidgetTester tester,
    ) async {
      // §11.6.5 step 8 writes `lastSyncAt` after *every* pass, and that emits on
      // the settings stream. Re-arming on every emission meant the 15-minute
      // timer was reset by each sync, so the interval never governed anything.
      await schedulerFor(
        Settings(syncOnForeground: false, syncIntervalMinutes: 15),
      ).start();

      await tester.pump(const Duration(minutes: 10));
      await settings.write(
        Settings(
          syncOnForeground: false,
          syncIntervalMinutes: 15,
          lastSyncAt: DateTime.utc(2026, 9, 24, 12),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(minutes: 5));

      expect(passes, hasLength(1));
      scheduler.dispose();
    });
  });

  group('NFR-1: nothing a trigger does reaches the user', () {
    testWidgets('a pass that throws does not escape the scheduler', (
      WidgetTester tester,
    ) async {
      // The orchestrator catches what it can name; this absorbs the rest. An
      // unhandled error from a background timer is a crash the user did not ask
      // for and cannot act on.
      final SyncScheduler throwing = SyncScheduler(
        sync: () async => throw StateError('the folder went away'),
        settings: _RecordingSettings(
          Settings(syncOnForeground: true, syncIntervalMinutes: 5),
        ),
      );
      addTearDown(throwing.dispose);

      await throwing.start();
      await tester.pump();
      await tester.pump(const Duration(minutes: 5));
      await tester.pump();
      throwing.dispose();

      expect(tester.takeException(), isNull);
    });
  });
}

/// A [SettingsRepository] whose stream emits each write, so the scheduler's
/// re-arm can be driven from a test.
final class _RecordingSettings implements SettingsRepository {
  _RecordingSettings(this._settings);

  Settings _settings;
  final StreamController<Settings> _changes =
      StreamController<Settings>.broadcast();

  @override
  Stream<Settings> watch() => _changes.stream;

  @override
  Future<Settings> read() async => _settings;

  @override
  Future<void> write(Settings settings) async {
    _settings = settings;
    _changes.add(settings);
  }
}

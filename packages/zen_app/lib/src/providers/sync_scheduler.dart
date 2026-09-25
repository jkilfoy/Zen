/// §11.6.5. When a sync runs, as opposed to what it does.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:zen_domain/zen_domain.dart';

/// §11.6.5. "Triggers: manual `"Sync now"` on both platforms; on app foreground
/// when `syncOnForeground`; and on a timer every `syncIntervalMinutes` while the
/// app is open."
///
/// This owns the second and third. The first is the Settings button. All three
/// end at [SyncOrchestrator.sync], which holds the single-flight lock, so they
/// cannot overlap however they are combined.
///
/// **No trigger may block the UI** (§11.6.5, NFR-1), so nothing here is awaited
/// by anything the user is waiting on, and a failed pass is swallowed — the
/// orchestrator has already recorded it, and the Settings screen is where it is
/// reported.
///
/// The same shape as `ArchiveScheduler` (EOD-3), for the same reason: the
/// *policy* is in the specification and the *timing* needs the app lifecycle,
/// which no other layer can see.
final class SyncScheduler with WidgetsBindingObserver {
  /// Schedules passes of [sync] according to [settings].
  ///
  /// [sync] rather than a `SyncOrchestrator`: all this needs is "run a pass",
  /// the orchestrator's own single-flight lock is what keeps the triggers from
  /// overlapping, and taking the narrower dependency is what lets the *timing* —
  /// the only thing this class decides — be tested without a database.
  SyncScheduler({
    required Future<void> Function() sync,
    required SettingsRepository settings,
    // A named parameter may not begin with an underscore.
    // ignore: prefer_initializing_formals
  }) : _sync = sync,
       // ignore: prefer_initializing_formals
       _settings = settings;

  final Future<void> Function() _sync;
  final SettingsRepository _settings;

  Timer? _timer;
  StreamSubscription<Settings>? _watch;
  bool _disposed = false;

  /// The interval the current [_timer] was armed with, so that a settings write
  /// which did not change it leaves the timer alone.
  int _armedInterval = 0;

  /// Whether the app has genuinely left the foreground since the last resume.
  ///
  /// False at construction: the launch itself counts as a foreground, and
  /// [start] handles that one directly.
  bool _leftForeground = false;

  /// Starts watching the lifecycle and the settings, and syncs if
  /// `syncOnForeground` is set.
  ///
  /// The app start counts as a foreground: §11.6.5 lists "on app foreground" as
  /// a trigger, and the first foreground of a session is the launch.
  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    final Settings current = await _settings.read();
    _arm(current.syncIntervalMinutes);

    // Re-armed when the interval changes, so that a new value in Settings takes
    // effect at once (SET-2) rather than after the old timer fires — but *only*
    // when it changes. §11.6.5 step 8 writes `lastSyncAt` after every pass, and
    // that emits here too; re-arming on every emission reset the timer on every
    // sync, so the interval never governed anything.
    _watch = _settings.watch().listen((Settings next) {
      if (next.syncIntervalMinutes != _armedInterval) {
        _arm(next.syncIntervalMinutes);
      }
    });

    if (current.syncOnForeground) {
      _syncQuietly();
    }
  }

  /// §11.6.5. "On app foreground when `syncOnForeground`."
  ///
  /// **A focus change is not a foreground.** On Windows, clicking away from the
  /// window and back produces `inactive` then `resumed`, so treating every
  /// `resumed` as a foreground made a full sync pass run on every click back
  /// into the app — which is what it looked like, reported from a real build as
  /// syncing "seems like all the time" regardless of `syncIntervalMinutes`.
  ///
  /// A genuine departure from the foreground passes through `hidden`, `paused`
  /// or `detached` on both platforms: minimising on Windows, backgrounding on
  /// Android. `inactive` alone is a focus flicker, a menu, or a dialog, and the
  /// app never stopped being on screen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) {
      return;
    }
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _leftForeground = true;
      case AppLifecycleState.inactive:
        // Deliberately nothing. The app is still on screen.
        break;
      case AppLifecycleState.resumed:
        if (!_leftForeground) {
          return;
        }
        _leftForeground = false;
        unawaited(
          _settings.read().then((Settings current) {
            if (current.syncOnForeground) {
              _syncQuietly();
            }
          }),
        );
    }
  }

  /// Stops the timer and the lifecycle observer.
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    unawaited(_watch?.cancel());
    WidgetsBinding.instance.removeObserver(this);
  }

  /// §11.8. "`0` disables."
  void _arm(int intervalMinutes) {
    _timer?.cancel();
    _armedInterval = intervalMinutes;
    if (_disposed || intervalMinutes <= 0) {
      _timer = null;
      return;
    }
    _timer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (Timer _) => _syncQuietly(),
    );
  }

  /// Runs a pass without anyone waiting on it or hearing about a failure.
  ///
  /// The orchestrator already catches every transport failure and records it in
  /// its outcome (§11.6.5 step 3), so what this absorbs is the unexpected — and
  /// even then, NFR-1 is explicit that capture must remain usable regardless.
  void _syncQuietly() {
    unawaited(_sync().catchError((Object _) {}));
  }
}

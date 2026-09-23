/// §4.5, §11.5.4. The archive sweep.
library;

import 'package:zen_domain/zen_domain.dart';

/// EOD-3, §11.5.4. Archives every Task whose End-of-Day boundary has passed.
///
/// §11.5.4: "It runs on app start, on foreground, and on a timer that fires at
/// the next boundary while the app runs." This class is the first two and the
/// arithmetic for the third; *scheduling* the timer needs the app lifecycle and
/// belongs to `zen_app` (M4), which calls [sweep] and [nextBoundaryAfter].
///
/// It reads `endOfDay` and the zone and hands both to the repository, which
/// takes every time input as an explicit parameter rather than reaching for a
/// clock of its own (§11.5.4). Because the boundary is derived from
/// `completedAt` rather than from when the sweep last ran, a device closed
/// across several boundaries archives correctly on next start with no catch-up
/// loop (AC-6).
final class ArchiveSweeper {
  /// Creates a sweeper over [tasks].
  const ArchiveSweeper({
    required Clock clock,
    required TimeZoneRules zone,
    required SettingsRepository settings,
    required TaskRepository tasks,
    // `prefer_initializing_formals` suggests `this._clock` and friends, which
    // Dart forbids: a named parameter may not begin with an underscore. Hence
    // the ignore on each line below.
    // ignore: prefer_initializing_formals
  }) : _clock = clock,
       // ignore: prefer_initializing_formals
       _zone = zone,
       // ignore: prefer_initializing_formals
       _settings = settings,
       // ignore: prefer_initializing_formals
       _tasks = tasks;

  final Clock _clock;
  final TimeZoneRules _zone;
  final SettingsRepository _settings;
  final TaskRepository _tasks;

  /// EOD-2, EOD-3. Archives what is due, and returns it.
  ///
  /// Idempotent, so running it at start, on foreground and at each boundary
  /// costs nothing extra. EOD-5 reads the zone at each sweep rather than
  /// caching it, because a device can travel.
  Future<List<Task>> sweep() async {
    final Settings settings = await _settings.read();
    return _tasks.runArchiveSweep(
      nowUtc: _clock.nowUtc(),
      endOfDay: settings.endOfDay,
      zoneId: _clock.localZoneId(),
    );
  }

  /// EOD-3. The next boundary instant after [afterUtc], for scheduling.
  ///
  /// The same calculation the sweep itself uses, so a timer set from this fires
  /// exactly when a Task completed now would become due.
  Future<DateTime> nextBoundaryAfter(DateTime afterUtc) async {
    final Settings settings = await _settings.read();
    return archiveBoundaryAfter(
      afterUtc,
      settings.endOfDay,
      _clock.localZoneId(),
      _zone,
    );
  }
}

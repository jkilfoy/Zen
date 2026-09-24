/// EOD-3, §11.5.4, D-M3-14. Running the archive sweep against the app
/// lifecycle.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:zen_data/zen_data.dart';
import 'package:zen_domain/zen_domain.dart';

/// EOD-3. "The archive sweep MUST run at app start, when the app returns to the
/// foreground, and at each EoD boundary while the app is running."
///
/// D-M3-14 left this to M4 because it needs the app lifecycle. The arithmetic
/// is `ArchiveSweeper`'s; all this adds is *when*. It holds no rule of its own,
/// so there is nothing here for `zen_domain` to own.
///
/// "A replica that was closed across one or more boundaries MUST archive
/// correctly on its next start" needs no catch-up loop: the boundary comes from
/// each Task's own `completedAt`, so one sweep clears every missed day at once
/// (§11.5.4, AC-6).
final class ArchiveScheduler with WidgetsBindingObserver {
  /// Schedules [sweeper]'s sweeps, reading the current instant from [clock].
  ArchiveScheduler({required ArchiveSweeper sweeper, required Clock clock})
    // ignore: prefer_initializing_formals
    : _sweeper = sweeper,
      // ignore: prefer_initializing_formals
      _clock = clock;

  /// The shortest timer this will set.
  ///
  /// `nextBoundaryAfter` returns an instant strictly after the one it is given,
  /// so the delay is always positive — but it can be a millisecond, and a timer
  /// that short risks re-firing before the sweep it triggered has committed.
  static const Duration _minimumDelay = Duration(seconds: 1);

  final ArchiveSweeper _sweeper;
  final Clock _clock;

  Timer? _timer;
  bool _disposed = false;

  /// EOD-3, first trigger. Sweeps now and arms the boundary timer.
  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    await sweepAndReschedule();
  }

  /// EOD-3, second trigger: "when the app returns to the foreground".
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(sweepAndReschedule());
    }
  }

  /// EOD-3, third trigger. Sweeps, then re-arms for the next boundary.
  ///
  /// Rescheduling after every sweep rather than on a fixed period is what makes
  /// EOD-4 work: a change to `settings.endOfDay` moves the next boundary, and
  /// the timer is derived from the setting each time rather than cached.
  Future<void> sweepAndReschedule() async {
    if (_disposed) {
      return;
    }
    await _sweeper.sweep();
    if (_disposed) {
      return;
    }
    final DateTime now = _clock.nowUtc();
    final DateTime next = await _sweeper.nextBoundaryAfter(now);
    _timer?.cancel();
    if (_disposed) {
      return;
    }
    final Duration delay = next.difference(now);
    _timer = Timer(
      delay < _minimumDelay ? _minimumDelay : delay,
      () => unawaited(sweepAndReschedule()),
    );
  }

  /// Cancels the timer and stops observing the lifecycle.
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }
}

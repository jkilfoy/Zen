/// Zen's entry point: open the database, then run the app.
///
/// §11.1 makes this the composition root. It is the only file that reads the
/// wall clock, touches the file system or asks the platform anything; every
/// other file receives what it needs through a provider (§11.7).
///
/// NAV-3: "Cold start MUST open the Home screen directly, with no splash or
/// loading screen beyond platform minimums." The database and the settings are
/// therefore read *before* `runApp`, so the first frame is already the Home
/// screen with the right theme, rather than a spinner that resolves into one.
library;

import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:zen_data/zen_data.dart';
import 'package:zen_domain/zen_domain.dart';

import 'src/app.dart';
import 'src/providers/app_providers.dart';
import 'src/providers/archive_scheduler.dart';
import 'src/providers/system_clock.dart';
import 'src/screens/unreadable_database_screen.dart';

/// STORE-1. "Each replica owns one local database."
const String databaseFileName = 'zen.sqlite';

/// EOD-5. What the zone is taken to be if the platform will not say.
///
/// A wrong zone moves the End-of-Day boundary, so this is a last resort rather
/// than a default: `flutter_timezone` answers on both target platforms, and
/// falling back is preferable to refusing to start (§11.5.5's posture).
const String fallbackZoneId = 'UTC';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final Directory directory = await getApplicationSupportDirectory();
  final String path = p.join(directory.path, databaseFileName);
  final String zoneId = await _localZoneId();
  final Clock clock = SystemClock(zoneId: zoneId);

  final OpenOutcome outcome = await openDatabase(
    path: path,
    nowUtc: clock.nowUtc(),
  );

  switch (outcome) {
    // §11.5.5. Nothing was destroyed; say so and offer the ways back.
    case DatabaseUnreadable():
      runApp(UnreadableDatabaseApp(outcome));

    case DatabaseOpened(:final AppDatabase database):
      final SettingsRepository settingsRepository = DriftSettingsRepository(
        database,
      );
      final Settings settings = await settingsRepository.read();

      // §11.5.1. "On each app start, delete entries older than 365 days,
      // keeping at least the most recent 5,000 regardless of age."
      unawaited(DriftEventLog(database).prune(clock.nowUtc()));

      final ProviderContainer container = ProviderContainer(
        // `Override` is not part of Riverpod 3's public export list, so the
        // list's type is inferred from the parameter rather than written out.
        overrides: [
          databaseProvider.overrideWithValue(database),
          localZoneIdProvider.overrideWithValue(zoneId),
          initialSettingsProvider.overrideWithValue(settings),
          deviceNameProvider.overrideWithValue(await _deviceName()),
        ],
      );

      // EOD-3. Sweep at start, on foreground, and at each boundary.
      final ArchiveScheduler scheduler = ArchiveScheduler(
        sweeper: ArchiveSweeper(
          clock: container.read(clockProvider),
          zone: container.read(timeZoneRulesProvider),
          settings: container.read(settingsRepositoryProvider),
          tasks: container.read(taskRepositoryProvider),
        ),
        clock: container.read(clockProvider),
      );
      await scheduler.start();

      runApp(
        UncontrolledProviderScope(container: container, child: const ZenApp()),
      );
  }
}

/// EOD-5. The device's IANA zone, e.g. `America/St_Johns`.
Future<String> _localZoneId() async {
  try {
    // `getLocalTimezone` returns the platform's whole answer; the IANA
    // identifier is the part `TimeZoneRules` takes (§11.4.3).
    return (await FlutterTimezone.getLocalTimezone()).identifier;
  } on Object {
    return fallbackZoneId;
  }
}

/// §11.5.1, D-M3-15. The name this installation is known by when pairing.
Future<String> _deviceName() async {
  final DeviceInfoPlugin info = DeviceInfoPlugin();
  try {
    if (Platform.isAndroid) {
      final AndroidDeviceInfo android = await info.androidInfo;
      return android.model;
    }
    if (Platform.isWindows) {
      final WindowsDeviceInfo windows = await info.windowsInfo;
      return windows.computerName;
    }
  } on Object {
    // Falls through to the generic name below: a device without a name is a
    // worse outcome than a device named after its platform.
  }
  return Platform.operatingSystem;
}

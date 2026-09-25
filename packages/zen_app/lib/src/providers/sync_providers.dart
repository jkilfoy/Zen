/// §11.6.5, §11.8. The sync layer's composition root.
///
/// Thin, like every other provider file (§11.7): these construct `zen_sync`'s
/// objects and hand them their dependencies. The orchestration itself is
/// `SyncOrchestrator`'s, the transports' behaviour is `zen_sync`'s, and neither
/// has any idea Riverpod exists (§11.1).
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zen_data/zen_data.dart';
import 'package:zen_domain/zen_domain.dart';
import 'package:zen_sync/zen_sync.dart';

import '../sync/saf_snapshot_directory.dart';
import '../sync/snapshot_file_exchange.dart';
import '../sync/sync_folder_picker.dart';
import 'app_providers.dart';

/// This build's version, for the snapshot envelope (§11.6.1). Overridden in
/// `main.dart` from `package_info_plus`.
final Provider<String> appVersionProvider = Provider<String>(
  (Ref ref) => throw UnimplementedError(
    'appVersionProvider is overridden in main() with the package version',
  ),
);

/// §11.6.6. The directory holding `backups/`, in application-private storage.
///
/// Overridden in `main.dart` from `path_provider`. Unlike the sync folder this
/// is the app's own space, so `dart:io` reaches it on both platforms — Android's
/// scoped-storage rules govern the user's folders, not the app's.
final Provider<String> backupDirectoryProvider = Provider<String>(
  (Ref ref) => throw UnimplementedError(
    'backupDirectoryProvider is overridden in main() with the app support dir',
  ),
);

/// §11.7. The one folder picker, platform chosen here so no screen branches.
final Provider<SyncFolderPicker> syncFolderPickerProvider =
    Provider<SyncFolderPicker>(
      (Ref ref) => Platform.isAndroid
          ? AndroidSyncFolderPicker()
          : const DesktopSyncFolderPicker(),
    );

/// §11.8. The one-file export and import, platform chosen here.
final Provider<SnapshotFileExchange> snapshotFileExchangeProvider =
    Provider<SnapshotFileExchange>(
      (Ref ref) => Platform.isAndroid
          ? AndroidSnapshotFileExchange()
          : const DesktopSnapshotFileExchange(),
    );

/// §11.6.6. Reads, writes and prunes the pre-merge backups.
final Provider<BackupStore> backupStoreProvider = Provider<BackupStore>(
  (Ref ref) => BackupStore(
    directoryPath: '${ref.watch(backupDirectoryProvider)}/backups',
  ),
);

/// §11.4.6, STORE-4. Replaces the dataset wholesale, for a merge and a restore.
final Provider<DatasetRepository> datasetRepositoryProvider =
    Provider<DatasetRepository>(
      (Ref ref) => DriftDatasetRepository(ref.watch(databaseProvider)),
    );

/// §9.1. The merge rule, "chosen through dependency injection".
final Provider<MergeStrategy> mergeStrategyProvider = Provider<MergeStrategy>(
  (Ref ref) => const NameUnionMergeStrategy(),
);

/// §11.6.3. Where this package's warnings go.
///
/// `debugPrint` rather than `print`: it is rate-limited, which matters because
/// a folder full of unreadable files logs one line each, every pass.
final Provider<SyncLogger> syncLoggerProvider = Provider<SyncLogger>(
  (Ref ref) =>
      (String message) => debugPrint('[sync] $message'),
);

/// §11.6.3. Builds the file transport for [location], or `null` if there is
/// none configured.
///
/// The platform decides only how the folder is *reached*: `IoSnapshotDirectory`
/// on Windows, `SafSnapshotDirectory` on Android. `FileSnapshotTransport` is
/// the same object either way (§11.6.3).
SnapshotDirectory _snapshotDirectory(String location) => Platform.isAndroid
    ? SafSnapshotDirectory(location)
    : IoSnapshotDirectory(location);

/// §11.6.5 step 3. The transports that are switched on right now.
///
/// §11.8's `syncFolderEnabled` and `syncLanEnabled` decide this, read fresh on
/// every pass so that turning a transport off takes effect at once (SET-2).
/// `syncLanEnabled` builds nothing yet: `LanSyncTransport` is M7, and the
/// orchestrator is already n-ary and multi-transport, so M7 adds an
/// implementation to this list and nothing else (§11.6.5).
final Provider<EnabledTransports> enabledTransportsProvider =
    Provider<EnabledTransports>((Ref ref) {
      final SettingsRepository settings = ref.watch(settingsRepositoryProvider);
      final ReplicaRepository replicas = ref.watch(replicaRepositoryProvider);
      final SyncLogger log = ref.watch(syncLoggerProvider);

      return () async {
        final Settings current = await settings.read();
        final String location = current.syncFolderLocation ?? '';
        if (!current.syncFolderEnabled || location.isEmpty) {
          return const <SyncTransport>[];
        }
        return <SyncTransport>[
          FileSnapshotTransport(
            directory: _snapshotDirectory(location),
            replicaId: await replicas.replicaId(),
            log: log,
          ),
        ];
      };
    });

/// §11.6.5. The one orchestrator, holding the single-flight lock.
///
/// A `Provider` rather than anything rebuilt per call, because step 1's lock
/// lives on the instance: a fresh orchestrator per sync would let two passes
/// run at once, which is the thing the lock exists to prevent.
final Provider<SyncOrchestrator> syncOrchestratorProvider =
    Provider<SyncOrchestrator>(
      (Ref ref) => SyncOrchestrator(
        enabledTransports: ref.watch(enabledTransportsProvider),
        replicas: ref.watch(replicaRepositoryProvider),
        ideas: ref.watch(ideaRepositoryProvider),
        tasks: ref.watch(taskRepositoryProvider),
        tombstones: ref.watch(tombstoneStoreProvider),
        dataset: ref.watch(datasetRepositoryProvider),
        settings: ref.watch(settingsRepositoryProvider),
        events: ref.watch(eventLogProvider),
        mergeStrategy: ref.watch(mergeStrategyProvider),
        backups: ref.watch(backupStoreProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
        appVersion: ref.watch(appVersionProvider),
        log: ref.watch(syncLoggerProvider),
      ),
    );

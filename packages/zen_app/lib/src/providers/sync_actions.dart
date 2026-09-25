/// §11.8. The commands the `"Sync"` settings section invokes.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zen_domain/zen_domain.dart';
import 'package:zen_sync/zen_sync.dart';

import 'app_providers.dart';
import 'sync_providers.dart';

/// §11.8. What the Sync section shows between passes.
@immutable
final class SyncState {
  /// Creates a state.
  const SyncState({this.running = false, this.outcome, this.message});

  /// Whether a pass is in flight, for the `"Sync now"` spinner.
  final bool running;

  /// §11.6.5 step 8. The last completed pass, or `null` if none has run in this
  /// session. `lastSyncAt` in settings is what survives a restart; this carries
  /// the detail the settings row cannot.
  final SyncOutcome? outcome;

  /// A one-line result for the user — the outcome of the last action, whether
  /// that was a sync, an import or a restore.
  final String? message;

  /// Returns a copy with the given fields replaced.
  SyncState copyWith({bool? running, SyncOutcome? outcome, String? message}) =>
      SyncState(
        running: running ?? this.running,
        outcome: outcome ?? this.outcome,
        message: message ?? this.message,
      );
}

/// §11.8. The Sync section's commands.
///
/// Thin, per §11.7: each method calls `zen_sync` or a repository and reports
/// what came back. **No rule lives here** — the orchestration is §11.6.5's and
/// the merge is `zen_domain`'s.
final class SyncController extends Notifier<SyncState> {
  @override
  SyncState build() => const SyncState();

  /// §11.6.5. `"Sync now"`, and the foreground and timer triggers.
  ///
  /// "**No trigger may block the UI**, and a sync failure is never surfaced as
  /// a blocking dialog — capture must remain usable regardless (NFR-1)." The
  /// result goes into [state] for the Settings screen to render; nothing here
  /// throws at the caller or opens a dialog.
  Future<SyncOutcome> syncNow() async {
    state = state.copyWith(running: true);
    try {
      final SyncOutcome outcome = await ref
          .read(syncOrchestratorProvider)
          .sync();
      state = SyncState(
        outcome: outcome,
        message: _describe(outcome, lanServes: await _lanServes()),
      );
      return outcome;
    } on Object {
      // The orchestrator catches everything it can name and reports it in the
      // outcome, so reaching here means something genuinely unforeseen. Belt
      // and braces all the same: without this, `running` would stay true and
      // the section would show a spinner that never stops.
      state = state.copyWith(
        running: false,
        message: 'Sync could not run. Your data is unchanged.',
      );
      rethrow;
    }
  }

  /// §11.6.3, §11.8. Picks the sync folder and stores it.
  ///
  /// Returns false if the user cancelled. Enabling the transport is left to the
  /// caller: picking a folder and switching sync on are two decisions, and
  /// §11.8 gives them two controls.
  Future<bool> chooseFolder() async {
    final String? location = await ref.read(syncFolderPickerProvider).pick();
    if (location == null) {
      return false;
    }
    final SettingsRepository settings = ref.read(settingsRepositoryProvider);
    await settings.write(
      (await settings.read()).copyWith(syncFolderLocation: location),
    );
    return true;
  }

  /// §11.8. Forgets the sync folder and gives up the platform grant.
  ///
  /// Releasing the grant matters on Android: a persisted permission the app
  /// holds and no longer uses is a permission the user did not ask it to keep.
  Future<void> forgetFolder() async {
    final SettingsRepository settings = ref.read(settingsRepositoryProvider);
    final Settings current = await settings.read();
    final String? location = current.syncFolderLocation;
    if (location != null) {
      await ref.read(syncFolderPickerProvider).release(location);
    }
    await settings.write(
      current.copyWith(syncFolderEnabled: false).withoutSyncFolder(),
    );
  }

  /// §11.8. Writes one sync setting.
  Future<void> update(Settings Function(Settings) change) async {
    final SettingsRepository settings = ref.read(settingsRepositoryProvider);
    await settings.write(change(await settings.read()));
  }

  /// §11.6.6. The backups `"Restore from backup…"` lists, newest first.
  Future<List<BackupEntry>> backups() => ref.read(backupStoreProvider).list();

  /// §11.6.6, §11.8. Restores [entry], **replacing** the dataset.
  ///
  /// "`"Restore from backup…"` is the replace, and it is the only one." The
  /// confirmation §11.6.6 requires is the screen's; by the time this is called
  /// the user has given it.
  Future<String> restore(BackupEntry entry) async {
    final Result<SnapshotEnvelope, SnapshotFormatFailure> read = await ref
        .read(backupStoreProvider)
        .read(entry);
    return switch (read) {
      Err<SnapshotEnvelope, SnapshotFormatFailure>(
        error: final SnapshotFormatFailure failure,
      ) =>
        _report(failure.message),
      Ok<SnapshotEnvelope, SnapshotFormatFailure>(
        value: final SnapshotEnvelope envelope,
      ) =>
        await _applyRestore(envelope),
    };
  }

  Future<String> _applyRestore(SnapshotEnvelope envelope) async {
    await ref.read(datasetRepositoryProvider).replaceAll(envelope.snapshot);
    return _report(
      'Restored ${envelope.snapshot.ideas.length} ideas and '
      '${envelope.snapshot.tasks.length} tasks.',
    );
  }

  /// §11.8. `"Import snapshot…"`.
  ///
  /// "**`"Import snapshot…"` is a merge, never a replace.** The chosen file is
  /// treated as one more peer snapshot and run through the ordinary
  /// orchestration of §11.6.5, pre-merge backup included. A replace would be
  /// destructive and irreversible, and nothing in the UI warns that it would
  /// be."
  Future<String> importSnapshot(String contents) async {
    final SyncLogger log = ref.read(syncLoggerProvider);
    final Result<SnapshotEnvelope, SnapshotFormatFailure> decoded =
        SnapshotCodec(log: log).decode(contents);
    if (decoded case Err<SnapshotEnvelope, SnapshotFormatFailure>(
      error: final SnapshotFormatFailure failure,
    )) {
      return _report(failure.message);
    }
    final SnapshotEnvelope envelope = decoded.unwrap();

    // The same path a peer takes: back up, merge, apply, append the events.
    // Going through the orchestrator rather than reimplementing step 4 to 6
    // here is what keeps an import and a sync the same operation.
    final SyncOutcome outcome = await ref
        .read(syncOrchestratorProvider)
        .syncWith(<SnapshotEnvelope>[envelope]);
    state = SyncState(
      outcome: outcome,
      message: _describe(outcome, lanServes: await _lanServes()),
    );
    return state.message!;
  }

  /// §11.8. The document `"Export snapshot…"` writes.
  Future<String> exportSnapshot() async {
    final ReplicaRepository replicas = ref.read(replicaRepositoryProvider);
    return const SnapshotCodec().encode(
      SnapshotEnvelope(
        replicaId: await replicas.replicaId(),
        deviceName: await replicas.deviceName(),
        generatedAt: ref.read(clockProvider).nowUtc(),
        appVersion: ref.read(appVersionProvider),
        snapshot: ReplicaSnapshot(
          replicaId: await replicas.replicaId(),
          ideas: await ref.read(ideaRepositoryProvider).watchAll().first,
          tasks: await ref.read(taskRepositoryProvider).watchAll().first,
          tombstones: await ref.read(tombstoneStoreProvider).all(),
        ),
      ),
    );
  }

  String _report(String message) {
    state = state.copyWith(message: message);
    return message;
  }

  /// §11.6.4. Whether this device serves LAN sync rather than initiating it.
  ///
  /// The desktop registers no LAN transport (§11.6.4), so a pass with LAN on
  /// and the folder off has nothing to send — which is correct, and which
  /// [_describe] must not report as sync being switched off while the section
  /// above it says the server is listening.
  Future<bool> _lanServes() async =>
      !ref.read(isLanClientProvider) &&
      (await ref.read(settingsRepositoryProvider).read()).syncLanEnabled;

  /// §11.6.5 step 8. One line describing a pass, for the Settings status row.
  static String _describe(SyncOutcome outcome, {required bool lanServes}) {
    if (outcome.transports.isEmpty) {
      // §11.6.4: "only the phone can initiate". On the PC that is the design,
      // not a misconfiguration, so it reads as an explanation rather than a
      // complaint.
      return lanServes
          ? 'Your phone starts LAN syncs. There is nothing to send from here.'
          : 'Sync is switched off.';
    }
    final List<String> failures = <String>[
      for (final TransportOutcome t in outcome.transports)
        if (!t.isHealthy && t.reason.isNotEmpty) t.reason,
    ];
    if (failures.isNotEmpty) {
      return failures.first;
    }
    if (outcome.mergeFailure != null) {
      return 'Synced, but the changes could not be applied. Your data is '
          'unchanged.';
    }
    if (!outcome.merged) {
      final bool unavailable = outcome.transports.every(
        (TransportOutcome t) => t.fetch == SyncFetchStatus.unavailable,
      );
      // §11.6.5 step 3: a pass that merges nothing still published, and that is
      // a success — "publishing is the only thing that makes this device
      // visible to the others".
      return unavailable ? 'Sync folder not available' : 'Nothing to sync.';
    }
    final int merged = outcome.report!.components.length;
    return merged == 0
        ? 'Synced with ${outcome.peersMerged} device'
              '${outcome.peersMerged == 1 ? '' : 's'}.'
        : 'Synced. $merged item${merged == 1 ? '' : 's'} were combined.';
  }
}

/// §11.8. The Sync section's state and commands.
final NotifierProvider<SyncController, SyncState> syncControllerProvider =
    NotifierProvider<SyncController, SyncState>(SyncController.new);

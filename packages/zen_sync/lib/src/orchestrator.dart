/// §11.6.5. One sync pass over every enabled transport.
///
// `prefer_initializing_formals` fires on every one of the fourteen fields this
// orchestrator is constructed with: it suggests `this._replicas` and friends,
// which Dart forbids, because a named parameter may not begin with an
// underscore. `ArchiveSweeper` ignores it per line; at fourteen that would bury
// the constructor, so it is ignored once here instead.
// ignore_for_file: prefer_initializing_formals
library;

import 'dart:async';

import 'package:zen_domain/zen_domain.dart';

import 'backup/backup_store.dart';
import 'peer_collection.dart';
import 'snapshot/snapshot_envelope.dart';
import 'sync_log.dart';
import 'sync_outcome.dart';
import 'transport/sync_transport.dart';

/// §11.6.5. Supplies the transports that are switched on right now.
///
/// §11.8's `syncFolderEnabled` and `syncLanEnabled` decide this, and they can
/// change between passes. Injected as a function so the orchestrator needs to
/// know neither the settings keys nor which transport is which — §11.6.5 runs
/// them all together, and nothing here may special-case one by [SyncTransport.id].
typedef EnabledTransports = Future<List<SyncTransport>> Function();

/// §11.6.5. Runs one sync pass: collect, merge, apply, publish.
///
/// **One orchestrator handles all enabled transports together**, in a single
/// pass. "Both transports may be enabled at once (A2), and the merge is n-ary
/// (MERGE-1), so peers from different transports are simply more inputs to one
/// merge rather than a reason to sync twice." Adding `LanSyncTransport` in M7
/// therefore adds an implementation and nothing else.
///
/// Nothing here throws at its caller. §11.6.5 forbids a failing transport from
/// aborting the pass, and NFR-1 forbids a sync failure from getting in the way
/// of capture, so every failure is caught, recorded in the [SyncOutcome] and
/// logged.
final class SyncOrchestrator {
  /// Wires the orchestrator to its collaborators.
  SyncOrchestrator({
    required EnabledTransports enabledTransports,
    required ReplicaRepository replicas,
    required IdeaRepository ideas,
    required TaskRepository tasks,
    required TombstoneStore tombstones,
    required DatasetRepository dataset,
    required SettingsRepository settings,
    required EventLog events,
    required MergeStrategy mergeStrategy,
    required BackupStore backups,
    required Clock clock,
    required IdGenerator ids,
    required String appVersion,
    SyncLogger log = discardSyncLog,
  }) : _enabledTransports = enabledTransports,
       _replicas = replicas,
       _ideas = ideas,
       _tasks = tasks,
       _tombstones = tombstones,
       _dataset = dataset,
       _settings = settings,
       _events = events,
       _merge = mergeStrategy,
       _backups = backups,
       _clock = clock,
       _ids = ids,
       _appVersion = appVersion,
       _log = log;

  final EnabledTransports _enabledTransports;
  final ReplicaRepository _replicas;
  final IdeaRepository _ideas;
  final TaskRepository _tasks;
  final TombstoneStore _tombstones;
  final DatasetRepository _dataset;
  final SettingsRepository _settings;
  final EventLog _events;
  final MergeStrategy _merge;
  final BackupStore _backups;
  final Clock _clock;
  final IdGenerator _ids;
  final String _appVersion;
  final SyncLogger _log;

  /// §11.6.5 step 1. The pass currently running, if any.
  Future<SyncOutcome>? _running;

  /// Whether a pass is running right now, for the UI's "Syncing…" state.
  bool get isSyncing => _running != null;

  /// §11.6.5. Runs one pass, or joins the one already running.
  ///
  /// **Step 1, single-flight.** "A second sync request while one is running
  /// returns the running one's future rather than starting a second pass." All
  /// three triggers — manual `"Sync now"`, app foreground, and the
  /// `syncIntervalMinutes` timer — come through here and are subject to it.
  Future<SyncOutcome> sync() {
    final Future<SyncOutcome>? running = _running;
    if (running != null) {
      return running;
    }
    return _begin(const <SnapshotEnvelope>[]);
  }

  /// §11.8. Runs a pass with [extraPeers] treated as peers alongside whatever
  /// the transports return.
  ///
  /// This is what `"Import snapshot…"` calls: "the chosen file is treated as
  /// one more peer snapshot and run through the ordinary orchestration of
  /// §11.6.5, pre-merge backup included". Everything from step 4 on is the same
  /// code, which is what keeps an import and a sync the same operation rather
  /// than two that are meant to agree.
  ///
  /// Unlike [sync] this **waits** for a pass already in flight rather than
  /// joining it: joining would return that pass's outcome and quietly discard
  /// the file the user chose.
  ///
  /// [extraPeers] are not filtered by `replicaId`. A snapshot this device
  /// exported earlier is a legitimate thing to import — the merge is idempotent
  /// against a current one, and against a stale one it unions, which restores
  /// nothing that a tombstone or a sticky flag says should stay gone (§9.4).
  Future<SyncOutcome> syncWith(List<SnapshotEnvelope> extraPeers) async {
    Future<SyncOutcome>? running = _running;
    while (running != null) {
      await running;
      running = _running;
    }
    return _begin(extraPeers);
  }

  Future<SyncOutcome> _begin(List<SnapshotEnvelope> extraPeers) {
    // The future that is stored and the future that is returned are the same
    // object, so a second caller receives literally "the running one's future".
    // The `whenComplete` is attached before the assignment and its callback
    // runs in a later microtask, so the lock cannot be cleared before it is
    // taken. Clearing there rather than after an `await` means a failure in
    // `_runPass` cannot leave the lock held for the life of the app — nothing
    // in it is expected to throw, and this is what makes "expected"
    // unnecessary to trust.
    final Future<SyncOutcome> pass = _runPass(extraPeers)
        .whenComplete(() => _running = null);
    _running = pass;
    return pass;
  }

  Future<SyncOutcome> _runPass(List<SnapshotEnvelope> extraPeers) async {
    final String replicaId = await _replicas.replicaId();
    final String deviceName = await _replicas.deviceName();

    // Step 2. The local snapshot, as this device stands before any merge.
    //
    // Captured **once** and handed to step 3, because §11.6.2's
    // `fetchPeerSnapshots` now takes it: the LAN transport has to send this
    // device's snapshot in order to receive the peer's in one round trip, and
    // letting it capture its own would give the two ends different inputs
    // whenever the user edited something in between.
    final ReplicaSnapshot local = await _localSnapshot(replicaId);
    final SnapshotEnvelope localEnvelope = SnapshotEnvelope(
      replicaId: replicaId,
      deviceName: deviceName,
      generatedAt: _clock.nowUtc(),
      appVersion: _appVersion,
      snapshot: local,
    );
    final List<SyncTransport> transports = await _enabledTransports();

    // Step 3.
    final PeerCollection collected = await collectPeers(
      transports: transports,
      local: localEnvelope,
      extraPeers: extraPeers,
      log: _log,
    );

    // Steps 4 to 6. Skipped entirely when there is nothing to merge — but the
    // pass continues to step 7, which is the correction v1.11 made: "Publishing
    // is the only thing that makes this device visible to the others, so a run
    // that returns without publishing leaves an empty folder empty."
    MergeReport? report;
    BackupEntry? backup;
    String? mergeFailure;
    ReplicaSnapshot published = local;
    if (collected.peers.isNotEmpty) {
      backup = await _writeBackup(local, replicaId, deviceName);
      try {
        final MergeResult result = _merge.merge(<ReplicaSnapshot>[
          local,
          ...collected.peers.map((SnapshotEnvelope e) => e.snapshot),
        ]);
        await _dataset.replaceAll(result.asSnapshot(replicaId));
        await _appendMergedEvents(result.report);
        report = result.report;
        published = result.asSnapshot(replicaId);
      } on Object catch (error) {
        // `replaceAll` is one transaction (STORE-3), so a constraint that fires
        // rolls the whole thing back and this device still holds exactly what
        // it held before. Two things follow, and both matter:
        //
        // * `published` stays the **pre-merge** snapshot, because step 7 is
        //   supposed to publish what the database now holds, and what it now
        //   holds is what it held at step 2.
        // * The pass still finishes. This class promises its callers that
        //   nothing throws at them (NFR-1), and a merge that could not be
        //   applied is a failure to report, not a reason to stop publishing or
        //   to leave the UI waiting on a future that never completes.
        mergeFailure = '$error';
        _log(
          'Sync: the merge could not be applied — $error. '
          'This device is unchanged.',
        );
      }
    }

    // Step 7.
    final List<TransportOutcome> outcomes = await _publish(
      transports: transports,
      fetches: collected.fetches,
      envelope: SnapshotEnvelope(
        replicaId: replicaId,
        deviceName: deviceName,
        generatedAt: _clock.nowUtc(),
        appVersion: _appVersion,
        snapshot: published,
      ),
    );

    // Step 8.
    final SyncOutcome outcome = SyncOutcome(
      finishedAt: _clock.nowUtc(),
      transports: outcomes,
      report: report,
      backup: backup,
      peersMerged: collected.peers.length,
      mergeFailure: mergeFailure,
    );
    await _recordLastSyncAt(outcome.finishedAt);
    return outcome;
  }

  /// Step 2. Builds this replica's snapshot from the repositories.
  ///
  /// Tasks come from `watchAll`, which includes archived and soft-deleted ones:
  /// a snapshot that carried only the To Do list would let a peer's copy of an
  /// archived Task resurrect it on the next merge. **Settings and the event log
  /// are absent** (MERGE-3, §11.6.1) — settings are per replica and never
  /// merged, so a snapshot carrying them would quietly overwrite the other
  /// device's preferences.
  Future<ReplicaSnapshot> _localSnapshot(String replicaId) async =>
      ReplicaSnapshot(
        replicaId: replicaId,
        ideas: await _ideas.watchAll().first,
        tasks: await _tasks.watchAll().first,
        tombstones: await _tombstones.all(),
      );

  /// Step 4. Writes the pre-merge backup (§11.6.6).
  ///
  /// A backup that cannot be written is logged and the pass continues. The
  /// alternative — refusing to sync — would mean a full disk stops the app
  /// syncing altogether, which is a worse outcome than a merge without
  /// insurance and is what §11.6.5's "MUST NOT abort the pass" and NFR-1 point
  /// at everywhere else.
  Future<BackupEntry?> _writeBackup(
    ReplicaSnapshot local,
    String replicaId,
    String deviceName,
  ) async {
    try {
      return await _backups.writeIfChanged(
        SnapshotEnvelope(
          replicaId: replicaId,
          deviceName: deviceName,
          generatedAt: _clock.nowUtc(),
          appVersion: _appVersion,
          snapshot: local,
        ),
      );
    } on Object catch (error) {
      _log('Sync: the pre-merge backup could not be written — $error.');
      return null;
    }
  }

  /// Step 6, second half. "Append a `merged` event per merged component, per
  /// §9.3 step 7."
  ///
  /// Outside `replaceAll`'s transaction, because STORE-4 deliberately keeps
  /// `events` out of the wholesale replace: the log carries no foreign key so
  /// that the history of how the data got here survives the data being
  /// replaced. A crash between the two loses some log entries for a log the MVP
  /// never reads back, which is a better trade than coupling the audit trail to
  /// the dataset's lifetime.
  Future<void> _appendMergedEvents(MergeReport report) async {
    final DateTime now = _clock.nowUtc();
    for (final MergedComponent component in report.components) {
      await _events.append(
        ItemEvent(
          eventId: _ids.newId(),
          itemId: component.outputId,
          itemKind: component.kind,
          type: ItemEventType.merged,
          timestamp: now,
          payload: <String, Object?>{
            'pass': component.pass,
            'inputIds': component.inputIds,
            if (component.repairs.isNotEmpty)
              'repairs': component.repairs
                  .map((MergeRepair r) => r.kind.name)
                  .toList(growable: false),
          },
        ),
      );
    }
  }

  /// Step 7. Publishes to **every** enabled transport, reachable or not.
  ///
  /// "Attempting the write is how a transport discovers it is usable, and a
  /// failure is recorded per transport rather than aborting the pass."
  Future<List<TransportOutcome>> _publish({
    required List<SyncTransport> transports,
    required Map<String, TransportFetch> fetches,
    required SnapshotEnvelope envelope,
  }) async {
    final List<TransportOutcome> outcomes = <TransportOutcome>[];
    for (final SyncTransport transport in transports) {
      final TransportFetch fetch =
          fetches[transport.id] ??
          const TransportFetch(SyncFetchStatus.fetched, 0, '');
      SyncPublishStatus status;
      String reason = fetch.reason;
      try {
        await transport.publish(envelope);
        status = SyncPublishStatus.published;
      } on Object catch (error) {
        status = SyncPublishStatus.failed;
        reason = '$error';
        _log('Sync (${transport.id}): could not publish — $error.');
      }
      outcomes.add(
        TransportOutcome(
          transportId: transport.id,
          fetch: fetch.status,
          publish: status,
          peersFetched: fetch.peers,
          reason: reason,
        ),
      );
    }
    return outcomes;
  }

  /// Step 8. "Record `lastSyncAt`."
  ///
  /// A per-replica setting (§11.8) and therefore never merged (MERGE-3), which
  /// is exactly why it is safe to write here: it describes this device's own
  /// history with its peers, not shared data.
  Future<void> _recordLastSyncAt(DateTime finishedAt) async {
    try {
      final Settings current = await _settings.read();
      await _settings.write(current.copyWith(lastSyncAt: finishedAt));
    } on Object catch (error) {
      _log('Sync: could not record lastSyncAt — $error.');
    }
  }
}

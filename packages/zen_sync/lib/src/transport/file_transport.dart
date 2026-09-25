/// §11.6.3. Snapshots exchanged through a shared directory.
library;

import 'package:uuid/uuid.dart';
import 'package:zen_domain/zen_domain.dart';

import '../snapshot/snapshot_codec.dart';
import '../snapshot/snapshot_envelope.dart';
import '../snapshot/snapshot_format_failure.dart';
import '../sync_log.dart';
import 'snapshot_directory.dart';
import 'sync_transport.dart';

/// §11.6.3. Reads and writes snapshots in a directory.
///
/// "The same implementation serves three purposes: manual export/import,
/// backup, and automatic sync through a folder kept in step by Syncthing or a
/// cloud drive." It is deliberately ignorant of which of the three it is doing
/// — a folder the user picked and a folder Syncthing replicates are the same
/// folder as far as this class is concerned.
///
/// Platform differences live entirely in the injected [SnapshotDirectory]
/// (§11.6.3, §11.7), so nothing here branches on the platform.
final class FileSnapshotTransport implements SyncTransport {
  /// Creates a transport over [directory] for the replica [replicaId].
  FileSnapshotTransport({
    required SnapshotDirectory directory,
    required String replicaId,
    SnapshotCodec? codec,
    SyncLogger log = discardSyncLog,
    Uuid uuid = const Uuid(),
    // `prefer_initializing_formals` suggests `this._directory` and friends,
    // which Dart forbids: a named parameter may not begin with an underscore.
    // Hence the ignores below.
    // ignore: prefer_initializing_formals
  }) : _directory = directory,
       // ignore: prefer_initializing_formals
       _replicaId = replicaId,
       _codec = codec ?? SnapshotCodec(log: log),
       // ignore: prefer_initializing_formals
       _log = log,
       // ignore: prefer_initializing_formals
       _uuid = uuid;

  /// §11.6.2. This transport's stable identifier.
  static const String transportId = 'file';

  /// §11.6.3. The prefix every published snapshot file carries.
  static const String _snapshotPrefix = 'zen-snapshot-';

  /// §11.6.3. The prefix of a partially written file.
  ///
  /// Deliberately **not** `zen-snapshot-`: a temp file must not match the read
  /// glob, or a peer would try to parse one mid-write — the very failure the
  /// write protocol exists to prevent.
  static const String _tempPrefix = 'zen-tmp-';

  static const String _extension = '.json';

  final SnapshotDirectory _directory;
  final String _replicaId;
  final SnapshotCodec _codec;
  final SyncLogger _log;
  final Uuid _uuid;

  @override
  String get id => transportId;

  @override
  Future<TransportAvailability> availability() => _directory.availability();

  /// §11.6.3. Every readable peer snapshot in the directory.
  ///
  /// "Reads: every `zen-snapshot-*.json` in the directory. **The body's
  /// `replicaId` is authoritative and the filename is a convention** — the two
  /// disagree whenever a file is copied or renamed by hand. Skip any file whose
  /// body carries this device's own `replicaId`. A file that fails to parse is
  /// skipped with a logged warning, never allowed to abort the sync."
  @override
  Future<List<SnapshotEnvelope>> fetchPeerSnapshots() async {
    final List<String> names = await _directory.listNames();
    final List<SnapshotEnvelope> peers = <SnapshotEnvelope>[];
    // Sorted so that two runs over the same folder report their warnings in the
    // same order and the orchestrator's peer list is reproducible, which the
    // convergence simulation leans on when a seed fails.
    for (final String name in names.toList()..sort()) {
      if (!_isSnapshotName(name)) {
        continue;
      }
      final String contents;
      try {
        contents = await _directory.readAsString(name);
      } on Object catch (error) {
        // A file that vanished between the listing and the read — the folder
        // sync client moving it, or a peer's own swap window (§11.6.3). Not an
        // error worth failing a pass over.
        _log('Sync folder: could not read "$name", skipping it ($error).');
        continue;
      }
      switch (_codec.decode(contents)) {
        case Ok<SnapshotEnvelope, SnapshotFormatFailure>(
          value: final SnapshotEnvelope envelope,
        ):
          if (envelope.replicaId == _replicaId) {
            // Our own snapshot, whatever the file is called. Merging it would
            // be harmless — the merge is idempotent — but it would put this
            // device in its own merge report as a peer, which is noise.
            continue;
          }
          peers.add(envelope);
        case Err<SnapshotEnvelope, SnapshotFormatFailure>(
          error: final SnapshotFormatFailure failure,
        ):
          _log('Sync folder: skipping "$name". ${failure.message}');
      }
    }
    return peers;
  }

  /// §11.6.3, §11.6.5 step 7. Writes this replica's snapshot, without a peer
  /// ever seeing a fragment.
  ///
  /// Three things happen, in this order:
  ///
  /// 1. **Skip if nothing changed** (§11.6.5 step 7). The comparison is of the
  ///    `ReplicaSnapshot`, not the envelope, whose `generatedAt` moves every
  ///    pass. "An unchanged dataset republished every 15 minutes wakes
  ///    Syncthing or a cloud drive with an identical payload under a new
  ///    timestamp for no reason."
  /// 2. **Write a temp file, then rename it over the target.** What that costs
  ///    differs by platform and is documented on
  ///    [SnapshotDirectory.renameOver].
  /// 3. **Sweep our own leftovers.** A crash leaves a temp file behind, and in
  ///    a Syncthing folder it replicates to every peer.
  @override
  Future<void> publish(SnapshotEnvelope envelope) async {
    final String target = snapshotFileName(envelope.replicaId);

    if (await _isUnchanged(target, envelope.snapshot)) {
      await _sweepOwnTemps();
      return;
    }

    final String temp =
        '$_tempPrefix${envelope.replicaId}-${_uuid.v7()}$_extension';
    await _directory.writeNew(temp, _codec.encode(envelope));
    try {
      await _directory.renameOver(temp, target);
    } on Object {
      // The rename failed, so the temp file is still a temp file. Remove it
      // rather than leaving a half-published snapshot behind for the sweep to
      // find later, then let the caller record the transport failure.
      await _directory.delete(temp);
      rethrow;
    }
    await _sweepOwnTemps();
  }

  /// §11.6.3. The published name for [replicaId].
  ///
  /// Also used by `"Export snapshot…"` (§11.8), so the file the user exports is
  /// the one another replica would read.
  static String snapshotFileName(String replicaId) =>
      '$_snapshotPrefix$replicaId$_extension';

  /// §11.6.5 step 7. Whether the directory already holds this exact dataset.
  ///
  /// Returns `false` whenever the answer cannot be established — no file, an
  /// unreadable one, a stale format. Republishing costs a write; wrongly
  /// skipping costs a peer the update, so the doubt resolves towards writing.
  Future<bool> _isUnchanged(String target, ReplicaSnapshot snapshot) async {
    final String existing;
    try {
      existing = await _directory.readAsString(target);
    } on Object {
      return false;
    }
    return switch (_codec.decode(existing)) {
      Ok<SnapshotEnvelope, SnapshotFormatFailure>(
        value: final SnapshotEnvelope envelope,
      ) =>
        envelope.snapshot == snapshot,
      Err<SnapshotEnvelope, SnapshotFormatFailure>() => false,
    };
  }

  /// §11.6.3. Deletes temp files carrying **this device's** replicaId.
  ///
  /// "It MUST NOT delete another device's temps, which may be in flight." That
  /// is why the replicaId is in the temp name at all: without it a sweep on one
  /// device could delete the file another device is in the middle of renaming,
  /// turning a crash-cleanup into the data loss it was meant to prevent.
  Future<void> _sweepOwnTemps() async {
    final List<String> names;
    try {
      names = await _directory.listNames();
    } on Object catch (error) {
      // Housekeeping. A folder that cannot be listed will be swept next pass,
      // and failing a publish that has already succeeded over it would be
      // worse than the leftover file.
      _log('Sync folder: could not sweep temp files ($error).');
      return;
    }
    for (final String name in names) {
      if (_isOwnTempName(name)) {
        await _directory.delete(name);
      }
    }
  }

  /// §11.6.3's read glob, `zen-snapshot-*.json`.
  static bool _isSnapshotName(String name) =>
      name.startsWith(_snapshotPrefix) && name.endsWith(_extension);

  /// Whether [name] is a temp file this replica wrote.
  ///
  /// The shape is `zen-tmp-<replicaId>-<uuid>.json` (§11.6.3): a `.json`
  /// extension, because SAF derives a file's type from its MIME type on create
  /// and a name ending in `.tmp-…` risks being mangled; a prefix that does not
  /// match the read glob; and a replicaId so a device can identify its own
  /// leftovers.
  bool _isOwnTempName(String name) =>
      name.startsWith('$_tempPrefix$_replicaId-') && name.endsWith(_extension);
}

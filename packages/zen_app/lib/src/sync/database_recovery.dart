/// §11.5.5, §11.6.6, §11.8. Getting back from an unreadable database.
library;

import 'package:zen_data/zen_data.dart';
import 'package:zen_domain/zen_domain.dart';
import 'package:zen_sync/zen_sync.dart';

import 'snapshot_file_exchange.dart';

/// §11.5.5. The two ways back the recovery screen offers.
///
/// "Show a dedicated screen naming the problem, offering `"Restore from
/// backup…"` and `"Import snapshot…"`, and keep the unreadable file in place,
/// renamed with a timestamp, so nothing is destroyed." D-M4-9 rendered both
/// disabled because they belong to the sync layer; this is that layer arriving.
///
/// The flow rests on the quarantine `openDatabase` already performs (D-M3-11):
/// once the unreadable file has been **moved aside**, opening the same path
/// again creates a fresh, empty database, and a backup or a snapshot can be
/// written into it. If the file could *not* be moved aside there is nowhere to
/// put a fresh database, and [canRecover] says so rather than offering a button
/// that would fail.
///
/// Nothing here merges. A device whose database is unreadable holds no data to
/// merge *with*, so both paths replace — which is also why both say so plainly
/// before they run.
final class DatabaseRecovery {
  /// Wires recovery to the database path and the backups beside it.
  DatabaseRecovery({
    required this.databasePath,
    required this.canRecover,
    required BackupStore backups,
    required SnapshotFileExchange exchange,
    required Clock clock,
    // A named parameter may not begin with an underscore.
    // ignore: prefer_initializing_formals
  }) : _backups = backups,
       // ignore: prefer_initializing_formals
       _exchange = exchange,
       // ignore: prefer_initializing_formals
       _clock = clock;

  /// Where the fresh database will be created.
  final String databasePath;

  /// §11.5.5. Whether the unreadable file was successfully moved aside.
  ///
  /// False means the original is still sitting at [databasePath], so creating a
  /// fresh one there would either fail or overwrite the very file the screen
  /// has just promised the user it kept.
  final bool canRecover;

  final BackupStore _backups;
  final SnapshotFileExchange _exchange;
  final Clock _clock;

  /// §11.6.6. The backups available to restore, newest first.
  Future<List<BackupEntry>> list() => _backups.list();

  /// §11.6.6. Restores [entry] into a fresh database.
  Future<RecoveryResult> restore(BackupEntry entry) async {
    final Result<SnapshotEnvelope, SnapshotFormatFailure> read = await _backups
        .read(entry);
    return switch (read) {
      Err<SnapshotEnvelope, SnapshotFormatFailure>(
        error: final SnapshotFormatFailure failure,
      ) =>
        RecoveryResult(succeeded: false, message: failure.message),
      Ok<SnapshotEnvelope, SnapshotFormatFailure>(
        value: final SnapshotEnvelope envelope,
      ) =>
        await _apply(envelope.snapshot),
    };
  }

  /// §11.8. Reads a snapshot file the user chooses and applies it.
  ///
  /// Returns `null` if they cancelled the file dialog.
  Future<RecoveryResult?> importSnapshot() async {
    final String? contents = await _exchange.read();
    if (contents == null) {
      return null;
    }
    final Result<SnapshotEnvelope, SnapshotFormatFailure> decoded =
        const SnapshotCodec().decode(contents);
    return switch (decoded) {
      Err<SnapshotEnvelope, SnapshotFormatFailure>(
        error: final SnapshotFormatFailure failure,
      ) =>
        RecoveryResult(succeeded: false, message: failure.message),
      Ok<SnapshotEnvelope, SnapshotFormatFailure>(
        value: final SnapshotEnvelope envelope,
      ) =>
        await _apply(envelope.snapshot),
    };
  }

  /// Opens a fresh database at [databasePath] and writes [snapshot] into it.
  Future<RecoveryResult> _apply(ReplicaSnapshot snapshot) async {
    final OpenOutcome outcome = await openDatabase(
      path: databasePath,
      nowUtc: _clock.nowUtc(),
    );
    switch (outcome) {
      case DatabaseUnreadable(:final Object cause):
        return RecoveryResult(
          succeeded: false,
          message: 'Zen still cannot create a database here: $cause',
        );
      case DatabaseOpened(:final AppDatabase database):
        try {
          await DriftDatasetRepository(database).replaceAll(snapshot);
        } on Object catch (error) {
          return RecoveryResult(
            succeeded: false,
            message: 'The recovered data could not be written: $error',
          );
        } finally {
          // Closed either way. The app is about to be restarted, and leaving a
          // second connection open to the file the next launch will use is how
          // a recovery turns into a locked database.
          await database.close();
        }
        return RecoveryResult(
          succeeded: true,
          message:
              'Restored ${snapshot.ideas.length} ideas and '
              '${snapshot.tasks.length} tasks. Close Zen and open it again.',
        );
    }
  }
}

/// What a recovery attempt did, in a line fit to show the user.
final class RecoveryResult {
  /// Records the attempt.
  const RecoveryResult({required this.succeeded, required this.message});

  /// Whether the data was written.
  final bool succeeded;

  /// What to tell the user, whichever way it went.
  final String message;
}

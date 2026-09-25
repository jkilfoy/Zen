/// §11.6.6. Pre-merge backups in application-private storage.
library;

import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:zen_domain/zen_domain.dart';

import '../snapshot/snapshot_codec.dart';
import '../snapshot/snapshot_envelope.dart';
import '../snapshot/snapshot_format_failure.dart';

/// §11.6.6. One retained backup, as the restore list shows it.
@immutable
final class BackupEntry {
  /// Records a backup file called [fileName], taken at [takenAt].
  const BackupEntry({required this.fileName, required this.takenAt});

  /// The file's name within the backup directory.
  final String fileName;

  /// When the backup was written, UTC. §11.6.6: the restore list orders by
  /// this, and it is the only thing distinguishing one backup from another in
  /// the UI.
  final DateTime takenAt;

  @override
  bool operator ==(Object other) =>
      other is BackupEntry &&
      other.fileName == fileName &&
      other.takenAt == takenAt;

  @override
  int get hashCode => Object.hash(fileName, takenAt);

  @override
  String toString() => 'BackupEntry($fileName)';
}

/// §11.6.6. Writes, lists and reads the pre-merge backups.
///
/// "This is cheap insurance: the snapshot codec already exists, and a merge bug
/// is the highest-severity failure available in this design (§9.4)."
///
/// Unlike the sync folder, this directory is **application-private**, so it is
/// reached with `dart:io` on both platforms — Android's scoped-storage rules
/// (§11.6.3) govern the user's own folders, not the app's. `path_provider`
/// supplies the location and `zen_app` injects it, which is the only part of
/// this that needs Flutter.
final class BackupStore {
  /// Creates a store over [directoryPath], the `backups/` directory.
  BackupStore({
    required this.directoryPath,
    SnapshotCodec codec = const SnapshotCodec(),
    // `prefer_initializing_formals` suggests `this._codec`, which Dart forbids:
    // a named parameter may not begin with an underscore.
    // ignore: prefer_initializing_formals
  }) : _codec = codec;

  /// §11.6.6. How many backups are retained, after de-duplication.
  static const int retained = 20;

  /// §11.6.6. The prefix every backup file carries.
  static const String filePrefix = 'pre-merge-';

  static const String _extension = '.json';

  /// The directory holding the backups.
  final String directoryPath;

  final SnapshotCodec _codec;

  /// §11.6.5 step 4, §11.6.6. Writes [envelope] unless it duplicates the newest
  /// backup, then applies retention. Returns the entry written, or `null` when
  /// the write was skipped.
  ///
  /// **Skipping matters more than it looks.** Without it, "20 backups, one
  /// before every merge, two devices on the 15-minute timer, and the whole
  /// history spans about five hours — so a merge bug noticed the next morning
  /// has no clean backup left, which is exactly the failure this file exists to
  /// insure against." Consecutive backups are identical whenever the
  /// intervening merge changed nothing, which is the common case.
  Future<BackupEntry?> writeIfChanged(SnapshotEnvelope envelope) async {
    final Directory directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      // Ours to manage, unlike the user's sync folder, so creating it is right.
      directory.createSync(recursive: true);
    }

    final List<BackupEntry> existing = await list();
    if (existing.isNotEmpty &&
        await _holdsSameDataset(existing.first, envelope.snapshot)) {
      return null;
    }

    final BackupEntry entry = BackupEntry(
      fileName: fileNameFor(envelope.generatedAt),
      takenAt: truncateToMilliseconds(envelope.generatedAt),
    );
    await File(p.join(directoryPath, entry.fileName))
        .writeAsString(_codec.encode(envelope), flush: true);

    await _applyRetention();
    return entry;
  }

  /// §11.6.6. The retained backups, **newest first**, as the restore list shows
  /// them.
  ///
  /// Ordered by the timestamp in the name rather than by the filesystem's
  /// modification time: a folder-sync client or a restore-from-another-device
  /// can rewrite mtimes, and the name is what the file actually claims about
  /// itself.
  Future<List<BackupEntry>> list() async {
    final Directory directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      return const <BackupEntry>[];
    }
    // `listSync` rather than the asynchronous stream, deliberately. This
    // directory holds at most [retained] small files, it is application-private
    // local storage rather than a folder a cloud client might be streaming over
    // a network, and it is read twice per sync at most. Against that, the
    // asynchronous `Directory.list()` returns a stream whose events are never
    // delivered under `flutter_test`'s fake clock, which made the one place
    // this is reached from the UI — §11.6.6's restore dialog — untestable.
    final List<FileSystemEntity> entries = directory.listSync(
      followLinks: false,
    );
    final List<BackupEntry> backups = <BackupEntry>[];
    for (final FileSystemEntity entity in entries) {
      if (entity is! File) {
        continue;
      }
      final String name = p.basename(entity.path);
      final DateTime? takenAt = takenAtFromFileName(name);
      if (takenAt != null) {
        backups.add(BackupEntry(fileName: name, takenAt: takenAt));
      }
    }
    backups.sort(
      (BackupEntry a, BackupEntry b) => b.takenAt.compareTo(a.takenAt),
    );
    return backups;
  }

  /// §11.6.6. Reads a backup for `"Restore from backup…"`.
  ///
  /// A backup written by this replica always decodes; one that does not has
  /// been corrupted on disk, and the user is told rather than handed a partial
  /// restore.
  Future<Result<SnapshotEnvelope, SnapshotFormatFailure>> read(
    BackupEntry entry,
  ) async {
    final File file = File(p.join(directoryPath, entry.fileName));
    final String contents;
    try {
      contents = await file.readAsString();
    } on FileSystemException catch (error) {
      return Err<SnapshotEnvelope, SnapshotFormatFailure>(
        SnapshotNotJson(error.message),
      );
    }
    return _codec.decode(contents);
  }

  /// §11.6.6. The file name for a backup taken at [instant].
  ///
  /// "**Plain ISO-8601 is not a legal Windows filename**, because `:` is
  /// forbidden there." Both the colons and the fractional-second dot become
  /// hyphens, giving `pre-merge-2026-09-24T18-30-00-000Z.json`. The result is
  /// fixed-width, so it also sorts lexicographically in chronological order.
  static String fileNameFor(DateTime instant) {
    final String iso = truncateToMilliseconds(instant).toIso8601String();
    return '$filePrefix${iso.replaceAll(':', '-').replaceAll('.', '-')}'
        '$_extension';
  }

  /// The instant [fileName] encodes, or `null` if it is not a backup name.
  ///
  /// The inverse of [fileNameFor]. Reversible because the encoded form is the
  /// exact 24-character INV-9 form with two known substitutions at known
  /// offsets — the date's own hyphens are never ambiguous with them.
  static DateTime? takenAtFromFileName(String fileName) {
    if (!fileName.startsWith(filePrefix) || !fileName.endsWith(_extension)) {
      return null;
    }
    final String stamp = fileName.substring(
      filePrefix.length,
      fileName.length - _extension.length,
    );
    // `YYYY-MM-DDTHH-MM-SS-mmmZ`.
    if (stamp.length != 24 || !stamp.endsWith('Z')) {
      return null;
    }
    final int t = stamp.indexOf('T');
    if (t != 10) {
      return null;
    }
    final String date = stamp.substring(0, t);
    final List<String> time = stamp
        .substring(t + 1, stamp.length - 1)
        .split('-');
    if (time.length != 4) {
      return null;
    }
    try {
      return DateTime.parse(
        '${date}T${time[0]}:${time[1]}:${time[2]}.${time[3]}Z',
      );
    } on FormatException {
      return null;
    }
  }

  /// Whether [entry] already holds [snapshot], byte-comparison avoided in
  /// favour of comparing the decoded dataset.
  ///
  /// The envelope's `generatedAt` differs on every pass (§9.3 step 8), so the
  /// files are never byte-identical even when the data is. The dataset is what
  /// the de-duplication is about.
  Future<bool> _holdsSameDataset(
    BackupEntry entry,
    ReplicaSnapshot snapshot,
  ) async {
    final Result<SnapshotEnvelope, SnapshotFormatFailure> decoded = await read(
      entry,
    );
    return switch (decoded) {
      Ok<SnapshotEnvelope, SnapshotFormatFailure>(
        value: final SnapshotEnvelope envelope,
      ) =>
        envelope.snapshot == snapshot,
      // Unreadable: treat it as different, so a fresh backup is written. The
      // doubt resolves towards keeping more insurance, not less.
      Err<SnapshotEnvelope, SnapshotFormatFailure>() => false,
    };
  }

  /// §11.6.6. "Keep the newest 20 after de-duplication and delete older ones."
  Future<void> _applyRetention() async {
    final List<BackupEntry> backups = await list();
    for (final BackupEntry stale in backups.skip(retained)) {
      final File file = File(p.join(directoryPath, stale.fileName));
      try {
        await file.delete();
      } on FileSystemException {
        // Retention is housekeeping. A file that cannot be deleted now is
        // retried on the next sync, and failing the pass over it would be
        // wildly out of proportion.
      }
    }
  }
}

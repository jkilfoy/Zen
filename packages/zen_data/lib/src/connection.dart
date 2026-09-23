/// §11.5.5. Opening the database, and what to do when it will not open.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'database.dart';
import 'mapping/instants.dart';

/// §11.5.5. The outcome of trying to open the database.
///
/// "Do not crash to a blank screen and do not silently create an empty database
/// over the top, which would present as total data loss." So opening returns a
/// value rather than throwing, and the failed case carries what the recovery
/// screen needs to say.
sealed class OpenOutcome {
  const OpenOutcome();
}

/// §11.5.5. The database opened.
final class DatabaseOpened extends OpenOutcome {
  /// Wraps the opened [database].
  const DatabaseOpened(this.database);

  /// The opened database.
  final AppDatabase database;
}

/// §11.5.5. The database could not be opened, and nothing was destroyed.
///
/// "Show a dedicated screen naming the problem, offering `"Restore from
/// backup…"` and `"Import snapshot…"`, and keep the unreadable file in place,
/// renamed with a timestamp, so nothing is destroyed."
final class DatabaseUnreadable extends OpenOutcome {
  /// Records that [originalPath] could not be opened.
  const DatabaseUnreadable({
    required this.originalPath,
    required this.quarantinedPath,
    required this.cause,
  });

  /// Where the database was.
  final String originalPath;

  /// Where the unreadable file was moved to, or `null` if it could not be
  /// moved — in which case it is still at [originalPath] and still intact.
  final String? quarantinedPath;

  /// What went wrong, for the screen to name.
  final Object cause;
}

/// §11.5.5. Opens the database at [path], quarantining an unreadable file.
///
/// Verifies the file with `PRAGMA integrity_check` before handing it back: a
/// corrupt page can otherwise sit unnoticed until the query that touches it,
/// which is exactly the "presents as total data loss" failure §11.5.5 forbids.
///
/// [nowUtc] names the quarantined copy, so the name is reproducible in a test
/// and §11.11's ban on a hidden clock holds here too.
Future<OpenOutcome> openDatabase({
  required String path,
  required DateTime nowUtc,
}) async {
  AppDatabase? database;
  try {
    database = AppDatabase(NativeDatabase(File(path)));
    final QueryRow check = await database
        .customSelect('PRAGMA integrity_check')
        .getSingle();
    final Object? result = check.data.values.first;
    if (result != 'ok') {
      throw StateError('PRAGMA integrity_check returned "$result"');
    }
    // Forces `beforeOpen` to run, so a failure to apply the pragmas or the
    // migration is caught here rather than at the first query.
    await database.customSelect('SELECT 1').getSingle();
    return DatabaseOpened(database);
  } on Object catch (error) {
    await database?.close();
    return DatabaseUnreadable(
      originalPath: path,
      quarantinedPath: await _quarantine(path, nowUtc),
      cause: error,
    );
  }
}

/// §11.5.5. Moves an unreadable database aside, returning where it went.
///
/// Renamed rather than deleted, always: the file is the user's data even when
/// this process cannot read it, and a later version — or a copy taken to
/// another machine — may well be able to.
Future<String?> _quarantine(String path, DateTime nowUtc) async {
  final File file = File(path);
  if (!file.existsSync()) {
    // Nothing to preserve: the failure was in creating the file, not in
    // reading one that was already there.
    return null;
  }
  final String stamp = encodeInstant(nowUtc)
      .replaceAll(':', '-')
      .replaceAll('.', '-');
  final String target = '$path.unreadable-$stamp';
  try {
    await file.rename(target);
    return target;
  } on FileSystemException {
    // Could not move it. Say so rather than pretending: the original is still
    // where it was, which is the outcome §11.5.5 actually cares about.
    return null;
  }
}

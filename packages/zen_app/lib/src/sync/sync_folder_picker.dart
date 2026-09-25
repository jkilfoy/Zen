/// §11.6.3, §11.7. Choosing the sync folder, on either platform.
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:saf_util/saf_util.dart';
import 'package:saf_util/saf_util_platform_interface.dart';

/// §11.7. "`file_selector` on Windows and `saf_util` on Android sit behind one
/// `SyncFolderPicker` interface so the screens contain no platform branching."
///
/// The value returned is whatever §11.8's `syncFolderLocation` holds for that
/// platform: a directory path on Windows, a SAF persistable tree URI on
/// Android. The Settings screen stores it and never inspects it.
abstract interface class SyncFolderPicker {
  /// Asks the user for a folder, returning `null` if they cancelled.
  Future<String?> pick();

  /// §11.6.3. Whether [location] is still usable.
  ///
  /// On Android this is a real question: a persisted grant can be revoked by
  /// the user or dropped by the system, and "a revoked or missing grant is a
  /// normal state".
  Future<bool> stillGranted(String location);

  /// Gives up any platform permission held for [location].
  ///
  /// Windows has none to give up. On Android, leaving a persisted grant behind
  /// for a folder the user has removed from the app is a permission the app
  /// holds and does not use.
  Future<void> release(String location);
}

/// §11.6.3. The Windows picker: "an ordinary directory path chosen with
/// `file_selector`".
final class DesktopSyncFolderPicker implements SyncFolderPicker {
  /// Creates the desktop picker.
  const DesktopSyncFolderPicker();

  @override
  Future<String?> pick() =>
      getDirectoryPath(confirmButtonText: 'Use this folder');

  /// On Windows the only question is whether the directory is still there — a
  /// removable drive, a network share, a folder the user moved.
  @override
  Future<bool> stillGranted(String location) => Directory(location).exists();

  @override
  Future<void> release(String location) async {}
}

/// §11.6.3. The Android picker: a SAF persistable tree URI.
///
/// "A SAF persistable tree URI obtained with `ACTION_OPEN_DOCUMENT_TREE` and
/// retained with `takePersistableUriPermission`. All access goes through
/// `ContentResolver`; raw `dart:io` paths do not work under scoped storage and
/// MUST NOT be attempted."
///
/// `saf_util`'s `pickDirectory` is `ACTION_OPEN_DOCUMENT_TREE`, and its
/// `persistablePermission` argument is `takePersistableUriPermission` — without
/// it the grant dies with the process and sync would work once and then stop.
final class AndroidSyncFolderPicker implements SyncFolderPicker {
  /// Creates the Android picker.
  AndroidSyncFolderPicker([SafUtil? saf]) : _saf = saf ?? SafUtil();

  final SafUtil _saf;

  @override
  Future<String?> pick() async {
    final SafDocumentFile? picked = await _saf.pickDirectory(
      writePermission: true,
      persistablePermission: true,
    );
    return picked?.uri;
  }

  /// §11.6.3. A revoked grant is a normal state, so this is asked before every
  /// sync rather than assumed at start-up.
  @override
  Future<bool> stillGranted(String location) async {
    if (!await _saf.hasPersistedPermission(location, checkWrite: true)) {
      return false;
    }
    // A held grant to a folder that has since been deleted is still a held
    // grant. Both have to be true for the transport to be usable.
    return _saf.exists(location, true);
  }

  @override
  Future<void> release(String location) =>
      _saf.releasePersistedPermission(location);
}

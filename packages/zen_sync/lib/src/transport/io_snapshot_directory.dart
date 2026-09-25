/// §11.6.3. The `dart:io` [SnapshotDirectory]: Windows, and every test.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'snapshot_directory.dart';
import 'sync_transport.dart';

/// §11.6.3. A [SnapshotDirectory] over an ordinary filesystem path.
///
/// This is the Windows implementation — "an ordinary directory path chosen with
/// `file_selector`" — and it is also what every headless test runs against, so
/// the file transport, the orchestrator and §11.12's convergence simulation are
/// all exercised over a real filesystem rather than a fake (§11.13.1 puts "the
/// file transport against ordinary directories" in the headless column).
///
/// It is **not** usable on Android for the sync folder: §11.6.3 forbids raw
/// `dart:io` paths under scoped storage. Android's own implementation is
/// `zen_app`'s, over SAF.
final class IoSnapshotDirectory implements SnapshotDirectory {
  /// Creates a directory handle over [path].
  ///
  /// The directory is not created: the user picked it (§11.6.3), and silently
  /// creating a missing one would turn a folder that has been moved or
  /// unmounted into an empty folder that looks healthy and syncs nothing.
  IoSnapshotDirectory(this.path);

  /// The absolute path of the directory.
  final String path;

  @override
  Future<TransportAvailability> availability() async {
    final Directory directory = Directory(path);
    if (!await directory.exists()) {
      // The wording §11.6.3 specifies for the unavailable case. The same
      // sentence serves a folder that was never picked, one on a drive that is
      // not mounted, and one the user has since deleted — from the user's side
      // those are one situation with one remedy.
      return const TransportAvailability.unreachable(
        'Sync folder not available',
      );
    }
    return const TransportAvailability.reachable();
  }

  @override
  Future<List<String>> listNames() async {
    final List<FileSystemEntity> entries = await Directory(path)
        .list(followLinks: false)
        .toList();
    return <String>[
      for (final FileSystemEntity entry in entries)
        if (entry is File) p.basename(entry.path),
    ];
  }

  @override
  Future<String> readAsString(String name) =>
      File(_resolve(name)).readAsString();

  @override
  Future<void> writeNew(String name, String contents) async {
    // `flush: true` is the durability §11.6.3's write protocol depends on: the
    // rename that follows must publish bytes that are actually on the disk, not
    // bytes still sitting in a buffer that a power cut would lose.
    await File(_resolve(name)).writeAsString(contents, flush: true);
  }

  @override
  Future<void> delete(String name) async {
    final File file = File(_resolve(name));
    if (await file.exists()) {
      try {
        await file.delete();
      } on PathNotFoundException {
        // Deleted between the check and the call — by another device's sweep,
        // or by the folder-sync client. The post-condition already holds.
      }
    }
  }

  @override
  Future<void> renameOver(String from, String to) async {
    // Atomic on Windows: Dart's `File.rename` maps to `MoveFileEx` with
    // `MOVEFILE_REPLACE_EXISTING`, so the target is swapped in one step and is
    // never missing. On POSIX, `rename(2)` gives the same guarantee. Android's
    // SAF cannot do this, which is why `SnapshotDirectory.renameOver`
    // documents the weaker contract that implementation provides.
    await File(_resolve(from)).rename(_resolve(to));
  }

  /// Joins [name] onto [path], refusing anything that is not a plain filename.
  ///
  /// The names this class is asked for come from [listNames] or from the
  /// transport's own generator, so a separator here would mean a bug rather
  /// than hostile input — but the failure it would cause (writing outside the
  /// user's chosen folder) is bad enough to be worth closing off outright.
  String _resolve(String name) {
    if (name.isEmpty || name != p.basename(name)) {
      throw ArgumentError.value(name, 'name', 'must be a plain file name');
    }
    return p.join(path, name);
  }
}

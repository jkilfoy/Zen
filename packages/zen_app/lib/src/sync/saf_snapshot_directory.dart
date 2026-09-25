/// §11.6.3, §11.7. The Android [SnapshotDirectory], over scoped storage.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:saf_stream/saf_stream.dart';
import 'package:saf_stream/saf_stream_platform_interface.dart';
import 'package:saf_util/saf_util.dart';
import 'package:saf_util/saf_util_platform_interface.dart';
import 'package:zen_sync/zen_sync.dart';

/// §11.6.3. A sync folder reached through a SAF persistable tree URI.
///
/// "All access goes through `ContentResolver`; raw `dart:io` paths do not work
/// under scoped storage and MUST NOT be attempted." `saf_util` does the
/// directory operations and `saf_stream` the reads and writes — `saf_util`
/// deliberately excludes the latter, which is why §11.2 names the pair.
///
/// **This class cannot be tested headlessly.** Every method is a platform
/// channel call into Android, and §11.13.1 puts "the Android SAF folder path in
/// M6" squarely in the hardware column: "scoped storage,
/// `ACTION_OPEN_DOCUMENT_TREE`, persisted grants, and grant revocation behave
/// only on a real device." The logic that *can* be tested — naming, the read
/// filter, the temp sweep, the unchanged-content check — lives in
/// `FileSnapshotTransport` above this port, and is covered there against an
/// ordinary directory. What is left here is the platform mapping, and
/// `MANUAL_VERIFICATION.md` is how it gets checked.
final class SafSnapshotDirectory implements SnapshotDirectory {
  /// Creates a directory over the persisted tree [treeUri].
  SafSnapshotDirectory(this.treeUri, {SafUtil? saf, SafStream? stream})
    : _saf = saf ?? SafUtil(),
      _stream = stream ?? SafStream();

  /// §11.6.3. The `ACTION_OPEN_DOCUMENT_TREE` URI, as §11.8's
  /// `syncFolderLocation` stores it.
  final String treeUri;

  final SafUtil _saf;
  final SafStream _stream;

  /// The type every snapshot file is created with.
  ///
  /// Load-bearing, not decorative: SAF derives a document's extension from its
  /// MIME type on create, so a mismatched type is how a file named
  /// `zen-snapshot-….json` ends up on disk as `zen-snapshot-….json.txt` and
  /// stops matching the read glob.
  static const String _mimeType = 'application/json';

  @override
  Future<TransportAvailability> availability() async {
    try {
      // Both questions, because either can be false on its own: the user can
      // revoke the grant, and the user can delete the folder while the grant
      // survives.
      final bool granted = await _saf.hasPersistedPermission(
        treeUri,
        checkWrite: true,
      );
      if (!granted || !await _saf.exists(treeUri, true)) {
        // §11.6.3's wording. "A revoked or missing grant is a normal state:
        // report 'sync folder not available', keep the app fully usable
        // offline, and offer to re-pick. **Never block capture on it.**"
        return const TransportAvailability.unreachable(
          'Sync folder not available',
        );
      }
      return const TransportAvailability.reachable();
    } on Object {
      // A platform channel failure is indistinguishable from a revoked grant
      // as far as the user's remedy goes, so it reads the same.
      return const TransportAvailability.unreachable(
        'Sync folder not available',
      );
    }
  }

  @override
  Future<List<String>> listNames() async {
    final List<SafDocumentFile> entries = await _saf.list(treeUri);
    return <String>[
      for (final SafDocumentFile entry in entries)
        if (!entry.isDir) entry.name,
    ];
  }

  @override
  Future<String> readAsString(String name) async {
    final SafDocumentFile file = await _require(name);
    final Uint8List bytes = await _stream.readFileBytes(file.uri);
    return utf8.decode(bytes);
  }

  @override
  Future<void> writeNew(String name, String contents) async {
    // `overwrite: true` matters even though the transport only ever passes a
    // freshly generated temp name. With `overwrite: false`, SAF does not fail
    // on an existing name — it invents a new one and returns it — so a stale
    // collision would leave this method reporting success having written
    // somewhere else entirely.
    final SafNewFile written = await _stream.writeFileBytes(
      treeUri,
      name,
      _mimeType,
      Uint8List.fromList(utf8.encode(contents)),
      overwrite: true,
    );
    final String? actual = written.fileName;
    if (actual != null && actual != name) {
      throw StateError(
        'The sync folder stored "$name" as "$actual". Zen cannot use a folder '
        'that renames the files it writes.',
      );
    }
  }

  @override
  Future<void> delete(String name) async {
    final SafDocumentFile? file = await _saf.child(treeUri, <String>[name]);
    if (file == null) {
      // Absence is the post-condition, so there is nothing to do and nothing
      // to report.
      return;
    }
    await _saf.delete(file.uri, false);
  }

  /// §11.6.3. Delete the target, then rename the temp onto the freed name.
  ///
  /// **Not atomic, and the specification says so.** `DocumentsContract` offers
  /// no rename-over-existing and no atomic replace: `renameDocument` onto an
  /// occupied name fails or de-duplicates to `name (1).json`, and opening with
  /// `"wt"` truncates in place, which is precisely the torn read this exists to
  /// prevent. So there is a window in which the snapshot file does not exist.
  ///
  /// That window is acceptable because **absent is not torn**. A peer reading
  /// mid-swap sees the old file, no file, or the complete new one — never a
  /// fragment — and a missing peer file costs exactly one sync round, because a
  /// snapshot is idempotent republishable state rather than a log. A process
  /// that dies inside the window republishes on its next pass.
  ///
  /// If the window ever proves to matter, §11.6.3 records the upgrade path:
  /// generation-numbered files, written under a fresh name that SAF will
  /// accept, with older generations deleted afterwards.
  @override
  Future<void> renameOver(String from, String to) async {
    final SafDocumentFile source = await _require(from);
    await delete(to);
    final SafDocumentFile renamed = await _saf.rename(source.uri, false, to);
    if (renamed.name != to) {
      // The de-duplication this method exists to avoid happened anyway — the
      // delete did not take, or the provider does not honour the name. Saying
      // so beats leaving `zen-snapshot-… (1).json` in the folder, which no peer
      // reads and nothing would ever report.
      throw StateError(
        'The sync folder renamed "$to" to "${renamed.name}". The previous '
        'snapshot could not be replaced.',
      );
    }
  }

  Future<SafDocumentFile> _require(String name) async {
    final SafDocumentFile? file = await _saf.child(treeUri, <String>[name]);
    if (file == null) {
      throw StateError('The sync folder has no file called "$name".');
    }
    return file;
  }
}

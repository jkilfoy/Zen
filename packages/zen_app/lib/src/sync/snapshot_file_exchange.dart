/// §11.8. `"Export snapshot…"` and `"Import snapshot…"`, on either platform.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_stream/saf_stream_platform_interface.dart';
import 'package:saf_util/saf_util.dart';
import 'package:saf_util/saf_util_platform_interface.dart';

/// §11.8. Hands one snapshot file to the user, or takes one from them.
///
/// Separate from `SyncFolderPicker` because it is a different question: that one
/// asks for a folder the app will keep using and needs a *persisted* grant;
/// this one is a single file, once, and needs no grant at all.
abstract interface class SnapshotFileExchange {
  /// `"Import snapshot…"`. Returns the file's text, or `null` if cancelled.
  Future<String?> read();

  /// `"Export snapshot…"`. Writes [contents], returning a description of where
  /// it went, or `null` if cancelled.
  Future<String?> write(String suggestedName, String contents);
}

/// The Windows implementation, over `file_selector`.
final class DesktopSnapshotFileExchange implements SnapshotFileExchange {
  /// Creates the desktop exchange.
  const DesktopSnapshotFileExchange();

  /// The one file type either direction deals in.
  static const XTypeGroup _json = XTypeGroup(
    label: 'Zen snapshot',
    extensions: <String>['json'],
  );

  @override
  Future<String?> read() async {
    final XFile? file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_json],
    );
    return file?.readAsString();
  }

  @override
  Future<String?> write(String suggestedName, String contents) async {
    final FileSaveLocation? location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const <XTypeGroup>[_json],
    );
    if (location == null) {
      return null;
    }
    await File(location.path).writeAsString(contents, flush: true);
    return location.path;
  }
}

/// The Android implementation.
///
/// Reading goes through `file_selector`, which implements `openFile` on
/// Android. **Writing does not**: `file_selector_android` implements `openFile`,
/// `openFiles` and `getDirectoryPath` and no save dialog at all, so
/// `getSaveLocation` would throw `UnimplementedError` at the moment the user
/// tapped Export. So the export asks for a destination folder with
/// `saf_util` — without a persistable grant, since this is a one-off — and
/// writes into it with `saf_stream`.
final class AndroidSnapshotFileExchange implements SnapshotFileExchange {
  /// Creates the Android exchange.
  AndroidSnapshotFileExchange({SafUtil? saf, SafStream? stream})
    : _saf = saf ?? SafUtil(),
      _stream = stream ?? SafStream();

  final SafUtil _saf;
  final SafStream _stream;

  @override
  Future<String?> read() async {
    final XFile? file = await openFile();
    return file?.readAsString();
  }

  @override
  Future<String?> write(String suggestedName, String contents) async {
    final SafDocumentFile? folder = await _saf.pickDirectory(
      writePermission: true,
      // Deliberately not persistable: an export is one file, once. Taking a
      // lasting grant on a folder the user picked for a single save would be
      // holding a permission they did not agree to keep.
      persistablePermission: false,
    );
    if (folder == null) {
      return null;
    }
    // `overwrite: false`, unlike the transport's own writes: exporting over a
    // file the user already has is not something to do silently, and SAF's
    // de-duplicated name is the friendlier outcome here. The name it actually
    // used is what gets reported back.
    final SafNewFile written = await _stream.writeFileBytes(
      folder.uri,
      suggestedName,
      'application/json',
      Uint8List.fromList(utf8.encode(contents)),
      overwrite: false,
    );
    return written.fileName ?? suggestedName;
  }
}

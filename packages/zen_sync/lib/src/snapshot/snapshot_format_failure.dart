/// §11.6.1. Why a snapshot could not be read.
library;

import 'package:meta/meta.dart';

/// §11.6.1. A refusal to decode a snapshot, carrying a message fit to show a
/// user or write to a log.
///
/// §11.4.1's rule — results, not exceptions — applies here for the same reason
/// it applies to the rules of §4: a malformed peer file is an ordinary,
/// expected condition, not programmer error. §11.6.3 requires that it "is
/// skipped with a logged warning, never allowed to abort the sync", which a
/// thrown exception makes easy to get wrong.
@immutable
sealed class SnapshotFormatFailure {
  /// Const superclass constructor.
  const SnapshotFormatFailure();

  /// What went wrong, in a sentence fit for the user.
  ///
  /// §11.6.1 requires "a clear message" for a refused `formatVersion`, and
  /// §11.8's `"Import snapshot…"` shows this directly when the user picks a
  /// file the app cannot read.
  String get message;
}

/// §11.6.1. The bytes were not JSON at all, or not a JSON object.
final class SnapshotNotJson extends SnapshotFormatFailure {
  /// Records that parsing failed, with [detail] from the JSON decoder.
  const SnapshotNotJson(this.detail);

  /// The underlying parser's complaint.
  final String detail;

  @override
  String get message => 'This file is not a Zen snapshot: $detail';

  @override
  bool operator ==(Object other) =>
      other is SnapshotNotJson && other.detail == detail;

  @override
  int get hashCode => Object.hash(SnapshotNotJson, detail);

  @override
  String toString() => 'SnapshotNotJson($detail)';
}

/// §11.6.1. `formatVersion` names a version this build cannot read.
///
/// "An unknown higher version is refused with a clear message rather than
/// parsed optimistically." A *lower* version would be readable if one existed;
/// version 1 is the first, so today any version but 1 is a refusal, and the
/// message distinguishes the two directions because they mean different things
/// to the user — one is "update this device", the other is "this file predates
/// anything I know about".
final class SnapshotVersionUnsupported extends SnapshotFormatFailure {
  /// Records that [found] is not readable by a build that writes [supported].
  const SnapshotVersionUnsupported({
    required this.found,
    required this.supported,
  });

  /// The `formatVersion` in the file.
  final int found;

  /// The highest version this build understands.
  final int supported;

  @override
  String get message => found > supported
      ? 'This snapshot was written by a newer version of Zen (format '
            '$found, this version reads $supported). Update Zen on this '
            'device, then try again.'
      : 'This snapshot uses an old format ($found) that this version of Zen '
            'can no longer read.';

  @override
  bool operator ==(Object other) =>
      other is SnapshotVersionUnsupported &&
      other.found == found &&
      other.supported == supported;

  @override
  int get hashCode => Object.hash(SnapshotVersionUnsupported, found, supported);

  @override
  String toString() => 'SnapshotVersionUnsupported($found, max $supported)';
}

/// §11.6.1. A field was missing, of the wrong type, or held a value no domain
/// type accepts.
///
/// This is the failure that makes a peer snapshot **all-or-nothing**. §11.6.1:
/// "If any record in it cannot be constructed … the whole file is skipped …
/// Dropping the one bad record instead would be the quieter failure and
/// therefore the worse one: the sync would appear to succeed while silently
/// carrying less than the peer holds, and this device would then republish that
/// reduced view."
///
/// [path] locates the offending value so the log says *which* record, which is
/// the difference between a diagnosable report and "the file was bad".
final class SnapshotFieldInvalid extends SnapshotFormatFailure {
  /// Records that the value at [path] was unusable, because of [reason].
  const SnapshotFieldInvalid({required this.path, required this.reason});

  /// A dotted path into the document, e.g. `tasks[3].subtasks[1].status`.
  final String path;

  /// Why that value could not be used.
  final String reason;

  @override
  String get message => 'This snapshot is not readable: $path $reason.';

  @override
  bool operator ==(Object other) =>
      other is SnapshotFieldInvalid &&
      other.path == path &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(SnapshotFieldInvalid, path, reason);

  @override
  String toString() => 'SnapshotFieldInvalid($path: $reason)';
}

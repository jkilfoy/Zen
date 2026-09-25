/// §11.6.3, §11.7. The filesystem port `FileSnapshotTransport` writes through.
library;

import 'sync_transport.dart';

/// §11.6.3. A flat directory of snapshot files, wherever it physically lives.
///
/// This port exists because the two platforms reach a directory in ways that
/// have nothing in common. Windows uses an ordinary path and `dart:io`; Android
/// uses a SAF persistable tree URI and `ContentResolver`, and §11.6.3 is
/// explicit that "raw `dart:io` paths do not work under scoped storage and MUST
/// NOT be attempted". SAF needs a Flutter platform channel, which a pure Dart
/// package cannot have, so the Android implementation lives in `zen_app`
/// alongside the rest of §11.7's platform glue while `FileSnapshotTransport`
/// stays platform-free and headlessly testable (§11.13.1).
///
/// Implementations are not required to be thread-safe. The orchestrator's
/// single-flight lock (§11.6.5 step 1) means only one pass touches a directory
/// at a time within one app; **across** apps no locking is assumed at all,
/// which is what the write protocol below is for.
abstract interface class SnapshotDirectory {
  /// §11.6.2, §11.6.3. Whether the directory can be read and written now.
  ///
  /// On Android a revoked or missing SAF grant is a normal state, not an error:
  /// "report 'sync folder not available', keep the app fully usable offline,
  /// and offer to re-pick. **Never block capture on it.**"
  Future<TransportAvailability> availability();

  /// The names of the files directly in this directory.
  ///
  /// Names only — no paths, no subdirectories. Subdirectories, if the user's
  /// folder has any, are not listed: §11.6.3 describes one flat folder.
  Future<List<String>> listNames();

  /// Reads the file called [name] as UTF-8 text.
  ///
  /// Throws if it does not exist or cannot be read. Callers treat that as
  /// §11.6.3's "a file that fails to parse is skipped with a logged warning".
  Future<String> readAsString(String name);

  /// Creates [name] and writes [contents] to it as UTF-8, flushed.
  ///
  /// [name] is expected not to exist — the transport only ever calls this for a
  /// freshly generated temp name. Implementations MUST have the bytes durably
  /// written before the returned future completes, because the whole point of
  /// the temp file is that the rename which follows publishes something
  /// complete.
  Future<void> writeNew(String name, String contents);

  /// Deletes [name] if it exists, and does nothing if it does not.
  ///
  /// Absence is not an error: the transport sweeps leftovers it may or may not
  /// have (§11.6.3), and racing another device's sweep must not fail a sync.
  Future<void> delete(String name);

  /// Moves [from] onto [to], replacing [to] if it exists.
  ///
  /// **The guarantee differs by platform, and §11.6.3 states both rather than
  /// assuming one.** What every implementation must provide is that a
  /// concurrent reader never sees a *fragment* of [to]:
  ///
  /// * **Windows** — `File.rename` replaces an existing file, so the swap is
  ///   atomic and there is no window in which [to] is missing.
  /// * **Android (SAF)** — `DocumentsContract` offers no rename-over-existing
  ///   and no atomic replace: `renameDocument` onto an occupied name fails or
  ///   de-duplicates to `name (1).json`, and opening with `"wt"` truncates in
  ///   place, which is precisely the torn read this rule exists to prevent. So
  ///   the implementation deletes [to] and then renames [from] onto the freed
  ///   name, and **there is a window in which [to] does not exist.**
  ///
  /// That window is acceptable because absent is not torn. A peer reading
  /// mid-swap sees the old file, no file, or the complete new one — never a
  /// fragment — and a missing peer file costs exactly one sync round, because a
  /// snapshot is idempotent republishable state rather than a log.
  Future<void> renameOver(String from, String to);
}

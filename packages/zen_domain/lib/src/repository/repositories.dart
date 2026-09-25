/// §8, §11.4.6. The repository interfaces.
///
/// STORE-2: all reads and writes go through these, and UI code must not touch
/// the database directly. Declared here and implemented in `zen_data` (M3), so
/// that a later version can add a remote-backed implementation without changing
/// UI or domain code.
library;

import '../merge/replica_snapshot.dart';
import '../model/enums.dart';
import '../model/idea.dart';
import '../model/item_event.dart';
import '../model/settings.dart';
import '../model/task.dart';
import '../model/tombstone.dart';
import '../result.dart';
import '../time/local_time.dart';

/// §11.4.6. Storage for Ideas.
abstract interface class IdeaRepository {
  /// IDEAS-4. Every Idea, oldest first, as a live stream.
  ///
  /// §11.7: the lists watch this, so an edit updates the screen without a
  /// manual refresh.
  Stream<List<Idea>> watchAll();

  /// Returns the Idea with [id], or `null`.
  Future<Idea?> findById(String id);

  /// NAME-6, NAME-8. Returns the active Idea whose normalized name is
  /// [normalized], or `null`. Used to render the `"Open it"` link.
  Future<Idea?> findActiveByNormalizedName(String normalized);

  /// §2, NAME-6. The normalized names of every Idea, which is what the rules
  /// in `rules/idea_rules.dart` take.
  ///
  /// Every Idea is active: DEL-3 removes a deleted one outright rather than
  /// flagging it (INV-7), so unlike Tasks there is no inactive set to exclude.
  Future<Set<String>> activeNormalizedNames();

  /// CREATE-1, CREATE-4. Persists a new Idea durably before returning.
  ///
  /// Returns [IdeaNameCollision] if the name is taken, whether the application
  /// check or the unique index catches it (§11.5.2).
  Future<Result<Idea, RuleViolation>> create(Idea idea);

  /// Persists an edit to an existing Idea.
  Future<Result<Idea, RuleViolation>> update(Idea idea);

  /// DEL-3. Removes the Idea and writes its tombstone, in one transaction.
  Future<void> delete(String id, DateTime now);
}

/// §11.4.6. Storage for Tasks.
abstract interface class TaskRepository {
  /// TODO-1, TODO-2. The To Do list: not deleted, not archived, oldest first.
  Stream<List<Task>> watchActive();

  /// ARCH-1. Archived, not deleted, newest first.
  Stream<List<Task>> watchArchived();

  /// SEARCH-2. Every Task this replica holds, including archived and
  /// soft-deleted ones, oldest first.
  ///
  /// Search filters on `Todo / Blocked / Done / Archived / Deleted`, and a
  /// soft-deleted Task appears in no other stream — so without this the Search
  /// screen would have to reach past the repository, which STORE-2 forbids.
  /// Filtering is `SearchQuery`'s (§5.10); this is only the source.
  Stream<List<Task>> watchAll();

  /// Returns the Task with [id], or `null`.
  Future<Task?> findById(String id);

  /// NAME-6, NAME-8, NAME-9. Returns the active Task whose normalized name is
  /// [normalized], or `null`.
  Future<Task?> findActiveByNormalizedName(String normalized);

  /// §2, NAME-7. The normalized names of every active Task, which is what the
  /// rules in `rules/task_rules.dart` take.
  Future<Set<String>> activeNormalizedNames();

  /// CREATE-2, CREATE-4. Persists a new Task durably before returning.
  Future<Result<Task, RuleViolation>> create(Task task);

  /// Persists an edit, replacing the subtask list wholesale (§11.5.1).
  Future<Result<Task, RuleViolation>> update(Task task);

  /// DEL-1. Soft-deletes the Task. Never a hard delete (principle 1.2.4).
  Future<Result<Task, RuleViolation>> softDelete(String id, DateTime now);

  /// DEL-2, NAME-9. Restores a soft-deleted Task, refusing on a name collision.
  Future<Result<Task, RuleViolation>> restore(String id, DateTime now);

  /// ARCH-3, ARCH-4, NAME-9. Unarchives a Task, refusing on a name collision.
  Future<Result<Task, RuleViolation>> unarchive(String id, DateTime now);

  /// EOD-2, EOD-3, STORE-3. Archives every Task whose boundary has passed, in
  /// one transaction, and returns them.
  ///
  /// §11.5.4: every time input arrives as an explicit parameter rather than
  /// being read from a clock or the settings inside the repository. That keeps
  /// this a pure transactional primitive, keeps §11.11's rule that time is
  /// passed in rather than hidden, and lets AC-6 be written without a settings
  /// round-trip. `ArchiveSweeper` is what reads [endOfDay] and [zoneId] and
  /// calls this.
  ///
  /// Idempotent, so running it at start, on foreground and at each boundary
  /// costs nothing extra (§11.5.4).
  Future<List<Task>> runArchiveSweep({
    required DateTime nowUtc,
    required LocalTime endOfDay,
    required String zoneId,
  });
}

/// §11.4.6. Storage for the per-replica settings of §3.6 and §11.8.
///
/// MERGE-3: settings are never merged and never travel in a snapshot.
abstract interface class SettingsRepository {
  /// The current settings, as a live stream so the theme and decor react
  /// immediately (SET-2).
  Stream<Settings> watch();

  /// Reads the current settings once.
  Future<Settings> read();

  /// SET-2. Persists [settings] immediately.
  Future<void> write(Settings settings);
}

/// HIST-2. The append-only event log.
///
/// Local-only: it never travels in a snapshot, and §11.5.1 caps it.
abstract interface class EventLog {
  /// Appends [event].
  Future<void> append(ItemEvent event);

  /// Every recorded event for [itemId], oldest first.
  ///
  /// The MVP does not show the log in the UI; this exists for audit and for
  /// future merge strategies (§9.1).
  Future<List<ItemEvent>> forItem(String itemId);

  /// §11.5.1. Applies the log's cap, returning how many entries it removed.
  ///
  /// "On each app start, delete entries older than 365 days, keeping at least
  /// the most recent 5,000 regardless of age." The retention window is counted
  /// back from [nowUtc]; the floor is **global**, not per item; and both
  /// numbers are one named constant in the implementation, so the cap can be
  /// raised in one place if the log ever becomes useful for a better merge
  /// strategy (§9.1).
  Future<int> prune(DateTime nowUtc);
}

/// §11.4.6, §9.3 step 1. Storage for Idea tombstones.
abstract interface class TombstoneStore {
  /// Every tombstone this replica holds, for inclusion in a snapshot.
  Future<List<IdeaTombstone>> all();

  /// INV-7. The ids of every tombstoned Idea.
  Future<Set<String>> tombstonedIdeaIds();

  /// Records [tombstone], ignoring one that is already present.
  Future<void> add(IdeaTombstone tombstone);
}

/// §11.4.6, CONVERT-4. Converting an Idea into a Task, atomically.
///
/// "Declared as a single method so that atomicity cannot be lost by a caller":
/// creating the Task, removing the Idea and writing the tombstone are one
/// transaction (STORE-3, AC-11).
abstract interface class ConversionService {
  /// CONVERT-3, CONVERT-4. Commits [draft] and consumes [idea].
  ///
  /// [draft] comes from `draftTaskFromIdea` with the user's edits applied
  /// (CONVERT-2). Returns [TaskNameCollision] without touching [idea] if the
  /// name is taken (CONVERT-3).
  Future<Result<Task, RuleViolation>> convert(
    Idea idea,
    Task draft,
    DateTime now,
  );
}

/// §11.5.1. The one-row table identifying this installation.
abstract interface class ReplicaRepository {
  /// This device's `replicaId`, a UUIDv7 generated on first launch.
  Future<String> replicaId();

  /// This device's name, used in pairing (§11.6.4) and snapshots (§11.6.1).
  Future<String> deviceName();
}

/// §11.6.5 step 6, §11.6.6. Replaces this replica's whole dataset in one
/// transaction.
///
/// Declared as a single method for the same reason as [ConversionService]: the
/// atomicity *is* the operation, and a caller assembling it from smaller writes
/// would lose it (§11.4.6).
///
/// Two callers, both of which replace rather than reconcile:
///
/// * §11.6.5 step 6 applies a [MergeResult]. §11.6.5 requires wholesale
///   replacement rather than a row-by-row upsert, because SQLite evaluates
///   unique indexes per statement and has no deferrable constraints, so
///   upserting transiently collides whenever two Tasks swap names.
/// * §11.6.6's `"Restore from backup…"` applies a backup snapshot. §11.8 is
///   explicit that this is the *only* replace in the app; `"Import snapshot…"`
///   is a merge.
///
/// Implementations MUST follow STORE-4's order. The schema forces it, and
/// getting it wrong aborts the transaction rather than failing a test.
abstract interface class DatasetRepository {
  /// STORE-3, STORE-4. Replaces the Ideas, Tasks and tombstones with
  /// [snapshot]'s, in one transaction.
  ///
  /// Settings and the event log are untouched (MERGE-3, STORE-4): settings are
  /// per replica and never merged, and `events` carries no foreign key
  /// precisely so that the history of how the data got here survives the data
  /// being replaced.
  ///
  /// [ReplicaSnapshot.replicaId] is not written anywhere — this device's
  /// identity is its own (§11.5.1), not the snapshot's.
  Future<void> replaceAll(ReplicaSnapshot snapshot);
}

/// §2. Which kind of Item a repository call is about, where one signature
/// serves both.
typedef ItemRef = ({String id, ItemKind kind});

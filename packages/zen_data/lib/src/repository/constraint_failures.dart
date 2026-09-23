/// §11.5.2. Turning a SQLite constraint failure into a [RuleViolation].
///
/// "Violations are detected by attempting the write, not by pre-checking it. A
/// `SELECT` before an `INSERT` has a time-of-check-to-time-of-use window, and
/// it also means the index under test never fires, so M3's definition of done
/// would be satisfied by code that never exercises the constraint at all."
///
/// So the repositories attempt the write and translate what comes back. The
/// mapping keys on SQLite's **numeric extended result code** plus the
/// constraint or table name, never on the message prose, which varies between
/// SQLite builds.
library;

import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:zen_domain/zen_domain.dart';

/// §11.5.2. `SQLITE_CONSTRAINT_UNIQUE` — a unique index rejected the row.
const int sqliteConstraintUnique = 2067;

/// §11.5.2. `SQLITE_CONSTRAINT_PRIMARYKEY` — a primary key rejected the row.
///
/// The tag tables key on `(owner_id, value_normalized)`, so TAG-4's per-Item
/// uniqueness surfaces as this rather than as [sqliteConstraintUnique].
const int sqliteConstraintPrimaryKey = 1555;

/// §11.5.2. `SQLITE_CONSTRAINT_CHECK` — a named `CHECK` rejected the row.
const int sqliteConstraintCheck = 275;

/// §11.5.2. `SQLITE_CONSTRAINT_TRIGGER` — a trigger's `RAISE(ABORT, …)` fired.
const int sqliteConstraintTrigger = 1811;

/// §11.5.2. `SQLITE_CONSTRAINT_FOREIGNKEY`.
const int sqliteConstraintForeignKey = 787;

/// §11.5.2. Whether [error] is the unique-index violation for [table]'s
/// `name_normalized` column — NAME-6.
///
/// The index name is not in the message SQLite produces; `table.column` is,
/// which is enough to tell the Ideas index from the Tasks one. The extended
/// result code is what establishes that this is a uniqueness failure at all.
bool isNameCollision(Object error, String table) =>
    error is SqliteException &&
    error.extendedResultCode == sqliteConstraintUnique &&
    error.message.contains('$table.name_normalized');

/// Runs [write], translating a NAME-6 collision on `ideas` into
/// [IdeaNameCollision] (NAME-8).
///
/// Every other failure is rethrown: a `CHECK` or trigger failing is a bug in
/// this package or a corrupt database, not something the user did, and
/// §11.4.1 reserves exceptions for exactly that.
Future<Result<T, RuleViolation>> translatingIdeaNameCollision<T>(
  Future<T> Function() write,
) async {
  try {
    return Ok<T, RuleViolation>(await write());
  } on SqliteException catch (error) {
    if (isNameCollision(error, 'ideas')) {
      return Err<T, RuleViolation>(const IdeaNameCollision());
    }
    rethrow;
  }
}

/// Runs [write], translating a NAME-6 collision on `tasks` into [onCollision].
///
/// The index cannot tell NAME-8 from NAME-9 — both are the same collision on
/// the same partial index — so the caller supplies the violation that matches
/// the operation it is performing: [TaskNameCollision] when saving, and
/// [ActiveTaskHoldsName] when restoring or unarchiving (NAME-9, AC-10).
Future<Result<T, RuleViolation>> translatingTaskNameCollision<T>(
  Future<T> Function() write, {
  required RuleViolation onCollision,
}) async {
  try {
    return Ok<T, RuleViolation>(await write());
  } on SqliteException catch (error) {
    if (isNameCollision(error, 'tasks')) {
      return Err<T, RuleViolation>(onCollision);
    }
    rethrow;
  }
}

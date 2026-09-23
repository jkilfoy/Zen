/// Shared setup for `zen_data`'s tests.
///
/// Two ways in, deliberately:
///
/// * [openTestDatabase] plus the raw-SQL helpers below, for the constraint
///   tests. Those bypass the repositories entirely — a constraint that is only
///   ever reached through a repository is not tested, because the test would
///   pass identically if the constraint were missing (§11.5.2).
/// * [TestRepositories], for the tests that are about behaviour.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_data/zen_data.dart';
import 'package:zen_domain/testing.dart';
import 'package:zen_domain/zen_domain.dart';

/// An arbitrary fixed instant, at millisecond precision (§3, INV-9).
final DateTime base = DateTime.utc(2026, 9, 22, 12);

/// [base] plus [minutes].
DateTime at(int minutes) => base.add(Duration(minutes: minutes));

/// Opens an in-memory database and closes it when the test ends.
///
/// §11.13.1 puts M3 in the headless column: Drift runs on Linux and an
/// in-memory database needs no device.
AppDatabase openTestDatabase() {
  final AppDatabase db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

/// The repositories under test, wired over one database.
final class TestRepositories {
  /// Builds the set over a fresh in-memory database.
  factory TestRepositories() {
    final AppDatabase db = openTestDatabase();
    final IdGenerator ids = SequentialIdGenerator(prefix: 'event');
    const TimeZoneRules zone = TorontoTimeZoneRules();
    return TestRepositories._(
      db: db,
      ideas: DriftIdeaRepository(db, ids: ids),
      tasks: DriftTaskRepository(db, ids: ids, zone: zone),
      conversions: DriftConversionService(db, ids: ids),
      tombstones: DriftTombstoneStore(db),
      settings: DriftSettingsRepository(db),
      events: DriftEventLog(db),
      replica: DriftReplicaRepository(
        db,
        ids: SequentialIdGenerator(prefix: 'replica'),
        defaultDeviceName: 'test-device',
      ),
      zone: zone,
    );
  }

  const TestRepositories._({
    required this.db,
    required this.ideas,
    required this.tasks,
    required this.conversions,
    required this.tombstones,
    required this.settings,
    required this.events,
    required this.replica,
    required this.zone,
  });

  /// The database the repositories share.
  final AppDatabase db;

  /// §11.4.6. Ideas.
  final DriftIdeaRepository ideas;

  /// §11.4.6. Tasks.
  final DriftTaskRepository tasks;

  /// §11.4.6, CONVERT-4.
  final DriftConversionService conversions;

  /// §11.4.6, §9.3 step 1.
  final DriftTombstoneStore tombstones;

  /// §11.4.6, §3.6.
  final DriftSettingsRepository settings;

  /// §11.4.6, HIST-2.
  final DriftEventLog events;

  /// §11.5.1. This installation's identity.
  final DriftReplicaRepository replica;

  /// EOD-5. The zone fixture the sweep tests use.
  final TimeZoneRules zone;
}

// ---------------------------------------------------------------------------
// Entity builders. Every one defaults to a well-formed record, so a test
// states only the field it is about.
// ---------------------------------------------------------------------------

/// Parses [raw] as an [ItemName], failing the test if it is invalid.
ItemName name(String raw) => ItemName.parse(raw).unwrap();

/// Parses [raw] as a [SubtaskName], failing the test if it is invalid.
SubtaskName subtaskName(String raw) => SubtaskName.parse(raw).unwrap();

/// Parses [raw] as a [Tag], failing the test if it is invalid.
Tag tag(String raw) => Tag.parse(raw).unwrap();

/// A well-formed [Idea].
Idea anIdea({
  String id = 'idea-1',
  String named = 'An idea',
  Timeframe timeframe = Timeframe.now,
  List<Tag> tags = const <Tag>[],
  String context = '',
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final DateTime created = createdAt ?? base;
  return Idea(
    id: id,
    name: name(named),
    tags: tags,
    context: ItemText.parseContext(context).unwrap(),
    timeframe: timeframe,
    createdAt: created,
    updatedAt: updatedAt ?? created,
  );
}

/// A well-formed [Subtask], `Todo` unless told otherwise.
Subtask aSubtask({
  String id = 'sub-1',
  String named = 'A subtask',
  TaskStatus status = TaskStatus.todo,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final DateTime created = createdAt ?? base;
  final DateTime updated = updatedAt ?? created;
  return Subtask(
    id: id,
    name: subtaskName(named),
    status: status,
    createdAt: created,
    updatedAt: updated,
    completedAt: status == TaskStatus.done ? updated : null,
  );
}

/// A well-formed [Task], `Todo` with no subtasks unless told otherwise.
Task aTask({
  String id = 'task-1',
  String named = 'A task',
  TaskStatus status = TaskStatus.todo,
  List<Subtask> subtasks = const <Subtask>[],
  List<Tag> tags = const <Tag>[],
  String description = '',
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? completedAt,
  bool isArchived = false,
  DateTime? archivedAt,
  bool isDeleted = false,
  DateTime? deletedAt,
  String? sourceIdeaId,
  DateTime? sourceIdeaCreatedAt,
}) {
  final DateTime created = createdAt ?? base;
  final DateTime updated = updatedAt ?? created;
  return Task(
    id: id,
    name: name(named),
    tags: tags,
    description: ItemText.parseDescription(description).unwrap(),
    status: status,
    subtasks: subtasks,
    createdAt: created,
    updatedAt: updated,
    completedAt: status == TaskStatus.done ? (completedAt ?? updated) : null,
    isArchived: isArchived,
    archivedAt: isArchived ? (archivedAt ?? updated) : null,
    isDeleted: isDeleted,
    deletedAt: isDeleted ? (deletedAt ?? updated) : null,
    sourceIdeaId: sourceIdeaId,
    sourceIdeaCreatedAt: sourceIdeaCreatedAt,
  );
}

// ---------------------------------------------------------------------------
// Raw SQL, for the constraint tests.
// ---------------------------------------------------------------------------

/// Inserts an `ideas` row in raw SQL, with every column overridable.
///
/// Deliberately not routed through [ideaToRow]: these tests are about what the
/// *schema* refuses, so they must be able to write rows the mapper never would.
Future<void> insertIdeaRow(
  AppDatabase db, {
  String id = 'i1',
  String itemName = 'Read SICP',
  String? nameNormalized,
  String context = '',
  String timeframe = 'now',
  String? createdAt,
  String? updatedAt,
}) => db.customStatement(
  'INSERT INTO ideas '
  '(id, name, name_normalized, context, timeframe, created_at, updated_at) '
  'VALUES (?, ?, ?, ?, ?, ?, ?)',
  <Object?>[
    id,
    itemName,
    nameNormalized ?? normalizeName(itemName),
    context,
    timeframe,
    createdAt ?? encodeInstant(base),
    updatedAt ?? encodeInstant(base),
  ],
);

/// Inserts a `tasks` row in raw SQL, with every column overridable.
Future<void> insertTaskRow(
  AppDatabase db, {
  String id = 't1',
  String itemName = 'Buy milk',
  String? nameNormalized,
  String description = '',
  String status = 'todo',
  String? createdAt,
  String? updatedAt,
  String? completedAt,
  int isArchived = 0,
  String? archivedAt,
  int isDeleted = 0,
  String? deletedAt,
  String? sourceIdeaId,
  String? sourceIdeaCreatedAt,
}) => db.customStatement(
  'INSERT INTO tasks '
  '(id, name, name_normalized, description, status, created_at, updated_at, '
  'completed_at, is_archived, archived_at, is_deleted, deleted_at, '
  'source_idea_id, source_idea_created_at) '
  'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
  <Object?>[
    id,
    itemName,
    nameNormalized ?? normalizeName(itemName),
    description,
    status,
    createdAt ?? encodeInstant(base),
    updatedAt ?? encodeInstant(base),
    completedAt,
    isArchived,
    archivedAt,
    isDeleted,
    deletedAt,
    sourceIdeaId,
    sourceIdeaCreatedAt,
  ],
);

/// Inserts a `subtasks` row in raw SQL.
Future<void> insertSubtaskRow(
  AppDatabase db, {
  String id = 's1',
  String taskId = 't1',
  String subtaskNameValue = 'A subtask',
  String status = 'todo',
  int sortIndex = 0,
  String? createdAt,
  String? updatedAt,
  String? completedAt,
}) => db.customStatement(
  'INSERT INTO subtasks '
  '(id, task_id, name, status, sort_index, created_at, updated_at, '
  'completed_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
  <Object?>[
    id,
    taskId,
    subtaskNameValue,
    status,
    sortIndex,
    createdAt ?? encodeInstant(base),
    updatedAt ?? encodeInstant(base),
    completedAt,
  ],
);

/// Inserts an `idea_tags` row in raw SQL.
Future<void> insertIdeaTagRow(
  AppDatabase db, {
  String ownerId = 'i1',
  String value = 'cs',
  String? valueNormalized,
  int sortIndex = 0,
}) => db.customStatement(
  'INSERT INTO idea_tags (owner_id, value, value_normalized, sort_index) '
  'VALUES (?, ?, ?, ?)',
  <Object?>[ownerId, value, valueNormalized ?? normalizeTag(value), sortIndex],
);

/// Inserts an `idea_tombstones` row in raw SQL.
Future<void> insertTombstoneRow(
  AppDatabase db, {
  String id = 'i1',
  String? deletedAt,
  String reason = 'deleted',
}) => db.customStatement(
  'INSERT INTO idea_tombstones (id, deleted_at, reason) VALUES (?, ?, ?)',
  <Object?>[id, deletedAt ?? encodeInstant(base), reason],
);

// ---------------------------------------------------------------------------
// Matchers for what the schema refuses.
// ---------------------------------------------------------------------------

/// Matches the [SqliteException] a named `CHECK` constraint raises.
///
/// Keys on the numeric extended result code, per §11.5.2, and on the
/// constraint's name so that a test cannot pass because some *other* constraint
/// happened to fire first.
Matcher violatesCheck(String constraintName) => throwsA(
  isA<SqliteException>()
      .having(
        (SqliteException e) => e.extendedResultCode,
        'extendedResultCode',
        sqliteConstraintCheck,
      )
      .having(
        (SqliteException e) => e.message,
        'message',
        contains(constraintName),
      ),
);

/// Matches the [SqliteException] a unique index or primary key raises on
/// [tableAndColumns], e.g. `'ideas.name_normalized'`.
Matcher violatesUnique(String tableAndColumns) => throwsA(
  isA<SqliteException>()
      .having(
        (SqliteException e) => e.extendedResultCode,
        'extendedResultCode',
        anyOf(sqliteConstraintUnique, sqliteConstraintPrimaryKey),
      )
      .having(
        (SqliteException e) => e.message,
        'message',
        contains(tableAndColumns),
      ),
);

/// Matches the [SqliteException] a trigger's `RAISE(ABORT, …)` raises, whose
/// message names the invariant it defends.
Matcher violatesTrigger(String invariant) => throwsA(
  isA<SqliteException>()
      .having(
        (SqliteException e) => e.extendedResultCode,
        'extendedResultCode',
        sqliteConstraintTrigger,
      )
      .having((SqliteException e) => e.message, 'message', contains(invariant)),
);

/// Matches the [SqliteException] a foreign key raises.
Matcher violatesForeignKey() => throwsA(
  isA<SqliteException>().having(
    (SqliteException e) => e.extendedResultCode,
    'extendedResultCode',
    sqliteConstraintForeignKey,
  ),
);

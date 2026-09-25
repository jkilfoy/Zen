/// §11.6.1. The JSON codec for the snapshot format.
///
/// This file and `snapshot_envelope.dart` are the whole of what §9.1 gives
/// `zen_sync` over the merge: "the envelope and the codec". The domain types it
/// reads and writes belong to `zen_domain` and are never redeclared here.
library;

import 'dart:convert';

import 'package:zen_domain/zen_domain.dart';

import '../sync_log.dart';
import 'snapshot_envelope.dart';
import 'snapshot_format_failure.dart';
import 'snapshot_json.dart';

/// §11.6.1. Encodes and decodes the versioned snapshot JSON.
///
/// **Settings never appear here** (MERGE-3, §11.6.1). They are per replica and
/// are never merged, so a snapshot that carried them would quietly overwrite
/// the other device's preferences on the next sync. Neither does the event log.
/// There is a test for both, because their absence is a property of this file
/// that nothing else would notice breaking.
final class SnapshotCodec {
  /// Creates a codec that reports warnings to [log].
  ///
  /// The only warning it raises is §11.6.1's `nameNormalized` mismatch;
  /// everything else that goes wrong is a [SnapshotFormatFailure] returned to
  /// the caller.
  const SnapshotCodec({
    SyncLogger log = discardSyncLog,
    // `prefer_initializing_formals` suggests `this._log`, which Dart forbids: a
    // named parameter may not begin with an underscore.
    // ignore: prefer_initializing_formals
  }) : _log = log;

  final SyncLogger _log;

  /// Two-space indent, because these files land in a folder the user can open,
  /// and `"Export snapshot…"` (§11.8) hands one to them directly.
  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  /// §11.6.1. Encodes [envelope] as the snapshot document.
  ///
  /// Deterministic: every map is built in a fixed key order and §9.3 step 8 has
  /// already put `ideas`, `tasks` and `tombstones` in canonical order, so equal
  /// datasets encode to equal bytes. That is what lets §11.6.5 step 7 compare
  /// content and skip an unnecessary write — though only of the snapshot body,
  /// since [SnapshotEnvelope.generatedAt] moves on every pass (§9.3 step 8).
  String encode(SnapshotEnvelope envelope) =>
      _encoder.convert(toJson(envelope));

  /// §11.6.1. Builds the JSON document for [envelope].
  ///
  /// Separate from [encode] so tests can assert the shape of the document
  /// without going through a string.
  Map<String, Object?> toJson(SnapshotEnvelope envelope) => <String, Object?>{
    'formatVersion': envelope.formatVersion,
    'replicaId': envelope.replicaId,
    'deviceName': envelope.deviceName,
    'generatedAt': _instant(envelope.generatedAt),
    'appVersion': envelope.appVersion,
    'ideas': envelope.snapshot.ideas.map(_ideaToJson).toList(growable: false),
    'tasks': envelope.snapshot.tasks.map(_taskToJson).toList(growable: false),
    'tombstones': envelope.snapshot.tombstones
        .map(_tombstoneToJson)
        .toList(growable: false),
  };

  /// §11.6.1. Decodes a snapshot document from [source].
  ///
  /// **All-or-nothing.** Any unreadable record refuses the whole document, per
  /// §11.6.1: dropping the one bad record "would be the quieter failure and
  /// therefore the worse one", because the sync would appear to succeed while
  /// carrying less than the peer holds, and this device would republish that
  /// reduced view.
  Result<SnapshotEnvelope, SnapshotFormatFailure> decode(String source) {
    final Object? parsed;
    try {
      parsed = jsonDecode(source);
    } on FormatException catch (error) {
      return Err<SnapshotEnvelope, SnapshotFormatFailure>(
        SnapshotNotJson(error.message),
      );
    }
    return fromJson(parsed);
  }

  /// §11.6.1. Decodes an already-parsed document.
  ///
  /// The `_Malformed` exception below is control flow *inside* this file only:
  /// threading a `Result` through thirty nested field reads would bury the
  /// shape of the format under plumbing. §11.4.1's rule holds at the boundary,
  /// which is what it is about — every public entry point returns a [Result].
  Result<SnapshotEnvelope, SnapshotFormatFailure> fromJson(Object? document) {
    try {
      final Map<String, Object?> root = jsonObject(document, r'$');

      // Checked before anything else is read: §11.6.1 requires that an unknown
      // version is "refused with a clear message rather than parsed
      // optimistically", and reading fields out of a format we do not
      // understand is exactly that optimism.
      final int formatVersion = jsonInt(root, 'formatVersion', 'formatVersion');
      if (formatVersion != SnapshotEnvelope.currentFormatVersion) {
        return Err<SnapshotEnvelope, SnapshotFormatFailure>(
          SnapshotVersionUnsupported(
            found: formatVersion,
            supported: SnapshotEnvelope.currentFormatVersion,
          ),
        );
      }

      final String replicaId = jsonString(root, 'replicaId', 'replicaId');
      final List<Idea> ideas = jsonList(
        root,
        'ideas',
      ).indexed.map(((int, Object?) e) => _ideaFromJson(e.$2, e.$1)).toList();
      final List<Task> tasks = jsonList(
        root,
        'tasks',
      ).indexed.map(((int, Object?) e) => _taskFromJson(e.$2, e.$1)).toList();
      final List<IdeaTombstone> tombstones = jsonList(root, 'tombstones')
          .indexed
          .map(((int, Object?) e) => _tombstoneFromJson(e.$2, e.$1))
          .toList();

      // INV-6 and INV-7 span the dataset, so no per-record check reaches them.
      // A replica's own database enforces both — the partial unique indexes and
      // the `inv7_*` triggers of §11.5.2 — so a snapshot that breaks either did
      // not come from a healthy replica and is refused like any other
      // unreadable file. This is *not* the case the merge exists to handle:
      // that one is two replicas each internally consistent but disagreeing
      // with each other, which is across snapshots, not within one.
      final List<String> broken = datasetInvariantFailures(
        ideas: ideas,
        tasks: tasks,
        tombstones: tombstones,
      );
      if (broken.isNotEmpty) {
        throw MalformedSnapshot(r'$', 'breaks §3.7 (${broken.join('; ')})');
      }

      return Ok<SnapshotEnvelope, SnapshotFormatFailure>(
        SnapshotEnvelope(
          formatVersion: formatVersion,
          replicaId: replicaId,
          deviceName: jsonString(root, 'deviceName', 'deviceName'),
          generatedAt: jsonInstant(root, 'generatedAt', 'generatedAt'),
          appVersion: jsonString(root, 'appVersion', 'appVersion'),
          snapshot: ReplicaSnapshot(
            replicaId: replicaId,
            ideas: ideas,
            tasks: tasks,
            tombstones: tombstones,
          ),
        ),
      );
    } on MalformedSnapshot catch (failure) {
      return Err<SnapshotEnvelope, SnapshotFormatFailure>(
        SnapshotFieldInvalid(path: failure.path, reason: failure.reason),
      );
    }
  }

  // ---------------------------------------------------------------- encoding

  Map<String, Object?> _ideaToJson(Idea idea) => <String, Object?>{
    'id': idea.id,
    'name': idea.name.value,
    'nameNormalized': idea.name.normalized,
    'tags': idea.tags.map((Tag t) => t.value).toList(growable: false),
    'context': idea.context.value,
    'timeframe': idea.timeframe.name,
    'createdAt': _instant(idea.createdAt),
    'updatedAt': _instant(idea.updatedAt),
  };

  Map<String, Object?> _taskToJson(Task task) => <String, Object?>{
    'id': task.id,
    'name': task.name.value,
    'nameNormalized': task.name.normalized,
    'tags': task.tags.map((Tag t) => t.value).toList(growable: false),
    'description': task.description.value,
    'status': task.status.name,
    // MERGE-3A: subtask order is user-controlled and visible, and §11.6.1 makes
    // the array order carry it. Nothing here may sort.
    'subtasks': task.subtasks.map(_subtaskToJson).toList(growable: false),
    'createdAt': _instant(task.createdAt),
    'updatedAt': _instant(task.updatedAt),
    'completedAt': _instantOrNull(task.completedAt),
    'isArchived': task.isArchived,
    'archivedAt': _instantOrNull(task.archivedAt),
    'isDeleted': task.isDeleted,
    'deletedAt': _instantOrNull(task.deletedAt),
    'sourceIdeaId': task.sourceIdeaId,
    'sourceIdeaCreatedAt': _instantOrNull(task.sourceIdeaCreatedAt),
  };

  Map<String, Object?> _subtaskToJson(Subtask subtask) => <String, Object?>{
    'id': subtask.id,
    'name': subtask.name.value,
    'status': subtask.status.name,
    'createdAt': _instant(subtask.createdAt),
    'updatedAt': _instant(subtask.updatedAt),
    'completedAt': _instantOrNull(subtask.completedAt),
  };

  Map<String, Object?> _tombstoneToJson(IdeaTombstone tombstone) =>
      <String, Object?>{
        'id': tombstone.id,
        'deletedAt': _instant(tombstone.deletedAt),
        'reason': tombstone.reason.name,
      };

  /// §3, INV-9. The exact 24-character form, `YYYY-MM-DDTHH:MM:SS.mmmZ`.
  static String _instant(DateTime instant) =>
      truncateToMilliseconds(instant).toIso8601String();

  static String? _instantOrNull(DateTime? instant) =>
      instant == null ? null : _instant(instant);

  // ---------------------------------------------------------------- decoding

  Idea _ideaFromJson(Object? value, int index) {
    final String path = 'ideas[$index]';
    final Map<String, Object?> json = jsonObject(value, path);
    final ItemName name = _itemName(json, path);
    return _guard(
      path,
      () => Idea(
        id: jsonString(json, 'id', '$path.id'),
        name: name,
        tags: _tags(json, path),
        context: _itemText(
          ItemText.parseContext(jsonString(json, 'context', '$path.context')),
          '$path.context',
        ),
        timeframe: jsonEnum(
          Timeframe.values,
          jsonString(json, 'timeframe', '$path.timeframe'),
          '$path.timeframe',
        ),
        createdAt: jsonInstant(json, 'createdAt', '$path.createdAt'),
        updatedAt: jsonInstant(json, 'updatedAt', '$path.updatedAt'),
      ),
      (Idea idea) => idea.invariantFailures,
    );
  }

  Task _taskFromJson(Object? value, int index) {
    final String path = 'tasks[$index]';
    final Map<String, Object?> json = jsonObject(value, path);
    final ItemName name = _itemName(json, path);
    final List<Subtask> subtasks = jsonList(json, 'subtasks').indexed
        .map(((int, Object?) e) => _subtaskFromJson(e.$2, path, e.$1))
        .toList(growable: false);
    return _guard(
      path,
      () => Task(
        id: jsonString(json, 'id', '$path.id'),
        name: name,
        tags: _tags(json, path),
        description: _itemText(
          ItemText.parseDescription(
            jsonString(json, 'description', '$path.description'),
          ),
          '$path.description',
        ),
        status: jsonEnum(
          TaskStatus.values,
          jsonString(json, 'status', '$path.status'),
          '$path.status',
        ),
        subtasks: subtasks,
        createdAt: jsonInstant(json, 'createdAt', '$path.createdAt'),
        updatedAt: jsonInstant(json, 'updatedAt', '$path.updatedAt'),
        completedAt: jsonInstantOrNull(
          json,
          'completedAt',
          '$path.completedAt',
        ),
        isArchived: jsonBool(json, 'isArchived', '$path.isArchived'),
        archivedAt: jsonInstantOrNull(json, 'archivedAt', '$path.archivedAt'),
        isDeleted: jsonBool(json, 'isDeleted', '$path.isDeleted'),
        deletedAt: jsonInstantOrNull(json, 'deletedAt', '$path.deletedAt'),
        sourceIdeaId: jsonStringOrNull(
          json,
          'sourceIdeaId',
          '$path.sourceIdeaId',
        ),
        sourceIdeaCreatedAt: jsonInstantOrNull(
          json,
          'sourceIdeaCreatedAt',
          '$path.sourceIdeaCreatedAt',
        ),
      ),
      (Task task) => task.invariantFailures,
    );
  }

  Subtask _subtaskFromJson(Object? value, String taskPath, int index) {
    final String path = '$taskPath.subtasks[$index]';
    final Map<String, Object?> json = jsonObject(value, path);
    return _guard(
      path,
      () => Subtask(
        id: jsonString(json, 'id', '$path.id'),
        name: _subtaskName(
          SubtaskName.parse(jsonString(json, 'name', '$path.name')),
          '$path.name',
        ),
        status: jsonEnum(
          TaskStatus.values,
          jsonString(json, 'status', '$path.status'),
          '$path.status',
        ),
        createdAt: jsonInstant(json, 'createdAt', '$path.createdAt'),
        updatedAt: jsonInstant(json, 'updatedAt', '$path.updatedAt'),
        completedAt: jsonInstantOrNull(
          json,
          'completedAt',
          '$path.completedAt',
        ),
      ),
      (Subtask subtask) => subtask.invariantFailures,
    );
  }

  IdeaTombstone _tombstoneFromJson(Object? value, int index) {
    final String path = 'tombstones[$index]';
    final Map<String, Object?> json = jsonObject(value, path);
    return IdeaTombstone(
      id: jsonString(json, 'id', '$path.id'),
      deletedAt: jsonInstant(json, 'deletedAt', '$path.deletedAt'),
      reason: jsonEnum(
        TombstoneReason.values,
        jsonString(json, 'reason', '$path.reason'),
        '$path.reason',
      ),
    );
  }

  /// §11.6.1. Parses the name and checks the peer's `nameNormalized` against
  /// the form this device derives.
  ///
  /// "`nameNormalized` is written but never read back. `ItemName` is
  /// constructible only through `parse`, which recomputes the normalized form,
  /// and that is deliberate: honouring a peer's value would let two replicas
  /// compute *different* merges from the same inputs whenever their
  /// normalization disagreed, breaking MERGE-2."
  ///
  /// A mismatch is still worth saying out loud — it means two replicas normalize
  /// differently, which MERGE-5's name matching rests on — so it is logged and
  /// the locally derived form is used.
  ItemName _itemName(Map<String, Object?> json, String path) {
    final String raw = jsonString(json, 'name', '$path.name');
    final Result<ItemName, RuleViolation> parsed = ItemName.parse(raw);
    final ItemName name = switch (parsed) {
      Ok<ItemName, RuleViolation>(:final ItemName value) => value,
      Err<ItemName, RuleViolation>(:final RuleViolation error) =>
        throw MalformedSnapshot(
          '$path.name',
          'is not a valid name (${error.message})',
        ),
    };
    final String? claimed = jsonStringOrNull(
      json,
      'nameNormalized',
      '$path.nameNormalized',
    );
    if (claimed != null && claimed != name.normalized) {
      _log(
        'Snapshot $path: nameNormalized is "$claimed" but this device '
        'normalizes "${name.value}" to "${name.normalized}". Using the local '
        'form (§11.6.1). The two replicas may be normalizing differently, '
        'which affects how MERGE-5 matches names.',
      );
    }
    return name;
  }

  List<Tag> _tags(Map<String, Object?> json, String path) {
    final List<Object?> raw = jsonList(json, 'tags');
    // TAG-4. De-duplicated case-insensitively on the way in, the same as every
    // other write path: a peer that somehow emitted duplicates must not be able
    // to put a §3.5 violation into this replica's database.
    return dedupeTags(<Tag>[
      for (final (int index, Object? entry) in raw.indexed)
        switch (Tag.parse(jsonStringValue(entry, '$path.tags[$index]'))) {
          Ok<Tag, RuleViolation>(:final Tag value) => value,
          Err<Tag, RuleViolation>(:final RuleViolation error) =>
            throw MalformedSnapshot(
              '$path.tags[$index]',
              'is not a valid tag (${error.message})',
            ),
        },
    ]);
  }

  static ItemText _itemText(
    Result<ItemText, RuleViolation> parsed,
    String path,
  ) => switch (parsed) {
    Ok<ItemText, RuleViolation>(:final ItemText value) => value,
    Err<ItemText, RuleViolation>(:final RuleViolation error) =>
      throw MalformedSnapshot(path, 'is not valid text (${error.message})'),
  };

  static SubtaskName _subtaskName(
    Result<SubtaskName, RuleViolation> parsed,
    String path,
  ) => switch (parsed) {
    Ok<SubtaskName, RuleViolation>(:final SubtaskName value) => value,
    Err<SubtaskName, RuleViolation>(:final RuleViolation error) =>
      throw MalformedSnapshot(
        path,
        'is not a valid subtask name (${error.message})',
      ),
  };

  /// §3.7. Builds an entity and refuses it if it breaks an invariant.
  ///
  /// Two checks, because only one of them runs in any given build. The entity
  /// constructors `assert` their invariants (§11.4.1), and Dart strips asserts
  /// from release builds — so in a debug build or a test the construction
  /// throws, and in release it succeeds and [failures] is what catches it. Both
  /// paths end in the same refusal, which is what keeps this file's behaviour
  /// the same in the app the owner runs as in the tests that check it.
  static T _guard<T>(
    String path,
    T Function() build,
    List<String> Function(T) failures,
  ) {
    final T value;
    try {
      value = build();
    } on AssertionError catch (error) {
      throw MalformedSnapshot(path, 'breaks §3.7 (${error.message})');
    }
    final List<String> broken = failures(value);
    if (broken.isNotEmpty) {
      throw MalformedSnapshot(path, 'breaks §3.7 (${broken.join('; ')})');
    }
    return value;
  }
}

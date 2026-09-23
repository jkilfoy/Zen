/// §11.12 item 2. Hand-written generators over random snapshots, driven by a
/// **seeded** [Random] so that any failure reproduces from the seed in its
/// message.
///
/// §11.2 rules out a property-testing dependency, so these are plain functions.
/// They deliberately draw ids, names, tags and subtask names from small shared
/// pools: the merge is only interesting where records *collide*, and generators
/// that drew freely would almost never produce two records with the same id or
/// the same normalized name.
///
/// Every snapshot they produce is **valid** — it satisfies
/// `datasetInvariantFailures` — because §11.12's invariant-preservation
/// property is a claim about valid inputs. `merge_property_test.dart` asserts
/// that of the inputs too, so a generator bug reports itself as a generator bug
/// rather than as a merge failure.
library;

import 'dart:math';

import 'package:zen_domain/zen_domain.dart';

import 'fixtures.dart';

/// Generates random replica snapshots from a seed.
final class SnapshotGenerator {
  /// Creates a generator for [seed]. The seed is carried so tests can put it in
  /// their failure messages.
  SnapshotGenerator(this.seed) : _random = Random(seed);

  /// The seed this generator was created with.
  final int seed;

  final Random _random;

  /// Ids are shared across replicas so that components form by `id`.
  static const int _ideaIdCount = 6;
  static const int _taskIdCount = 6;
  static const int _subtaskIdCount = 5;

  /// A small name pool, so that components also form by *name* (MERGE-5).
  static const List<String> _names = <String>[
    'Read SICP',
    'Buy milk',
    'Water the plants',
    'Call the bank',
  ];

  /// Two subtask names only, so NAME-11 duplicates — and therefore step 5's
  /// name-position fall-back — come up constantly.
  static const List<String> _subtaskNames = <String>['Set', 'Rep'];

  static const List<String> _tags = <String>['home', 'Work', 'ERRAND'];

  /// Generates [count] replica snapshots that plausibly diverged from a shared
  /// history: overlapping ids, overlapping names, independent edits.
  List<ReplicaSnapshot> replicas({int count = 2}) => <ReplicaSnapshot>[
    for (int i = 0; i < count; i++) _snapshot('replica-$i'),
  ];

  /// §9.3 step 6, second bullet. Generates the one shape that reaches the
  /// **name re-pass**, which [replicas] hits vanishingly rarely — it needs four
  /// things at once, and measured over 300 seeds it never produced all four.
  ///
  /// The shape: replica A holds an archived Task and, legally under NAME-7, an
  /// *active* Task of the same name. Replica B holds the archived one's `id`,
  /// still active and since renamed, with an extra open subtask. The archived
  /// record becomes the primary by `updatedAt` and carries its name out; the
  /// sticky `Done` plus that open subtask trip the INV-2 repair, which
  /// un-archives the result — and it lands on the name the other active Task
  /// already holds.
  ///
  /// Everything but the shape is randomized, including which `id` sorts
  /// smaller and whether the archived record actually wins the primary slot,
  /// so the properties still see a spread of cases rather than one fixture.
  List<ReplicaSnapshot> archivedNameCollisionReplicas() {
    final String sharedId = _chance(0.5) ? 'task-aaa' : 'task-zzz';
    final String otherId = _chance(0.5) ? 'task-bbb' : 'task-mmm';

    final int nameIndex = _random.nextInt(_names.length);
    final String archivedName = _names[nameIndex];
    final String renamedTo = _names[(nameIndex + 1) % _names.length];

    // Whether the archived record wins the primary slot. When it does not, the
    // re-pass does not fire — a case the properties should see too.
    final bool archivedIsPrimary = _chance(0.7);
    final DateTime archivedUpdatedAt = at(archivedIsPrimary ? 80 : 20);
    final DateTime liveUpdatedAt = at(archivedIsPrimary ? 20 : 80);

    final ReplicaSnapshot a = aSnapshot(
      replicaId: 'replica-archived',
      tasks: <Task>[
        aTask(
          id: sharedId,
          named: archivedName,
          status: TaskStatus.done,
          isArchived: true,
          updatedAt: archivedUpdatedAt,
          subtasks: <Subtask>[
            aSubtask(
              id: '$sharedId-sub-0',
              named: _pick(_subtaskNames),
              status: TaskStatus.done,
              updatedAt: archivedUpdatedAt,
            ),
          ],
        ),
        // NAME-7: the archived Task reserves no name, so this is legal — and
        // it is the name the repaired Task is about to land on.
        aTask(
          id: otherId,
          named: archivedName,
          status: _pick(const <TaskStatus>[
            TaskStatus.todo,
            TaskStatus.blocked,
          ]),
          tags: _tagList(),
          describedAs: description(_text()),
          updatedAt: _instant(0, 60),
        ),
      ],
    );

    final ReplicaSnapshot b = aSnapshot(
      replicaId: 'replica-live',
      tasks: <Task>[
        aTask(
          id: sharedId,
          named: renamedTo,
          updatedAt: liveUpdatedAt,
          tags: _tagList(),
          describedAs: description(_text()),
          subtasks: <Subtask>[
            aSubtask(
              id: '$sharedId-sub-0',
              named: _pick(_subtaskNames),
              status: TaskStatus.done,
              updatedAt: liveUpdatedAt,
            ),
            // The open subtask that trips the INV-2 repair.
            aSubtask(
              id: '$sharedId-sub-1',
              named: _pick(_subtaskNames),
              updatedAt: liveUpdatedAt,
            ),
          ],
        ),
      ],
    );

    return <ReplicaSnapshot>[a, b];
  }

  ReplicaSnapshot _snapshot(String replicaId) {
    final List<Idea> ideas = _ideas();
    return aSnapshot(
      replicaId: replicaId,
      ideas: ideas,
      tasks: _tasks(),
      // INV-7: a tombstone's id must be absent from this replica's Ideas.
      tombstones: _tombstones(ideas.map((Idea i) => i.id).toSet()),
    );
  }

  // ------------------------------------------------------------------ Ideas

  List<Idea> _ideas() {
    final List<Idea> generated = <Idea>[
      for (int i = 0; i < _ideaIdCount; i++)
        if (_chance(0.6)) _idea('idea-$i'),
    ];
    // Every Idea is active (§2), so NAME-6 applies to all of them.
    return _withUniqueActiveNames<Idea>(
      generated,
      isActive: (Idea i) => i.isActive,
      normalizedNameOf: (Idea i) => i.name.normalized,
    );
  }

  Idea _idea(String id) {
    final DateTime createdAt = _instant(0, 40);
    return anIdea(
      id: id,
      named: _name(),
      tags: _tagList(),
      contextText: context(_text()),
      timeframe: _pick(Timeframe.values),
      createdAt: createdAt,
      updatedAt: _after(createdAt),
    );
  }

  // ------------------------------------------------------------------ Tasks

  List<Task> _tasks() {
    final List<Task> generated = <Task>[
      for (int i = 0; i < _taskIdCount; i++)
        if (_chance(0.6)) _task('task-$i'),
    ];
    return _withUniqueActiveNames<Task>(
      generated,
      isActive: (Task t) => t.isActive,
      normalizedNameOf: (Task t) => t.name.normalized,
    );
  }

  Task _task(String id) {
    final List<Subtask> subtasks = <Subtask>[
      for (int i = 0; i < _subtaskIdCount; i++)
        if (_chance(0.45)) _subtask('$id-sub-$i'),
    ];

    // INV-2: only a Task whose subtasks are all Done may be Done itself.
    final bool mayComplete = subtasks.every(
      (Subtask s) => s.status == TaskStatus.done,
    );
    final TaskStatus status = mayComplete
        ? _pick(TaskStatus.values)
        : _pick(const <TaskStatus>[TaskStatus.todo, TaskStatus.blocked]);

    final DateTime createdAt = _instant(0, 40);
    final DateTime updatedAt = _after(createdAt);
    // INV-3: archiving requires Done. INV-1 and INV-4 pair each timestamp with
    // its flag, which `aTask` maintains.
    final bool isArchived = status == TaskStatus.done && _chance(0.3);
    final bool isDeleted = _chance(0.2);
    final bool converted = _chance(0.25);

    return aTask(
      id: id,
      named: _name(),
      status: status,
      subtasks: subtasks,
      tags: _tagList(),
      describedAs: description(_text()),
      createdAt: createdAt,
      updatedAt: updatedAt,
      completedAt: updatedAt,
      isArchived: isArchived,
      archivedAt: _after(updatedAt),
      isDeleted: isDeleted,
      deletedAt: _after(updatedAt),
      sourceIdeaId: converted ? 'idea-${_random.nextInt(_ideaIdCount)}' : null,
      sourceIdeaCreatedAt: converted ? _instant(0, 10) : null,
    );
  }

  Subtask _subtask(String id) {
    final DateTime createdAt = _instant(0, 40);
    return aSubtask(
      id: id,
      named: _pick(_subtaskNames),
      status: _pick(TaskStatus.values),
      createdAt: createdAt,
      updatedAt: _after(createdAt),
    );
  }

  // ------------------------------------------------------------- Tombstones

  List<IdeaTombstone> _tombstones(Set<String> liveIdeaIds) => <IdeaTombstone>[
    for (int i = 0; i < _ideaIdCount; i++)
      if (!liveIdeaIds.contains('idea-$i') && _chance(0.25))
        aTombstone(
          id: 'idea-$i',
          deletedAt: _instant(0, 80),
          reason: _pick(TombstoneReason.values),
        ),
  ];

  // ----------------------------------------------------------------- pieces

  /// NAME-6. Keeps the first record per normalized name among the active ones,
  /// so the generated snapshot is a dataset the app could actually have held.
  List<T> _withUniqueActiveNames<T>(
    List<T> records, {
    required bool Function(T record) isActive,
    required String Function(T record) normalizedNameOf,
  }) {
    final Set<String> taken = <String>{};
    return <T>[
      for (final T record in records)
        if (!isActive(record) || taken.add(normalizedNameOf(record))) record,
    ];
  }

  /// A name from the pool, sometimes re-cased or padded, so that §2's
  /// normalization is exercised rather than assumed.
  String _name() {
    final String base = _pick(_names);
    return switch (_random.nextInt(4)) {
      0 => base.toUpperCase(),
      1 => base.toLowerCase(),
      2 => '  ${base.replaceAll(' ', '  ')} ',
      _ => base,
    };
  }

  List<Tag> _tagList() {
    final List<Tag> tags = <Tag>[
      for (final String value in _tags)
        if (_chance(0.4)) tag(_chance(0.5) ? value.toLowerCase() : value),
    ];
    // TAG-4 de-duplication is the entity's job; the merge must cope with what
    // a real Item holds, which is a de-duplicated list.
    return dedupeTags(tags);
  }

  /// Texts of differing length, so step 4's "longest wins" has something to do.
  String _text() => 'x' * _random.nextInt(12);

  DateTime _instant(int from, int to) =>
      at(from + _random.nextInt(to - from + 1));

  /// An instant at or after [earliest], keeping INV-5 (`createdAt <=
  /// updatedAt`) true by construction.
  DateTime _after(DateTime earliest) =>
      earliest.add(Duration(minutes: _random.nextInt(30)));

  T _pick<T>(List<T> values) => values[_random.nextInt(values.length)];

  bool _chance(double probability) => _random.nextDouble() < probability;
}

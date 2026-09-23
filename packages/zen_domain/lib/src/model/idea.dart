/// §3.2. Something the user might do, but might never do.
library;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../time/instant_precision.dart';
import 'enums.dart';
import 'item_name.dart';
import 'item_text.dart';
import 'tag.dart';

const ListEquality<Tag> _tagEquality = ListEquality<Tag>();

/// §3.2. An Idea.
///
/// Ideas have no status, no archive flag and no delete flag: every live Idea is
/// active (§2). Deleting one removes it and leaves a tombstone (DEL-3), and
/// converting one consumes it the same way (CONVERT-4).
///
/// Immutable: every change produces a new instance (§11.11).
@immutable
final class Idea {
  /// Constructs an Idea and asserts §3.7's per-entity invariants.
  Idea({
    required this.id,
    required this.name,
    required this.timeframe,
    required this.createdAt,
    required this.updatedAt,
    List<Tag> tags = const <Tag>[],
    this.context = ItemText.empty,
  }) : tags = List<Tag>.unmodifiable(tags) {
    assert(
      invariantFailures.isEmpty,
      'Idea $id violates §3.7: ${invariantFailures.join('; ')}',
    );
  }

  /// §3, §3.2. UUIDv7, assigned at creation and never changed.
  final String id;

  /// §3.2, §3.1. The idea's name, unique among active Ideas (NAME-6).
  final ItemName name;

  /// §3.2, §3.5. Tags in insertion order, de-duplicated case-insensitively.
  final List<Tag> tags;

  /// §3.2. Free multi-line plain text.
  final ItemText context;

  /// §3.2. The idea's urgency class. Discarded on conversion (CONVERT-1).
  final Timeframe timeframe;

  /// §3.2. Creation instant, UTC.
  final DateTime createdAt;

  /// §3.2. Instant of the last edit, UTC.
  final DateTime updatedAt;

  /// §2. Every live Idea is active, so this is always `true`.
  ///
  /// Present so that rules spanning both kinds — NAME-6's uniqueness scope and
  /// MERGE-5's name matching — can ask the same question of an Idea and a Task
  /// without a special case.
  bool get isActive => true;

  /// §3.7. The invariants this Idea breaks, empty when it is well-formed.
  ///
  /// Only INV-5 and INV-9 apply per entity: an Idea has no status or lifecycle
  /// flags.
  /// INV-6 (uniqueness) and INV-7 (tombstones) span the dataset and live in
  /// `invariants.dart`.
  List<String> get invariantFailures => <String>[
    if (createdAt.isAfter(updatedAt))
      'INV-5: createdAt $createdAt is after updatedAt $updatedAt',
    ...timestampPrecisionFailures(<String, DateTime?>{
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    }),
  ];

  /// Returns a copy with the given fields replaced.
  Idea copyWith({
    ItemName? name,
    List<Tag>? tags,
    ItemText? context,
    Timeframe? timeframe,
    DateTime? updatedAt,
  }) => Idea(
    id: id,
    name: name ?? this.name,
    tags: tags ?? this.tags,
    context: context ?? this.context,
    timeframe: timeframe ?? this.timeframe,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Idea &&
      other.id == id &&
      other.name == name &&
      _tagEquality.equals(other.tags, tags) &&
      other.context == context &&
      other.timeframe == timeframe &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    _tagEquality.hash(tags),
    context,
    timeframe,
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'Idea($id, "$name", ${timeframe.name})';
}

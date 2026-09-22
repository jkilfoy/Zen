/// §2, DEL-3, §9.3 step 1. Proof that an Idea once existed and was removed.
library;

import 'package:meta/meta.dart';

import 'enums.dart';

/// §2, DEL-3. A tombstone for a removed Idea.
///
/// Tombstones store **no name**. Matching during a merge is by [id] only
/// (§9.3 step 1, Q3), so a name that was deleted may be created again as a new
/// Idea with a new id and the tombstone will not affect it (AC-18).
@immutable
final class IdeaTombstone {
  /// Records that the Idea with [id] was removed at [deletedAt] for [reason].
  const IdeaTombstone({
    required this.id,
    required this.deletedAt,
    required this.reason,
  });

  /// The id of the Idea that was removed. INV-7 requires it to be absent from
  /// the Ideas table.
  final String id;

  /// When the removal happened, UTC.
  final DateTime deletedAt;

  /// Whether the Idea was deleted outright or consumed by a conversion.
  final TombstoneReason reason;

  @override
  bool operator ==(Object other) =>
      other is IdeaTombstone &&
      other.id == id &&
      other.deletedAt == deletedAt &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(id, deletedAt, reason);

  @override
  String toString() => 'IdeaTombstone($id, ${reason.name}, $deletedAt)';
}

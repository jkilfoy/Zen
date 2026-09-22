/// HIST-2. The append-only event log each replica keeps.
library;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'enums.dart';

const MapEquality<String, Object?> _payloadEquality =
    MapEquality<String, Object?>();

/// HIST-2. The kinds of entry in the event log.
///
/// The MVP does not show this log in the UI. It exists for audit and for
/// future, better merge strategies (§9.1).
enum ItemEventType {
  /// An Item was created (§4.1).
  created,

  /// An Item's name changed.
  renamed,

  /// An Item's tags changed.
  tagsChanged,

  /// An Idea's context or a Task's description changed.
  contextChanged,

  /// An Idea's timeframe changed.
  timeframeChanged,

  /// A Task's status changed (§4.2).
  statusChanged,

  /// A subtask was added (SUB-8 permitting).
  subtaskAdded,

  /// A subtask was renamed or its status changed.
  subtaskChanged,

  /// A subtask was hard-deleted (SUB-7).
  subtaskRemoved,

  /// A Task's subtasks were reordered.
  subtasksReordered,

  /// A Task was archived at an End-of-Day boundary (EOD-2).
  archived,

  /// An archived Task was returned to the To Do list (ARCH-3).
  unarchived,

  /// A Task was soft-deleted (DEL-1) or an Idea removed (DEL-3).
  deleted,

  /// A soft-deleted Task was restored (DEL-2).
  restored,

  /// An Idea was consumed by a conversion into a Task (CONVERT-4).
  convertedToTask,

  /// A conflict component was resolved by a merge (§9.3 step 7).
  merged,
}

/// HIST-2. One entry in a replica's append-only event log.
///
/// The log is local-only and never travels in a snapshot (§11.5.1, §11.6.1).
@immutable
final class ItemEvent {
  /// Records that [type] happened to [itemId] at [timestamp].
  ItemEvent({
    required this.eventId,
    required this.itemId,
    required this.itemKind,
    required this.type,
    required this.timestamp,
    Map<String, Object?> payload = const <String, Object?>{},
  }) : payload = Map<String, Object?>.unmodifiable(payload);

  /// UUIDv7 identifying this entry.
  final String eventId;

  /// The Idea or Task the entry is about.
  final String itemId;

  /// Which kind of Item [itemId] refers to.
  final ItemKind itemKind;

  /// What happened.
  final ItemEventType type;

  /// When it happened, UTC.
  final DateTime timestamp;

  /// Type-specific detail. Deliberately untyped: HIST-2 specifies a payload
  /// without specifying its shape, and the MVP never reads it back.
  final Map<String, Object?> payload;

  @override
  bool operator ==(Object other) =>
      other is ItemEvent &&
      other.eventId == eventId &&
      other.itemId == itemId &&
      other.itemKind == itemKind &&
      other.type == type &&
      other.timestamp == timestamp &&
      _payloadEquality.equals(other.payload, payload);

  @override
  int get hashCode => Object.hash(
    eventId,
    itemId,
    itemKind,
    type,
    timestamp,
    _payloadEquality.hash(payload),
  );

  @override
  String toString() => 'ItemEvent(${type.name}, ${itemKind.name} $itemId)';
}

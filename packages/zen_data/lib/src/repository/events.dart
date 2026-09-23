/// HIST-2. Turning a change into the event-log entries that record it.
library;

import 'package:zen_domain/zen_domain.dart';

/// HIST-2. Appends the entries that describe a change, inside the same
/// transaction as the change itself.
///
/// §11.4.6 declares `EventLog` beside the other repositories without saying who
/// writes to it. The repositories do, from inside their own transactions,
/// because an audit trail written outside the transaction loses entries to
/// exactly the crashes it exists to explain — and STORE-3 already requires
/// these operations to be atomic (D-M3-6).
///
/// What it emits is derived by comparing the record before and after, so a save
/// that changed a name and a tag produces both `renamed` and `tagsChanged`
/// rather than one vague entry. A save that changed nothing produces nothing.
final class EventRecorder {
  /// Writes to [log], minting entry ids with [ids].
  const EventRecorder(this._log, this._ids);

  final EventLog _log;
  final IdGenerator _ids;

  /// HIST-2. Appends one entry.
  Future<void> record({
    required String itemId,
    required ItemKind kind,
    required ItemEventType type,
    required DateTime at,
    Map<String, Object?> payload = const <String, Object?>{},
  }) => _log.append(
    ItemEvent(
      eventId: _ids.newId(),
      itemId: itemId,
      itemKind: kind,
      type: type,
      timestamp: at,
      payload: payload,
    ),
  );

  /// HIST-2. Appends what changed between [before] and [after] for an Idea.
  Future<void> recordIdeaEdit({
    required Idea before,
    required Idea after,
    required DateTime at,
  }) async {
    if (before.name != after.name) {
      await record(
        itemId: after.id,
        kind: ItemKind.idea,
        type: ItemEventType.renamed,
        at: at,
        payload: <String, Object?>{
          'from': before.name.value,
          'to': after.name.value,
        },
      );
    }
    if (!_sameTags(before.tags, after.tags)) {
      await record(
        itemId: after.id,
        kind: ItemKind.idea,
        type: ItemEventType.tagsChanged,
        at: at,
        payload: <String, Object?>{'to': _tagValues(after.tags)},
      );
    }
    if (before.context != after.context) {
      await record(
        itemId: after.id,
        kind: ItemKind.idea,
        type: ItemEventType.contextChanged,
        at: at,
      );
    }
    if (before.timeframe != after.timeframe) {
      await record(
        itemId: after.id,
        kind: ItemKind.idea,
        type: ItemEventType.timeframeChanged,
        at: at,
        payload: <String, Object?>{
          'from': before.timeframe.name,
          'to': after.timeframe.name,
        },
      );
    }
  }

  /// HIST-2. Appends what changed between [before] and [after] for a Task.
  Future<void> recordTaskEdit({
    required Task before,
    required Task after,
    required DateTime at,
  }) async {
    if (before.name != after.name) {
      await record(
        itemId: after.id,
        kind: ItemKind.task,
        type: ItemEventType.renamed,
        at: at,
        payload: <String, Object?>{
          'from': before.name.value,
          'to': after.name.value,
        },
      );
    }
    if (!_sameTags(before.tags, after.tags)) {
      await record(
        itemId: after.id,
        kind: ItemKind.task,
        type: ItemEventType.tagsChanged,
        at: at,
        payload: <String, Object?>{'to': _tagValues(after.tags)},
      );
    }
    if (before.description != after.description) {
      await record(
        itemId: after.id,
        kind: ItemKind.task,
        type: ItemEventType.contextChanged,
        at: at,
      );
    }
    if (before.status != after.status) {
      await record(
        itemId: after.id,
        kind: ItemKind.task,
        type: ItemEventType.statusChanged,
        at: at,
        payload: <String, Object?>{
          'from': before.status.name,
          'to': after.status.name,
        },
      );
    }
    await _recordSubtaskEdits(before: before, after: after, at: at);
  }

  Future<void> _recordSubtaskEdits({
    required Task before,
    required Task after,
    required DateTime at,
  }) async {
    final Map<String, Subtask> was = <String, Subtask>{
      for (final Subtask s in before.subtasks) s.id: s,
    };
    final Map<String, Subtask> now = <String, Subtask>{
      for (final Subtask s in after.subtasks) s.id: s,
    };

    for (final Subtask subtask in after.subtasks) {
      final Subtask? old = was[subtask.id];
      if (old == null) {
        await record(
          itemId: after.id,
          kind: ItemKind.task,
          type: ItemEventType.subtaskAdded,
          at: at,
          payload: <String, Object?>{'subtaskId': subtask.id},
        );
      } else if (old.name != subtask.name || old.status != subtask.status) {
        await record(
          itemId: after.id,
          kind: ItemKind.task,
          type: ItemEventType.subtaskChanged,
          at: at,
          payload: <String, Object?>{
            'subtaskId': subtask.id,
            'status': subtask.status.name,
          },
        );
      }
    }
    for (final Subtask subtask in before.subtasks) {
      if (!now.containsKey(subtask.id)) {
        await record(
          itemId: after.id,
          kind: ItemKind.task,
          type: ItemEventType.subtaskRemoved,
          at: at,
          payload: <String, Object?>{'subtaskId': subtask.id},
        );
      }
    }

    // D-M1-7: a reorder changes nothing about an individual subtask, so it is
    // only visible as a change of sequence. Reported only when the membership
    // is the same, since an add or a remove moves later subtasks by itself.
    final List<String> wasOrder = before.subtasks
        .map((Subtask s) => s.id)
        .toList(growable: false);
    final List<String> nowOrder = after.subtasks
        .map((Subtask s) => s.id)
        .toList(growable: false);
    if (was.keys.toSet().length == now.keys.toSet().length &&
        was.keys.toSet().containsAll(now.keys) &&
        !_sameOrder(wasOrder, nowOrder)) {
      await record(
        itemId: after.id,
        kind: ItemKind.task,
        type: ItemEventType.subtasksReordered,
        at: at,
        payload: <String, Object?>{'order': nowOrder},
      );
    }
  }

  static List<String> _tagValues(List<Tag> tags) =>
      tags.map((Tag t) => t.value).toList(growable: false);

  /// TAG-4 compares tags case-insensitively, but §3.2 and §3.3 make the order
  /// and the casing the user typed part of the record, so both count as a
  /// change here.
  static bool _sameTags(List<Tag> a, List<Tag> b) =>
      _sameOrder(_tagValues(a), _tagValues(b));

  static bool _sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}

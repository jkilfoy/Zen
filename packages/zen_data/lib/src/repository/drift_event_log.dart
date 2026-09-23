/// HIST-2, §11.5.1. The append-only event log.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:zen_domain/zen_domain.dart';

import '../database.dart';
import '../mapping/instants.dart';

/// §11.5.1. The log's cap, in one place so it can be raised in one place.
///
/// "On each app start, delete entries older than 365 days, keeping at least the
/// most recent 5,000 regardless of age." The floor is global, not per item.
/// Raising these is the change to make if the log ever becomes useful for a
/// better merge strategy (§9.1).
class EventLogCap {
  const EventLogCap._();

  /// How long an entry is kept regardless of how many there are.
  static const Duration retention = Duration(days: 365);

  /// How many of the most recent entries are kept regardless of age.
  static const int floor = 5000;
}

/// HIST-2, §11.5.1. The Drift-backed [EventLog].
///
/// Local-only: these rows never travel in a snapshot (§11.6.1). The other
/// repositories hold one of these and append inside their own transactions, so
/// that an entry and the change it records commit together — a log written
/// outside the transaction would lose entries to exactly the crashes it exists
/// to explain (D-M3-6).
final class DriftEventLog implements EventLog {
  /// Creates a log over [db].
  DriftEventLog(this._db);

  final AppDatabase _db;

  @override
  Future<void> append(ItemEvent event) async {
    await _db
        .into(_db.events)
        .insert(
          EventsCompanion(
            eventId: Value<String>(event.eventId),
            itemId: Value<String>(event.itemId),
            itemKind: Value<String>(event.itemKind.name),
            type: Value<String>(event.type.name),
            timestamp: Value<String>(encodeInstant(event.timestamp)),
            payload: Value<String>(jsonEncode(event.payload)),
          ),
        );
  }

  @override
  Future<List<ItemEvent>> forItem(String itemId) async {
    final List<EventRow> rows =
        await (_db.select(_db.events)
              ..where((Events e) => e.itemId.equals(itemId))
              // INV-9 makes every timestamp the same width, so ordering the
              // stored text is ordering the instants (§3).
              ..orderBy(<OrderClauseGenerator<Events>>[
                (Events e) => OrderingTerm.asc(e.timestamp),
                (Events e) => OrderingTerm.asc(e.eventId),
              ]))
            .get();
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<int> prune(DateTime nowUtc) async {
    final String cutoff = encodeInstant(nowUtc.subtract(EventLogCap.retention));

    // The floor is the timestamp of the `floor`-th most recent entry. Anything
    // at or after it is kept whatever its age; anything before it is kept only
    // while it is inside the retention window.
    final List<EventRow> floorRow =
        await (_db.select(_db.events)
              ..orderBy(<OrderClauseGenerator<Events>>[
                (Events e) => OrderingTerm.desc(e.timestamp),
              ])
              ..limit(1, offset: EventLogCap.floor - 1))
            .get();
    if (floorRow.isEmpty) {
      // Fewer entries than the floor: nothing may be deleted, whatever its age.
      return 0;
    }
    final String floor = floorRow.single.timestamp;

    return (_db.delete(_db.events)..where(
          (Events e) =>
              e.timestamp.isSmallerThanValue(cutoff) &
              e.timestamp.isSmallerThanValue(floor),
        ))
        .go();
  }

  ItemEvent _fromRow(EventRow row) => ItemEvent(
    eventId: row.eventId,
    itemId: row.itemId,
    itemKind: ItemKind.values.byName(row.itemKind),
    type: ItemEventType.values.byName(row.type),
    timestamp: decodeInstant(row.timestamp),
    payload: (jsonDecode(row.payload) as Map<String, Object?>),
  );
}

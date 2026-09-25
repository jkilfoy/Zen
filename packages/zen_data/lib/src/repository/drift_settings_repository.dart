/// §3.6, §11.4.6. The Drift-backed [SettingsRepository].
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:zen_domain/zen_domain.dart';

import '../mapping/instants.dart';

// Drift names a table's class after the table, so `settings` generates a
// `Settings` that would shadow §3.6's. Only the row and companion types are
// needed here; the table itself is reached through `_db.settings`.
import '../database.dart' hide Settings;

/// §3.6. The key-value encoding of [Settings].
///
/// A key-value table rather than a one-row table with a column per setting, so
/// §11.8's sync settings can join in M6 without a migration (§11.5.1).
///
/// Every value is a string, and **every read falls back to the factory default
/// when the stored value is malformed** (§11.5.5): a settings row the user
/// cannot see is not worth crashing the app over, and §3.6 gives a default for
/// every key.
class SettingsKeys {
  const SettingsKeys._();

  /// §3.6. `defaultIdeaTimeframe`, stored as a [Timeframe] name.
  static const String defaultIdeaTimeframe = 'defaultIdeaTimeframe';

  /// §3.6, IDEAS-2. `expandedIdeaGroups`, stored as comma-separated
  /// [Timeframe] names. The empty string is the empty set.
  static const String expandedIdeaGroups = 'expandedIdeaGroups';

  /// §3.6, TODO-3. `strikethroughDone`, stored as `0` or `1`.
  static const String strikethroughDone = 'strikethroughDone';

  /// §3.6, EOD-1. `endOfDay`, stored as `HH:MM`.
  static const String endOfDay = 'endOfDay';

  /// §3.6, DECOR-1. `theme`, stored as a [ThemeMode] name.
  static const String theme = 'theme';

  /// §3.6, DECOR-1. `decor`, stored as a decor pack id.
  static const String decor = 'decor';

  /// §3.6, DEL-4. `confirmDestructive`, stored as `0` or `1`.
  static const String confirmDestructive = 'confirmDestructive';

  /// §11.8. `syncFolderEnabled`, stored as `0` or `1`.
  static const String syncFolderEnabled = 'syncFolderEnabled';

  /// §11.8. `syncFolderLocation`: a directory path (Windows) or a SAF tree URI
  /// (Android). The empty string is `null` — neither a path nor a URI can be
  /// empty, so no real value is lost to the encoding.
  static const String syncFolderLocation = 'syncFolderLocation';

  /// §11.8. `syncLanEnabled`, stored as `0` or `1`.
  static const String syncLanEnabled = 'syncLanEnabled';

  /// §11.8. `syncLanPort`, stored as a decimal integer.
  static const String syncLanPort = 'syncLanPort';

  /// §11.8, §11.6.4. `syncLanPeers`, stored as a JSON array.
  ///
  /// JSON rather than a delimited string because a device name is free text and
  /// would have to be escaped anyway. Written empty by M6 and filled by M7's
  /// pairing flow.
  static const String syncLanPeers = 'syncLanPeers';

  /// §11.8. `syncOnForeground`, stored as `0` or `1`.
  static const String syncOnForeground = 'syncOnForeground';

  /// §11.8. `syncIntervalMinutes`, stored as a decimal integer. `0` disables.
  static const String syncIntervalMinutes = 'syncIntervalMinutes';

  /// §11.8, §11.6.5 step 8. `lastSyncAt`, stored as an ISO-8601 instant. The
  /// empty string is `null` — no sync has completed yet.
  static const String lastSyncAt = 'lastSyncAt';
}

/// §11.4.6. Per-replica settings (§3.6).
///
/// MERGE-3: these are never merged and never travel in a snapshot, which is why
/// nothing in `zen_sync` will read this table.
final class DriftSettingsRepository implements SettingsRepository {
  /// Creates a repository over [db].
  DriftSettingsRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<Settings> watch() =>
      _db.select(_db.settings).watch().map(_decode).distinct();

  @override
  Future<Settings> read() async =>
      _decode(await _db.select(_db.settings).get());

  @override
  Future<void> write(Settings settings) async {
    // SET-2: "Changes apply immediately and persist." One transaction so a
    // partially written settings record is never observable.
    await _db.transaction(() async {
      final Map<String, String> values = _encode(settings);
      await _db.batch(
        (Batch batch) =>
            batch.insertAllOnConflictUpdate(_db.settings, <SettingsCompanion>[
              for (final MapEntry<String, String> entry in values.entries)
                SettingsCompanion(
                  settingKey: Value<String>(entry.key),
                  settingValue: Value<String>(entry.value),
                ),
            ]),
      );
    });
  }

  Map<String, String> _encode(Settings settings) => <String, String>{
    SettingsKeys.defaultIdeaTimeframe: settings.defaultIdeaTimeframe.name,
    SettingsKeys.expandedIdeaGroups:
        (settings.expandedIdeaGroups.toList()
              ..sort((Timeframe a, Timeframe b) => a.index.compareTo(b.index)))
            .map((Timeframe t) => t.name)
            .join(','),
    SettingsKeys.strikethroughDone: settings.strikethroughDone ? '1' : '0',
    SettingsKeys.endOfDay: settings.endOfDay.format(),
    SettingsKeys.theme: settings.theme.name,
    SettingsKeys.decor: settings.decor,
    SettingsKeys.confirmDestructive: settings.confirmDestructive ? '1' : '0',
    SettingsKeys.syncFolderEnabled: settings.syncFolderEnabled ? '1' : '0',
    SettingsKeys.syncFolderLocation: settings.syncFolderLocation ?? '',
    SettingsKeys.syncLanEnabled: settings.syncLanEnabled ? '1' : '0',
    SettingsKeys.syncLanPort: settings.syncLanPort.toString(),
    SettingsKeys.syncLanPeers: jsonEncode(<Map<String, Object?>>[
      for (final LanPeer peer in settings.syncLanPeers)
        <String, Object?>{
          'replicaId': peer.replicaId,
          'deviceName': peer.deviceName,
          'host': peer.host,
          'port': peer.port,
          'psk': peer.psk,
        },
    ]),
    SettingsKeys.syncOnForeground: settings.syncOnForeground ? '1' : '0',
    SettingsKeys.syncIntervalMinutes: settings.syncIntervalMinutes.toString(),
    SettingsKeys.lastSyncAt: encodeInstantOrNull(settings.lastSyncAt) ?? '',
  };

  Settings _decode(List<SettingRow> rows) {
    final Map<String, String> stored = <String, String>{
      for (final SettingRow row in rows) row.settingKey: row.settingValue,
    };
    final Settings defaults = Settings();

    return Settings(
      defaultIdeaTimeframe:
          _enum(Timeframe.values, stored[SettingsKeys.defaultIdeaTimeframe]) ??
          defaults.defaultIdeaTimeframe,
      expandedIdeaGroups:
          _timeframeSet(stored[SettingsKeys.expandedIdeaGroups]) ??
          defaults.expandedIdeaGroups,
      strikethroughDone:
          _bool(stored[SettingsKeys.strikethroughDone]) ??
          defaults.strikethroughDone,
      endOfDay: _localTime(stored[SettingsKeys.endOfDay]) ?? defaults.endOfDay,
      theme:
          _enum(ThemeMode.values, stored[SettingsKeys.theme]) ?? defaults.theme,
      decor: _nonEmpty(stored[SettingsKeys.decor]) ?? defaults.decor,
      confirmDestructive:
          _bool(stored[SettingsKeys.confirmDestructive]) ??
          defaults.confirmDestructive,
      syncFolderEnabled:
          _bool(stored[SettingsKeys.syncFolderEnabled]) ??
          defaults.syncFolderEnabled,
      syncFolderLocation: _nonEmpty(stored[SettingsKeys.syncFolderLocation]),
      syncLanEnabled:
          _bool(stored[SettingsKeys.syncLanEnabled]) ?? defaults.syncLanEnabled,
      syncLanPort:
          _port(stored[SettingsKeys.syncLanPort]) ?? defaults.syncLanPort,
      syncLanPeers:
          _lanPeers(stored[SettingsKeys.syncLanPeers]) ?? defaults.syncLanPeers,
      syncOnForeground:
          _bool(stored[SettingsKeys.syncOnForeground]) ??
          defaults.syncOnForeground,
      syncIntervalMinutes:
          _interval(stored[SettingsKeys.syncIntervalMinutes]) ??
          defaults.syncIntervalMinutes,
      lastSyncAt: _instant(stored[SettingsKeys.lastSyncAt]),
    );
  }

  static T? _enum<T extends Enum>(List<T> values, String? stored) {
    if (stored == null) {
      return null;
    }
    for (final T value in values) {
      if (value.name == stored) {
        return value;
      }
    }
    return null;
  }

  static bool? _bool(String? stored) => switch (stored) {
    '1' => true,
    '0' => false,
    _ => null,
  };

  static String? _nonEmpty(String? stored) =>
      stored == null || stored.isEmpty ? null : stored;

  static LocalTime? _localTime(String? stored) =>
      stored == null ? null : LocalTime.tryParse(stored);

  /// §11.8, §11.6.5 step 8. Decodes `lastSyncAt`.
  ///
  /// The empty string is a real value meaning "never synced", so it decodes to
  /// null rather than to the factory default — which is also null, but for a
  /// different reason.
  ///
  /// `tryParse` rather than `decodeInstant`, which throws: this table's rule is
  /// that "every read falls back to the factory default when the stored value
  /// is malformed" (§11.5.5), and a settings row the user cannot even see is
  /// not worth taking the app down over. Truncated on the way out for the same
  /// reason `decodeInstant` does it — a row written before the INV-9 checks
  /// existed must not hand a finer instant to the domain (D-M1-16).
  static DateTime? _instant(String? stored) {
    if (stored == null || stored.isEmpty) {
      return null;
    }
    final DateTime? parsed = DateTime.tryParse(stored);
    return parsed == null ? null : truncateToMilliseconds(parsed);
  }

  /// §11.8. Decodes `syncLanPort`, refusing anything outside the TCP range.
  ///
  /// A port of 0 or 70000 is not a preference the app can honour, and §11.5.5's
  /// rule for this table is that a malformed value falls back to the factory
  /// default rather than propagating.
  static int? _port(String? stored) {
    final int? value = stored == null ? null : int.tryParse(stored);
    return value != null && value >= 1 && value <= 65535 ? value : null;
  }

  /// §11.8. Decodes `syncIntervalMinutes`. `0` disables the timer; a negative
  /// value is malformed and falls back to the default.
  static int? _interval(String? stored) {
    final int? value = stored == null ? null : int.tryParse(stored);
    return value != null && value >= 0 ? value : null;
  }

  /// §11.8, §11.6.4. Decodes `syncLanPeers`.
  ///
  /// The whole list falls back to the factory default if the JSON is
  /// unreadable, and an individual entry missing a field is dropped. A
  /// half-decoded peer would be worse than a missing one: M7 dials it, and a
  /// peer with no host is a connection attempt that can only fail.
  static List<LanPeer>? _lanPeers(String? stored) {
    if (stored == null || stored.isEmpty) {
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(stored);
    } on FormatException {
      return null;
    }
    if (decoded is! List<Object?>) {
      return null;
    }
    return <LanPeer>[
      for (final Object? entry in decoded)
        if (entry is Map<String, Object?> &&
            entry['replicaId'] is String &&
            entry['deviceName'] is String &&
            entry['host'] is String &&
            entry['port'] is int &&
            entry['psk'] is String)
          LanPeer(
            replicaId: entry['replicaId']! as String,
            deviceName: entry['deviceName']! as String,
            host: entry['host']! as String,
            port: entry['port']! as int,
            psk: entry['psk']! as String,
          ),
    ];
  }

  /// IDEAS-2. Decodes the expanded-group set.
  ///
  /// An unrecognised name is dropped rather than failing the whole set: the
  /// setting is a display preference, and losing one group's expansion state is
  /// a smaller harm than resetting all four (§11.5.5).
  static Set<Timeframe>? _timeframeSet(String? stored) {
    if (stored == null) {
      return null;
    }
    if (stored.isEmpty) {
      // A legitimate value: every group collapsed.
      return const <Timeframe>{};
    }
    return <Timeframe>{
      for (final String part in stored.split(','))
        if (_enum(Timeframe.values, part) case final Timeframe t) t,
    };
  }
}

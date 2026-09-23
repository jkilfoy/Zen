/// §3.6, §11.4.6. The Drift-backed [SettingsRepository].
library;

import 'package:drift/drift.dart';
import 'package:zen_domain/zen_domain.dart';

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

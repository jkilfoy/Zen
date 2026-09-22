/// §3.6. Per-replica settings.
library;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../time/local_time.dart';
import 'enums.dart';

const SetEquality<Timeframe> _timeframeSetEquality = SetEquality<Timeframe>();

/// §3.6, Q16. The light/dark axis, independent of [Settings.decor] (DECOR-1).
enum ThemeMode {
  /// Follow the platform's light/dark setting.
  system,

  /// Always light.
  light,

  /// Always dark.
  dark,
}

/// §3.6. The settings of one replica.
///
/// "Settings are stored **per replica** and are never merged" (§3.6, MERGE-3,
/// Q15), which is why they are excluded from snapshots (§11.6.1).
///
/// §11.8's sync settings extend this table. They are added in M6, when the
/// transports that read them exist.
@immutable
final class Settings {
  /// Constructs a settings record, defaulting every field to its §3.6 factory
  /// default.
  Settings({
    this.defaultIdeaTimeframe = Timeframe.now,
    Set<Timeframe> expandedIdeaGroups = const <Timeframe>{
      Timeframe.now,
      Timeframe.soon,
      Timeframe.later,
    },
    this.strikethroughDone = true,
    this.endOfDay = LocalTime.endOfDayDefault,
    this.theme = ThemeMode.system,
    this.decor = basicDecorId,
    this.confirmDestructive = true,
  }) : expandedIdeaGroups = Set<Timeframe>.unmodifiable(expandedIdeaGroups);

  /// DECOR-3. The id of the one decor pack the MVP ships.
  static const String basicDecorId = 'Basic';

  /// §3.6. Timeframe preselected on the Add Idea screen.
  final Timeframe defaultIdeaTimeframe;

  /// §3.6, IDEAS-2, Q2. Which timeframe groups are expanded when the Ideas tab
  /// opens. The same setting as "which groups are shown by default".
  final Set<Timeframe> expandedIdeaGroups;

  /// §3.6, TODO-3. Whether Done Tasks and Subtasks show their name struck
  /// through.
  final bool strikethroughDone;

  /// §3.6, EOD-1. The logical day boundary.
  final LocalTime endOfDay;

  /// §3.6, DECOR-1. The light/dark axis.
  final ThemeMode theme;

  /// §3.6, DECOR-1. The visual skin axis, independent of [theme].
  final String decor;

  /// §3.6, DEL-4. Whether deleting asks for confirmation.
  final bool confirmDestructive;

  /// Returns a copy with the given fields replaced.
  Settings copyWith({
    Timeframe? defaultIdeaTimeframe,
    Set<Timeframe>? expandedIdeaGroups,
    bool? strikethroughDone,
    LocalTime? endOfDay,
    ThemeMode? theme,
    String? decor,
    bool? confirmDestructive,
  }) => Settings(
    defaultIdeaTimeframe: defaultIdeaTimeframe ?? this.defaultIdeaTimeframe,
    expandedIdeaGroups: expandedIdeaGroups ?? this.expandedIdeaGroups,
    strikethroughDone: strikethroughDone ?? this.strikethroughDone,
    endOfDay: endOfDay ?? this.endOfDay,
    theme: theme ?? this.theme,
    decor: decor ?? this.decor,
    confirmDestructive: confirmDestructive ?? this.confirmDestructive,
  );

  @override
  bool operator ==(Object other) =>
      other is Settings &&
      other.defaultIdeaTimeframe == defaultIdeaTimeframe &&
      _timeframeSetEquality.equals(
        other.expandedIdeaGroups,
        expandedIdeaGroups,
      ) &&
      other.strikethroughDone == strikethroughDone &&
      other.endOfDay == endOfDay &&
      other.theme == theme &&
      other.decor == decor &&
      other.confirmDestructive == confirmDestructive;

  @override
  int get hashCode => Object.hash(
    defaultIdeaTimeframe,
    _timeframeSetEquality.hash(expandedIdeaGroups),
    strikethroughDone,
    endOfDay,
    theme,
    decor,
    confirmDestructive,
  );

  @override
  String toString() => 'Settings(endOfDay: $endOfDay, theme: ${theme.name})';
}

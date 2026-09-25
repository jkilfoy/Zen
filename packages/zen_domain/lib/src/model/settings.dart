/// §3.6. Per-replica settings.
library;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../time/local_time.dart';
import 'enums.dart';
import 'lan_peer.dart';

const SetEquality<Timeframe> _timeframeSetEquality = SetEquality<Timeframe>();
const ListEquality<LanPeer> _lanPeerListEquality = ListEquality<LanPeer>();

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
/// §11.8's sync settings extend this record. They are per replica too, which is
/// what makes it safe for the orchestrator to write [lastSyncAt] on every pass:
/// it describes this device's own history with its peers, not shared data.
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
    this.syncFolderEnabled = false,
    this.syncFolderLocation,
    this.syncLanEnabled = false,
    this.syncLanPort = defaultLanPort,
    List<LanPeer> syncLanPeers = const <LanPeer>[],
    this.syncOnForeground = true,
    this.syncIntervalMinutes = defaultSyncIntervalMinutes,
    this.lastSyncAt,
  }) : expandedIdeaGroups = Set<Timeframe>.unmodifiable(expandedIdeaGroups),
       syncLanPeers = List<LanPeer>.unmodifiable(syncLanPeers);

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

  /// §11.6.4, §11.8. The desktop's default listen port.
  static const int defaultLanPort = 51789;

  /// §11.8. The default periodic-sync interval, in minutes.
  static const int defaultSyncIntervalMinutes = 15;

  /// §11.8. Whether the file transport (§11.6.3) is switched on.
  final bool syncFolderEnabled;

  /// §11.8. The sync folder: a directory path on Windows, a SAF tree URI on
  /// Android (§11.6.3). Null until the user picks one.
  final String? syncFolderLocation;

  /// §11.8. Whether the LAN transport (§11.6.4, M7) is switched on.
  final bool syncLanEnabled;

  /// §11.8, §11.6.4. The desktop's listen port.
  final int syncLanPort;

  /// §11.8, §11.6.4. Paired devices. Empty until M7's pairing flow exists.
  final List<LanPeer> syncLanPeers;

  /// §11.8, §11.6.5. Whether a sync runs when the app comes to the foreground.
  final bool syncOnForeground;

  /// §11.8, §11.6.5. Minutes between periodic syncs while the app is open.
  /// `0` disables the timer.
  final int syncIntervalMinutes;

  /// §11.8, §11.6.5 step 8. When the last pass finished. Read-only in the UI —
  /// the orchestrator is the only writer.
  final DateTime? lastSyncAt;

  /// §11.8. Whether the periodic timer runs at all.
  bool get syncTimerEnabled => syncIntervalMinutes > 0;

  /// Returns a copy with the given fields replaced.
  Settings copyWith({
    Timeframe? defaultIdeaTimeframe,
    Set<Timeframe>? expandedIdeaGroups,
    bool? strikethroughDone,
    LocalTime? endOfDay,
    ThemeMode? theme,
    String? decor,
    bool? confirmDestructive,
    bool? syncFolderEnabled,
    String? syncFolderLocation,
    bool? syncLanEnabled,
    int? syncLanPort,
    List<LanPeer>? syncLanPeers,
    bool? syncOnForeground,
    int? syncIntervalMinutes,
    DateTime? lastSyncAt,
  }) => Settings(
    defaultIdeaTimeframe: defaultIdeaTimeframe ?? this.defaultIdeaTimeframe,
    expandedIdeaGroups: expandedIdeaGroups ?? this.expandedIdeaGroups,
    strikethroughDone: strikethroughDone ?? this.strikethroughDone,
    endOfDay: endOfDay ?? this.endOfDay,
    theme: theme ?? this.theme,
    decor: decor ?? this.decor,
    confirmDestructive: confirmDestructive ?? this.confirmDestructive,
    syncFolderEnabled: syncFolderEnabled ?? this.syncFolderEnabled,
    syncFolderLocation: syncFolderLocation ?? this.syncFolderLocation,
    syncLanEnabled: syncLanEnabled ?? this.syncLanEnabled,
    syncLanPort: syncLanPort ?? this.syncLanPort,
    syncLanPeers: syncLanPeers ?? this.syncLanPeers,
    syncOnForeground: syncOnForeground ?? this.syncOnForeground,
    syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
  );

  /// §11.8. Returns a copy with no sync folder, which [copyWith] cannot express.
  ///
  /// `copyWith`'s `??` idiom cannot set a nullable field back to null, and
  /// `syncFolderLocation` is the one setting the user can genuinely clear —
  /// they picked a folder and want it forgotten. A dedicated method rather than
  /// a sentinel value or a `clearX` flag: one caller, one name, nothing to
  /// misread. [lastSyncAt] needs no twin, because it only ever moves forward.
  Settings withoutSyncFolder() => Settings(
    defaultIdeaTimeframe: defaultIdeaTimeframe,
    expandedIdeaGroups: expandedIdeaGroups,
    strikethroughDone: strikethroughDone,
    endOfDay: endOfDay,
    theme: theme,
    decor: decor,
    confirmDestructive: confirmDestructive,
    syncFolderEnabled: syncFolderEnabled,
    syncLanEnabled: syncLanEnabled,
    syncLanPort: syncLanPort,
    syncLanPeers: syncLanPeers,
    syncOnForeground: syncOnForeground,
    syncIntervalMinutes: syncIntervalMinutes,
    lastSyncAt: lastSyncAt,
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
      other.confirmDestructive == confirmDestructive &&
      other.syncFolderEnabled == syncFolderEnabled &&
      other.syncFolderLocation == syncFolderLocation &&
      other.syncLanEnabled == syncLanEnabled &&
      other.syncLanPort == syncLanPort &&
      _lanPeerListEquality.equals(other.syncLanPeers, syncLanPeers) &&
      other.syncOnForeground == syncOnForeground &&
      other.syncIntervalMinutes == syncIntervalMinutes &&
      other.lastSyncAt == lastSyncAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    defaultIdeaTimeframe,
    _timeframeSetEquality.hash(expandedIdeaGroups),
    strikethroughDone,
    endOfDay,
    theme,
    decor,
    confirmDestructive,
    syncFolderEnabled,
    syncFolderLocation,
    syncLanEnabled,
    syncLanPort,
    _lanPeerListEquality.hash(syncLanPeers),
    syncOnForeground,
    syncIntervalMinutes,
    lastSyncAt,
  ]);

  @override
  String toString() => 'Settings(endOfDay: $endOfDay, theme: ${theme.name})';
}

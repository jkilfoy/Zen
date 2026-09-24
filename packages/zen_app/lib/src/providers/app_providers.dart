/// §11.7. The composition root: the providers that construct dependencies and
/// expose repository streams.
///
/// "Providers are thin. They construct dependencies, expose repository streams
/// via `StreamProvider`, and call domain functions. **No rule, guard or
/// validation may live in a provider.**" Everything here either builds an
/// object or forwards a stream; the rules it hands those objects to are in
/// `zen_domain`, and the commands that call them are in `idea_actions.dart`
/// and `task_actions.dart`.
///
/// [databaseProvider], [initialSettingsProvider] and [deviceNameProvider] are
/// overridden in `main.dart`, which is the only place that may read a clock,
/// touch the file system or ask the platform anything.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zen_data/zen_data.dart';
import 'package:zen_domain/zen_domain.dart';

import '../theme/decor_pack.dart';
import '../theme/decor_registry.dart';
import 'system_clock.dart';

/// The open database. Overridden in `main.dart`; reading it without that
/// override is programmer error.
final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>(
  (Ref ref) => throw UnimplementedError(
    'databaseProvider is overridden in main() with the opened database',
  ),
);

/// §11.5.1, D-M3-15. This device's name, asked of the platform in `main.dart`.
final Provider<String> deviceNameProvider = Provider<String>(
  (Ref ref) => throw UnimplementedError(
    'deviceNameProvider is overridden in main() with the platform device name',
  ),
);

/// The settings as read once before the first frame.
///
/// [settingsProvider] is the live view; this is what the theme uses until that
/// stream's first event arrives, so a cold start never flashes the wrong theme
/// (NAV-3: "no splash or loading screen beyond platform minimums").
final Provider<Settings> initialSettingsProvider = Provider<Settings>(
  (Ref ref) => throw UnimplementedError(
    'initialSettingsProvider is overridden in main() with the stored settings',
  ),
);

/// §11.11. The only clock in the application.
final Provider<Clock> clockProvider = Provider<Clock>(
  (Ref ref) => SystemClock(zoneId: ref.watch(localZoneIdProvider)),
);

/// EOD-5. The device's IANA zone id, resolved in `main.dart`.
final Provider<String> localZoneIdProvider = Provider<String>(
  (Ref ref) => throw UnimplementedError(
    'localZoneIdProvider is overridden in main() with the device time zone',
  ),
);

/// §3. UUIDv7 ids.
final Provider<IdGenerator> idGeneratorProvider = Provider<IdGenerator>(
  (Ref ref) => const UuidV7IdGenerator(),
);

/// §11.4.3, EOD-5. The IANA rules, from `zen_data`'s `timezone` adapter.
final Provider<TimeZoneRules> timeZoneRulesProvider = Provider<TimeZoneRules>(
  (Ref ref) => TimeZoneDatabaseRules(),
);

// ---------------------------------------------------------------------------
// Repositories (§11.4.6). STORE-2: every read and write goes through these.
// ---------------------------------------------------------------------------

/// HIST-2. The append-only event log, for the start-up prune (§11.5.1).
final Provider<EventLog> eventLogProvider = Provider<EventLog>(
  (Ref ref) => DriftEventLog(ref.watch(databaseProvider)),
);

/// Storage for Ideas.
final Provider<IdeaRepository> ideaRepositoryProvider =
    Provider<IdeaRepository>(
      (Ref ref) => DriftIdeaRepository(
        ref.watch(databaseProvider),
        ids: ref.watch(idGeneratorProvider),
      ),
    );

/// Storage for Tasks.
final Provider<TaskRepository> taskRepositoryProvider =
    Provider<TaskRepository>(
      (Ref ref) => DriftTaskRepository(
        ref.watch(databaseProvider),
        ids: ref.watch(idGeneratorProvider),
        zone: ref.watch(timeZoneRulesProvider),
      ),
    );

/// §11.5.1, D-M3-15. This installation's replica row.
final Provider<ReplicaRepository> replicaRepositoryProvider =
    Provider<ReplicaRepository>(
      (Ref ref) => DriftReplicaRepository(
        ref.watch(databaseProvider),
        ids: ref.watch(idGeneratorProvider),
        defaultDeviceName: ref.watch(deviceNameProvider),
      ),
    );

/// Storage for the per-replica settings of §3.6.
final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
      (Ref ref) => DriftSettingsRepository(ref.watch(databaseProvider)),
    );

/// §9.3 step 1. Idea tombstones.
final Provider<TombstoneStore> tombstoneStoreProvider =
    Provider<TombstoneStore>(
      (Ref ref) => DriftTombstoneStore(ref.watch(databaseProvider)),
    );

/// CONVERT-4. The one atomic Idea-to-Task transaction.
final Provider<ConversionService> conversionServiceProvider =
    Provider<ConversionService>(
      (Ref ref) => DriftConversionService(
        ref.watch(databaseProvider),
        ids: ref.watch(idGeneratorProvider),
      ),
    );

// ---------------------------------------------------------------------------
// Streams (§11.7: "Lists watch Drift streams, so a completion-circle tap
// updates the list without manual refresh").
// ---------------------------------------------------------------------------

/// TODO-1, TODO-2. The To Do list.
final StreamProvider<List<Task>> activeTasksProvider =
    StreamProvider<List<Task>>(
      (Ref ref) => ref.watch(taskRepositoryProvider).watchActive(),
    );

/// ARCH-1. The Archived Tasks list.
final StreamProvider<List<Task>> archivedTasksProvider =
    StreamProvider<List<Task>>(
      (Ref ref) => ref.watch(taskRepositoryProvider).watchArchived(),
    );

/// SEARCH-2. Every Task, for the Search screen's state filter.
final StreamProvider<List<Task>> allTasksProvider = StreamProvider<List<Task>>(
  (Ref ref) => ref.watch(taskRepositoryProvider).watchAll(),
);

/// IDEAS-4. Every Idea, oldest first.
final StreamProvider<List<Idea>> ideasProvider = StreamProvider<List<Idea>>(
  (Ref ref) => ref.watch(ideaRepositoryProvider).watchAll(),
);

/// SET-2. The live settings.
final StreamProvider<Settings> settingsProvider = StreamProvider<Settings>(
  (Ref ref) => ref.watch(settingsRepositoryProvider).watch(),
);

/// The settings every screen reads: the live value once it has arrived, and
/// the value `main.dart` read before the first frame until then.
final Provider<Settings> currentSettingsProvider = Provider<Settings>(
  (Ref ref) =>
      ref.watch(settingsProvider).value ?? ref.watch(initialSettingsProvider),
);

/// TAG-6. "All tags that exist on any active Item", for the chip input's
/// autocomplete.
///
/// Deduplicated case-insensitively (TAG-4) and sorted, keeping the first
/// casing seen so the suggestion reads the way the user last typed it.
final Provider<List<Tag>> activeTagsProvider = Provider<List<Tag>>((Ref ref) {
  final Map<String, Tag> byNormalized = <String, Tag>{};
  for (final Tag tag in <Tag>[
    for (final Idea idea in ref.watch(ideasProvider).value ?? const <Idea>[])
      ...idea.tags,
    for (final Task task
        in ref.watch(activeTasksProvider).value ?? const <Task>[])
      ...task.tags,
  ]) {
    byNormalized.putIfAbsent(tag.normalized, () => tag);
  }
  final List<Tag> tags = byNormalized.values.toList()
    ..sort((Tag a, Tag b) => a.normalized.compareTo(b.normalized));
  return List<Tag>.unmodifiable(tags);
});

// ---------------------------------------------------------------------------
// Decor (§3.6.1).
// ---------------------------------------------------------------------------

/// §11.7. The registry, "injected through a provider".
final Provider<DecorRegistry> decorRegistryProvider = Provider<DecorRegistry>(
  (Ref ref) => DecorRegistry.mvp(),
);

/// §11.7. The active pack. "Widgets read the active pack and never name a
/// specific one."
final Provider<DecorPack> activeDecorProvider = Provider<DecorPack>(
  (Ref ref) => ref
      .watch(decorRegistryProvider)
      .byId(ref.watch(currentSettingsProvider).decor),
);

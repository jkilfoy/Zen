/// In-memory repository doubles for the orchestrator tests.
///
/// The orchestrator talks to seven `zen_domain` interfaces. `zen_sync` cannot
/// depend on `zen_data` (§11.1), so these stand in for the Drift
/// implementations wherever the test is about §11.6.5's control flow rather
/// than about storage. The convergence simulation of §11.12 item 3 is the
/// counterweight: it runs the same orchestrator against **real** databases, in
/// `zen_app/test/integration/`.
library;

import 'package:zen_domain/zen_domain.dart';

/// A [ReplicaRepository] returning a fixed identity.
final class FakeReplicaRepository implements ReplicaRepository {
  /// Creates a repository reporting [id] and [name].
  FakeReplicaRepository(this.id, this.name);

  /// This replica's id.
  final String id;

  /// This device's name.
  final String name;

  @override
  Future<String> replicaId() async => id;

  @override
  Future<String> deviceName() async => name;
}

/// One replica's dataset, held in memory.
///
/// A single object rather than three, because §11.6.5 reads Ideas, Tasks and
/// tombstones to build the local snapshot and then replaces all three together;
/// keeping them in separate doubles would let a test drift into a state no real
/// database could reach. The repository interfaces are thin views over it,
/// because `IdeaRepository` and `TaskRepository` declare `watchAll`, `findById`,
/// `create` and `update` with incompatible types and one class cannot implement
/// both.
final class InMemoryDataset {
  /// Creates a dataset holding [initial], or an empty one.
  InMemoryDataset([ReplicaSnapshot? initial]) {
    if (initial != null) {
      ideas = List<Idea>.of(initial.ideas);
      tasks = List<Task>.of(initial.tasks);
      tombstones = List<IdeaTombstone>.of(initial.tombstones);
    }
  }

  /// This replica's Ideas.
  List<Idea> ideas = <Idea>[];

  /// This replica's Tasks, including archived and soft-deleted ones.
  List<Task> tasks = <Task>[];

  /// This replica's Idea tombstones.
  List<IdeaTombstone> tombstones = <IdeaTombstone>[];

  /// How many times the dataset has been replaced wholesale.
  int replaceCount = 0;

  /// The dataset as a snapshot.
  ReplicaSnapshot asSnapshot(String replicaId) => ReplicaSnapshot(
    replicaId: replicaId,
    ideas: ideas,
    tasks: tasks,
    tombstones: tombstones,
  );

  /// The [IdeaRepository] view.
  IdeaRepository get ideaRepository => _Ideas(this);

  /// The [TaskRepository] view.
  TaskRepository get taskRepository => _Tasks(this);

  /// The [TombstoneStore] view.
  TombstoneStore get tombstoneStore => _Tombstones(this);

  /// The [DatasetRepository] view.
  DatasetRepository get datasetRepository => _Dataset(this);
}

/// Every method below that throws is one §11.6.5 never calls. Failing loudly
/// rather than returning a plausible empty value: a sync that started calling
/// one of these would be doing something the specification does not describe,
/// and a silent default would hide it.
final class _Ideas implements IdeaRepository {
  _Ideas(this._data);

  final InMemoryDataset _data;

  @override
  Stream<List<Idea>> watchAll() => Stream<List<Idea>>.value(_data.ideas);

  @override
  Future<Idea?> findById(String id) => throw UnimplementedError();

  @override
  Future<Idea?> findActiveByNormalizedName(String normalized) =>
      throw UnimplementedError();

  @override
  Future<Set<String>> activeNormalizedNames() => throw UnimplementedError();

  @override
  Future<Result<Idea, RuleViolation>> create(Idea idea) =>
      throw UnimplementedError();

  @override
  Future<Result<Idea, RuleViolation>> update(Idea idea) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id, DateTime now) => throw UnimplementedError();
}

final class _Tasks implements TaskRepository {
  _Tasks(this._data);

  final InMemoryDataset _data;

  /// §11.6.5 step 2 builds the snapshot from this one, which is why it includes
  /// archived and soft-deleted Tasks: a snapshot carrying only the To Do list
  /// would let a peer's copy of an archived Task resurrect it on the next merge.
  @override
  Stream<List<Task>> watchAll() => Stream<List<Task>>.value(_data.tasks);

  @override
  Stream<List<Task>> watchActive() => Stream<List<Task>>.value(
    _data.tasks.where((Task t) => t.isActive).toList(growable: false),
  );

  @override
  Stream<List<Task>> watchArchived() => Stream<List<Task>>.value(
    _data.tasks
        .where((Task t) => t.isArchived && !t.isDeleted)
        .toList(growable: false),
  );

  @override
  Future<Task?> findById(String id) => throw UnimplementedError();

  @override
  Future<Task?> findActiveByNormalizedName(String normalized) =>
      throw UnimplementedError();

  @override
  Future<Set<String>> activeNormalizedNames() => throw UnimplementedError();

  @override
  Future<Result<Task, RuleViolation>> create(Task task) =>
      throw UnimplementedError();

  @override
  Future<Result<Task, RuleViolation>> update(Task task) =>
      throw UnimplementedError();

  @override
  Future<Result<Task, RuleViolation>> softDelete(String id, DateTime now) =>
      throw UnimplementedError();

  @override
  Future<Result<Task, RuleViolation>> restore(String id, DateTime now) =>
      throw UnimplementedError();

  @override
  Future<Result<Task, RuleViolation>> unarchive(String id, DateTime now) =>
      throw UnimplementedError();

  @override
  Future<List<Task>> runArchiveSweep({
    required DateTime nowUtc,
    required LocalTime endOfDay,
    required String zoneId,
  }) => throw UnimplementedError();
}

final class _Tombstones implements TombstoneStore {
  _Tombstones(this._data);

  final InMemoryDataset _data;

  @override
  Future<List<IdeaTombstone>> all() async => _data.tombstones;

  @override
  Future<Set<String>> tombstonedIdeaIds() async =>
      _data.tombstones.map((IdeaTombstone t) => t.id).toSet();

  @override
  Future<void> add(IdeaTombstone tombstone) async =>
      _data.tombstones.add(tombstone);
}

final class _Dataset implements DatasetRepository {
  _Dataset(this._data);

  final InMemoryDataset _data;

  @override
  Future<void> replaceAll(ReplicaSnapshot snapshot) async {
    _data.replaceCount++;
    _data.ideas = List<Idea>.of(snapshot.ideas);
    _data.tasks = List<Task>.of(snapshot.tasks);
    _data.tombstones = List<IdeaTombstone>.of(snapshot.tombstones);
  }
}

/// A [SettingsRepository] over a single in-memory record.
final class InMemorySettings implements SettingsRepository {
  /// Creates a repository holding [settings], or the factory defaults.
  InMemorySettings([Settings? settings]) : _settings = settings ?? Settings();

  Settings _settings;

  @override
  Stream<Settings> watch() => Stream<Settings>.value(_settings);

  @override
  Future<Settings> read() async => _settings;

  @override
  Future<void> write(Settings settings) async => _settings = settings;
}

/// An [EventLog] that keeps what it is given.
final class InMemoryEventLog implements EventLog {
  /// Every appended event, in order.
  final List<ItemEvent> appended = <ItemEvent>[];

  @override
  Future<void> append(ItemEvent event) async => appended.add(event);

  @override
  Future<List<ItemEvent>> forItem(String itemId) async => appended
      .where((ItemEvent e) => e.itemId == itemId)
      .toList(growable: false);

  @override
  Future<int> prune(DateTime nowUtc) async => 0;
}

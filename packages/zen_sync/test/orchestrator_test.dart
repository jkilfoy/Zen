/// §11.6.5. The eight steps of one sync pass.
library;

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zen_domain/testing.dart';
import 'package:zen_domain/zen_domain.dart';
import 'package:zen_sync/zen_sync.dart';

import 'support/fixtures.dart';
import 'support/in_memory_repositories.dart';

/// A transport a test can drive: it holds envelopes in memory and can be told
/// to fail, which is how §11.6.5 step 3's "MUST NOT abort the pass" is checked.
final class FakeTransport implements SyncTransport {
  FakeTransport(this.id, {this.available = true});

  @override
  final String id;

  /// What `availability()` reports.
  bool available;

  /// Peers this transport will hand back.
  List<SnapshotEnvelope> peers = <SnapshotEnvelope>[];

  /// Every envelope `publish` was given.
  final List<SnapshotEnvelope> published = <SnapshotEnvelope>[];

  /// When set, `fetchPeerSnapshots` throws this instead of returning.
  Object? fetchError;

  /// When set, `publish` throws this instead of recording.
  Object? publishError;

  @override
  Future<TransportAvailability> availability() async => available
      ? const TransportAvailability.reachable()
      : const TransportAvailability.unreachable('not available');

  /// §11.6.2. What step 2 captured and handed to this transport.
  ///
  /// Recorded rather than ignored: the LAN transport's whole purpose is to send
  /// it, so a test that the orchestrator passes the right value is worth having
  /// even for a fake that does not need it.
  SnapshotEnvelope? fetchedWith;

  @override
  Future<List<SnapshotEnvelope>> fetchPeerSnapshots(
    SnapshotEnvelope local,
  ) async {
    fetchedWith = local;
    if (fetchError case final Object error) {
      throw error;
    }
    return peers;
  }

  @override
  Future<void> publish(SnapshotEnvelope envelope) async {
    if (publishError case final Object error) {
      throw error;
    }
    published.add(envelope);
  }
}

void main() {
  late Directory root;
  late InMemoryDataset data;
  late InMemorySettings settings;
  late InMemoryEventLog events;
  late FakeClock clock;
  late List<String> warnings;

  setUp(() {
    root = Directory.systemTemp.createTempSync('zen_orchestrator');
    data = InMemoryDataset();
    settings = InMemorySettings();
    events = InMemoryEventLog();
    clock = FakeClock(t0);
    warnings = <String>[];
  });

  tearDown(() => root.deleteSync(recursive: true));

  SyncOrchestrator orchestratorOver(
    List<SyncTransport> transports, {
    String replicaId = 'replica-a',
  }) => SyncOrchestrator(
    enabledTransports: () async => transports,
    replicas: FakeReplicaRepository(replicaId, 'desktop'),
    ideas: data.ideaRepository,
    tasks: data.taskRepository,
    tombstones: data.tombstoneStore,
    dataset: data.datasetRepository,
    settings: settings,
    events: events,
    mergeStrategy: const NameUnionMergeStrategy(),
    backups: BackupStore(directoryPath: '${root.path}/backups'),
    clock: clock,
    ids: SequentialIdGenerator(prefix: 'event'),
    appVersion: '1.0.0',
    log: warnings.add,
  );

  SnapshotEnvelope peerEnvelope(
    String replicaId, {
    List<Idea> ideas = const <Idea>[],
    List<Task> tasks = const <Task>[],
    List<IdeaTombstone> tombstones = const <IdeaTombstone>[],
    DateTime? generatedAt,
  }) => SnapshotEnvelope(
    replicaId: replicaId,
    deviceName: 'device-$replicaId',
    generatedAt: generatedAt ?? t0,
    appVersion: '1.0.0',
    snapshot: snapshot(
      replicaId,
      ideas: ideas,
      tasks: tasks,
      tombstones: tombstones,
    ),
  );

  group('§11.6.5 step 1: single flight', () {
    test(
      'a second request joins the running pass rather than starting one',
      () async {
        final FakeTransport transport = FakeTransport('file');
        final SyncOrchestrator orchestrator = orchestratorOver(<SyncTransport>[
          transport,
        ]);

        final Future<SyncOutcome> first = orchestrator.sync();
        final Future<SyncOutcome> second = orchestrator.sync();

        expect(identical(first, second), isTrue);
        await first;
        expect(transport.published, hasLength(1));
      },
    );

    test('the lock is released once the pass finishes', () async {
      final FakeTransport transport = FakeTransport('file');
      final SyncOrchestrator orchestrator = orchestratorOver(<SyncTransport>[
        transport,
      ]);

      await orchestrator.sync();
      expect(orchestrator.isSyncing, isFalse);
      await orchestrator.sync();

      expect(transport.published, hasLength(2));
    });
  });

  group('§11.6.5 step 3: no peers still publishes', () {
    test('a first run over an empty folder publishes anyway', () async {
      // The v1.11 correction. Before it: "device A finds no peers and writes
      // nothing, device B does the same, and the two never discover each
      // other." Publishing is the only thing that makes this device visible.
      final FakeTransport transport = FakeTransport('file');
      data.ideas.add(idea('idea-1', 'Learn Dart'));

      final SyncOutcome outcome = await orchestratorOver(<SyncTransport>[
        transport,
      ]).sync();

      expect(transport.published, hasLength(1));
      expect(transport.published.single.snapshot.ideas, hasLength(1));
      expect(outcome.merged, isFalse);
      expect(outcome.published, isTrue);
    });

    test(
      'no merge runs and no backup is taken when there is nothing to merge',
      () async {
        final SyncOutcome outcome = await orchestratorOver(<SyncTransport>[
          FakeTransport('file'),
        ]).sync();

        expect(outcome.report, isNull);
        expect(outcome.backup, isNull);
        expect(data.replaceCount, 0);
        expect(Directory('${root.path}/backups').existsSync(), isFalse);
      },
    );
  });

  group('§11.6.5 step 7: publishes the post-merge dataset', () {
    test('what is published is what the database now holds', () async {
      // Publishing the step-2 snapshot instead "describes a state this device
      // has already left, and relaying it costs every peer an extra round".
      final FakeTransport transport = FakeTransport('file')
        ..peers = <SnapshotEnvelope>[
          peerEnvelope('replica-b', ideas: <Idea>[idea('idea-2', 'Read more')]),
        ];
      data.ideas.add(idea('idea-1', 'Learn Dart'));

      await orchestratorOver(<SyncTransport>[transport]).sync();

      expect(
        transport.published.single.snapshot.ideas.map((Idea i) => i.id),
        <String>['idea-1', 'idea-2'],
        reason: 'the peer\'s Idea is in the published snapshot, not just ours',
      );
      expect(
        transport.published.single.snapshot,
        data.asSnapshot('replica-a'),
        reason: 'the file and the database agree',
      );
    });

    test('publishes to a transport that reported itself unreachable', () async {
      // "Attempting the write is how a transport discovers it is usable."
      final FakeTransport transport = FakeTransport('file', available: false);

      final SyncOutcome outcome = await orchestratorOver(<SyncTransport>[
        transport,
      ]).sync();

      expect(transport.published, hasLength(1));
      expect(outcome.transports.single.fetch, SyncFetchStatus.unavailable);
      expect(outcome.transports.single.publish, SyncPublishStatus.published);
    });
  });

  group('§11.6.5 step 3: a failing transport must not abort the pass', () {
    test('the other transport\'s peers are still merged', () async {
      final FakeTransport failing = FakeTransport('lan')
        ..fetchError = StateError('desktop not running');
      final FakeTransport working = FakeTransport('file')
        ..peers = <SnapshotEnvelope>[
          peerEnvelope('replica-b', ideas: <Idea>[idea('idea-2', 'Read more')]),
        ];

      final SyncOutcome outcome = await orchestratorOver(<SyncTransport>[
        failing,
        working,
      ]).sync();

      expect(data.ideas.map((Idea i) => i.id), <String>['idea-2']);
      expect(outcome.peersMerged, 1);
      expect(
        outcome.transports
            .firstWhere((TransportOutcome t) => t.transportId == 'lan')
            .fetch,
        SyncFetchStatus.failed,
      );
      expect(warnings.single, contains('desktop not running'));
    });

    test('a failing publish is recorded and the pass completes', () async {
      final FakeTransport transport = FakeTransport('file')
        ..publishError = const FileSystemException('disk full');

      final SyncOutcome outcome = await orchestratorOver(<SyncTransport>[
        transport,
      ]).sync();

      expect(outcome.transports.single.publish, SyncPublishStatus.failed);
      expect(outcome.isHealthy, isFalse);
      expect(outcome.published, isFalse);
      expect(settings.read(), completion(isA<Settings>()));
    });

    test(
      'an availability check that throws is recorded, not propagated',
      () async {
        final FakeTransport transport = FakeTransport('file');
        final SyncOrchestrator orchestrator = SyncOrchestrator(
          enabledTransports: () async => <SyncTransport>[
            _ThrowingAvailability(),
          ],
          replicas: FakeReplicaRepository('replica-a', 'desktop'),
          ideas: data.ideaRepository,
          tasks: data.taskRepository,
          tombstones: data.tombstoneStore,
          dataset: data.datasetRepository,
          settings: settings,
          events: events,
          mergeStrategy: const NameUnionMergeStrategy(),
          backups: BackupStore(directoryPath: '${root.path}/backups'),
          clock: clock,
          ids: SequentialIdGenerator(prefix: 'event'),
          appVersion: '1.0.0',
          log: warnings.add,
        );

        final SyncOutcome outcome = await orchestrator.sync();

        expect(outcome.transports.single.fetch, SyncFetchStatus.failed);
        expect(transport.published, isEmpty);
      },
    );
  });

  group('§11.6.5 step 3: cross-transport de-duplication', () {
    test(
      'the same replica over two transports keeps the later generatedAt',
      () async {
        final FakeTransport file = FakeTransport('file')
          ..peers = <SnapshotEnvelope>[
            peerEnvelope(
              'replica-b',
              ideas: <Idea>[idea('idea-old', 'Stale idea')],
              generatedAt: at(0),
            ),
          ];
        final FakeTransport lan = FakeTransport('lan')
          ..peers = <SnapshotEnvelope>[
            peerEnvelope(
              'replica-b',
              ideas: <Idea>[idea('idea-new', 'Fresh idea')],
              generatedAt: at(60),
            ),
          ];

        final SyncOutcome outcome = await orchestratorOver(<SyncTransport>[
          file,
          lan,
        ]).sync();

        expect(outcome.peersMerged, 1);
        expect(data.ideas.map((Idea i) => i.id), <String>['idea-new']);
      },
    );

    test('distinct replicas are all merged', () async {
      data.ideas.add(idea('idea-1', 'Learn Dart'));
      final FakeTransport file = FakeTransport('file')
        ..peers = <SnapshotEnvelope>[
          peerEnvelope('replica-b', ideas: <Idea>[idea('idea-2', 'Read more')]),
        ];
      final FakeTransport lan = FakeTransport('lan')
        ..peers = <SnapshotEnvelope>[
          peerEnvelope('replica-c', ideas: <Idea>[idea('idea-3', 'Run daily')]),
        ];

      final SyncOutcome outcome = await orchestratorOver(<SyncTransport>[
        file,
        lan,
      ]).sync();

      expect(outcome.peersMerged, 2);
      expect(data.ideas, hasLength(3));
    });

    test('a peer carrying our own replicaId is ignored', () async {
      final FakeTransport transport = FakeTransport('file')
        ..peers = <SnapshotEnvelope>[
          peerEnvelope('replica-a', ideas: <Idea>[idea('idea-9', 'Not ours')]),
        ];

      final SyncOutcome outcome = await orchestratorOver(<SyncTransport>[
        transport,
      ]).sync();

      expect(outcome.peersMerged, 0);
      expect(outcome.merged, isFalse);
    });
  });

  group('§11.6.5 steps 4 to 6', () {
    test('the backup is written before the dataset is replaced', () async {
      data.ideas.add(idea('idea-1', 'Learn Dart'));
      final FakeTransport transport = FakeTransport('file')
        ..peers = <SnapshotEnvelope>[
          peerEnvelope('replica-b', ideas: <Idea>[idea('idea-2', 'Read more')]),
        ];

      final SyncOutcome outcome = await orchestratorOver(<SyncTransport>[
        transport,
      ]).sync();

      expect(outcome.backup, isNotNull);
      final BackupStore store = BackupStore(
        directoryPath: '${root.path}/backups',
      );
      final SnapshotEnvelope restored = (await store.read(outcome.backup!))
          .unwrap();
      expect(restored.snapshot.ideas.map((Idea i) => i.id), <String>[
        'idea-1',
      ], reason: 'the backup holds the dataset as it was before the merge');
    });

    test('the merge result is applied in one wholesale replace', () async {
      data.ideas.add(idea('idea-1', 'Learn Dart'));
      final FakeTransport transport = FakeTransport('file')
        ..peers = <SnapshotEnvelope>[
          peerEnvelope('replica-b', ideas: <Idea>[idea('idea-2', 'Read more')]),
        ];

      await orchestratorOver(<SyncTransport>[transport]).sync();

      expect(data.replaceCount, 1);
      expect(data.ideas.map((Idea i) => i.id), <String>['idea-1', 'idea-2']);
    });

    test('a merged component appends a `merged` event (§9.3 step 7)', () async {
      // The same Idea on both replicas, renamed on the peer: one component.
      data.ideas.add(idea('idea-1', 'Groceries list', updatedAt: at(0)));
      final FakeTransport transport = FakeTransport('file')
        ..peers = <SnapshotEnvelope>[
          peerEnvelope(
            'replica-b',
            ideas: <Idea>[idea('idea-1', 'Groceries', updatedAt: at(5))],
          ),
        ];

      final SyncOutcome outcome = await orchestratorOver(<SyncTransport>[
        transport,
      ]).sync();

      expect(outcome.report!.components, hasLength(1));
      expect(events.appended, hasLength(1));
      final ItemEvent event = events.appended.single;
      expect(event.type, ItemEventType.merged);
      expect(event.itemId, 'idea-1');
      expect(event.itemKind, ItemKind.idea);
      expect(event.payload['inputIds'], <String>['idea-1']);
      expect(
        data.ideas.single.name.value,
        'Groceries',
        reason:
            'the later updatedAt wins, so the rename survives (§9.3 step 4)',
      );
    });

    test('a pass-through merge appends no events', () async {
      data.ideas.add(idea('idea-1', 'Learn Dart'));
      final FakeTransport transport = FakeTransport('file')
        ..peers = <SnapshotEnvelope>[
          peerEnvelope('replica-b', ideas: <Idea>[idea('idea-2', 'Read more')]),
        ];

      await orchestratorOver(<SyncTransport>[transport]).sync();

      expect(events.appended, isEmpty);
    });

    test('AC-17: a tombstoned Idea is not resurrected by a peer', () async {
      data.tombstones.add(tombstone('idea-1'));
      final FakeTransport transport = FakeTransport('file')
        ..peers = <SnapshotEnvelope>[
          peerEnvelope(
            'replica-b',
            ideas: <Idea>[idea('idea-1', 'Learn Dart')],
          ),
        ];

      await orchestratorOver(<SyncTransport>[transport]).sync();

      expect(data.ideas, isEmpty);
      expect(data.tombstones.map((IdeaTombstone t) => t.id), <String>[
        'idea-1',
      ]);
    });
  });

  group('§11.6.5 step 6: a merge that cannot be applied', () {
    test('is reported, and the pre-merge dataset is what gets published', () async {
      // `replaceAll` is one transaction (STORE-3), so a constraint that fires
      // rolls it back and the device still holds what it held at step 2. The
      // pass must therefore publish *that*, not the merge result the database
      // rejected — and it must still finish, because nothing here may throw at
      // its caller (NFR-1).
      data.ideas.add(idea('idea-1', 'Learn Dart'));
      final _RefusingDataset refusing = _RefusingDataset();
      final FakeTransport transport = FakeTransport('file')
        ..peers = <SnapshotEnvelope>[
          peerEnvelope('replica-b', ideas: <Idea>[idea('idea-2', 'Read more')]),
        ];

      final SyncOutcome outcome = await SyncOrchestrator(
        enabledTransports: () async => <SyncTransport>[transport],
        replicas: FakeReplicaRepository('replica-a', 'desktop'),
        ideas: data.ideaRepository,
        tasks: data.taskRepository,
        tombstones: data.tombstoneStore,
        dataset: refusing,
        settings: settings,
        events: events,
        mergeStrategy: const NameUnionMergeStrategy(),
        backups: BackupStore(directoryPath: '${root.path}/backups'),
        clock: clock,
        ids: SequentialIdGenerator(prefix: 'event'),
        appVersion: '1.0.0',
        log: warnings.add,
      ).sync();

      expect(outcome.mergeFailure, isNotNull);
      expect(outcome.isHealthy, isFalse);
      expect(
        transport.published.single.snapshot.ideas.map((Idea i) => i.id),
        <String>['idea-1'],
        reason: 'the published file matches what the database still holds',
      );
      expect(warnings.single, contains('could not be applied'));
    });
  });

  group('§11.6.5 step 2: what the local snapshot carries', () {
    test('archived and soft-deleted Tasks travel', () async {
      // A snapshot carrying only the To Do list would let a peer's copy of an
      // archived Task resurrect it on the next merge.
      data.tasks.addAll(<Task>[
        task('task-1', 'Active one'),
        task(
          'task-2',
          'Archived one',
          status: TaskStatus.done,
          isArchived: true,
        ),
        task('task-3', 'Deleted one', isDeleted: true),
      ]);
      final FakeTransport transport = FakeTransport('file');

      await orchestratorOver(<SyncTransport>[transport]).sync();

      expect(
        transport.published.single.snapshot.tasks.map((Task t) => t.id),
        <String>['task-1', 'task-2', 'task-3'],
      );
    });

    test('MERGE-3: settings do not travel, whatever they hold', () async {
      settings = InMemorySettings(
        Settings(
          syncFolderEnabled: true,
          syncFolderLocation: r'D:\Sync\Zen',
          syncLanPeers: <LanPeer>[
            const LanPeer(
              replicaId: 'replica-b',
              deviceName: 'phone',
              host: '192.168.1.5',
              port: 51789,
              psk: 'c2VjcmV0',
            ),
          ],
        ),
      );
      final FakeTransport transport = FakeTransport('file');

      await orchestratorOver(<SyncTransport>[transport]).sync();

      final String encoded = const SnapshotCodec().encode(
        transport.published.single,
      );
      expect(encoded, isNot(contains('c2VjcmV0')));
      expect(encoded, isNot(contains('Sync')));
      expect(encoded, isNot(contains('51789')));
    });
  });

  group('§11.6.5 step 8', () {
    test('lastSyncAt records when the pass finished', () async {
      clock.set(at(42));

      final SyncOutcome outcome = await orchestratorOver(<SyncTransport>[
        FakeTransport('file'),
      ]).sync();

      expect(outcome.finishedAt, at(42));
      expect((await settings.read()).lastSyncAt, at(42));
    });

    test('the other settings are left alone', () async {
      settings = InMemorySettings(
        Settings(syncIntervalMinutes: 30, syncOnForeground: false),
      );

      await orchestratorOver(<SyncTransport>[FakeTransport('file')]).sync();

      final Settings after = await settings.read();
      expect(after.syncIntervalMinutes, 30);
      expect(after.syncOnForeground, isFalse);
    });

    test('an outcome names every enabled transport', () async {
      final SyncOutcome outcome = await orchestratorOver(<SyncTransport>[
        FakeTransport('file'),
        FakeTransport('lan'),
      ]).sync();

      expect(
        outcome.transports.map((TransportOutcome t) => t.transportId),
        <String>['file', 'lan'],
      );
    });

    test('no enabled transport is a complete, harmless pass', () async {
      final SyncOutcome outcome = await orchestratorOver(<SyncTransport>[])
          .sync();

      expect(outcome.transports, isEmpty);
      expect(outcome.merged, isFalse);
      expect(outcome.published, isFalse);
      expect(data.replaceCount, 0);
    });
  });
}

/// A transport whose `availability()` throws, which §11.6.5 step 3 must absorb.
final class _ThrowingAvailability implements SyncTransport {
  @override
  String get id => 'file';

  @override
  Future<TransportAvailability> availability() async =>
      throw StateError('grant revoked');

  @override
  Future<List<SnapshotEnvelope>> fetchPeerSnapshots(
    SnapshotEnvelope local,
  ) async => <SnapshotEnvelope>[];

  @override
  Future<void> publish(SnapshotEnvelope envelope) async {}
}

/// A [DatasetRepository] that refuses every write, standing in for a schema
/// constraint firing inside `replaceAll`.
final class _RefusingDataset implements DatasetRepository {
  @override
  Future<void> replaceAll(ReplicaSnapshot snapshot) async =>
      throw StateError('UNIQUE constraint failed: ideas.name_normalized');
}

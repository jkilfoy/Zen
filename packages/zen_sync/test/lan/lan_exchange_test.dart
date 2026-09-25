/// §11.6.4. The whole exchange: a phone and a desktop, one round trip, both
/// ends merging independently and arriving at the same dataset.
///
/// This is M7's definition of done — "merge-exchange logic covered by automated
/// tests against a loopback server" — and it is deliberately built out of the
/// real pieces: two `SyncOrchestrator`s over two datasets, a real
/// `LanSyncServer` bound to loopback, and a real `LanSyncTransport` reaching it
/// over HTTP. Nothing between the two replicas is a test double.
library;

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zen_domain/testing.dart';
import 'package:zen_domain/zen_domain.dart';
import 'package:zen_sync/zen_sync.dart';

import '../support/fixtures.dart';
import '../support/in_memory_repositories.dart';

void main() {
  late Directory root;
  late FakeClock clock;

  setUp(() {
    clock = FakeClock(t0);
    root = Directory.systemTemp.createTempSync('zen-lan-');
  });

  tearDown(() => root.deleteSync(recursive: true));

  /// One replica: its data, its settings and its orchestrator.
  ///
  /// Built the same way on both sides, so the only asymmetry in this file is
  /// the one §11.6.4 specifies — the desktop serves and the phone dials.
  ({
    InMemoryDataset data,
    InMemorySettings settings,
    SyncOrchestrator orchestrator,
  })
  replica(
    String replicaId,
    String deviceName, {
    List<SyncTransport> transports = const <SyncTransport>[],
  }) {
    final InMemoryDataset data = InMemoryDataset();
    final InMemorySettings settings = InMemorySettings();
    return (
      data: data,
      settings: settings,
      orchestrator: SyncOrchestrator(
        enabledTransports: () async => transports,
        replicas: FakeReplicaRepository(replicaId, deviceName),
        ideas: data.ideaRepository,
        tasks: data.taskRepository,
        tombstones: data.tombstoneStore,
        dataset: data.datasetRepository,
        settings: settings,
        events: InMemoryEventLog(),
        mergeStrategy: const NameUnionMergeStrategy(),
        backups: BackupStore(directoryPath: '${root.path}/$replicaId'),
        clock: clock,
        ids: SequentialIdGenerator(prefix: 'event-$replicaId'),
        appVersion: '1.0.0',
      ),
    );
  }

  group('§11.6.4 one round trip, both ends merging', () {
    test('a phone and a desktop converge in a single pass', () async {
      final desktop = replica('replica-desktop', 'Jordan PC');
      desktop.data.ideas = <Idea>[idea('idea-desktop', 'Buy a kettle')];

      final LanSyncServer server = LanSyncServer(
        replicas: FakeReplicaRepository('replica-desktop', 'Jordan PC'),
        settings: desktop.settings,
        snapshotSource: () async => SnapshotEnvelope(
          replicaId: 'replica-desktop',
          deviceName: 'Jordan PC',
          generatedAt: clock.nowUtc(),
          appVersion: '1.0.0',
          snapshot: desktop.data.asSnapshot('replica-desktop'),
        ),
        // "The handler passes the client's envelope into the same entry point
        // `"Import snapshot…"` uses."
        inboundMerge: (SnapshotEnvelope peer) =>
            desktop.orchestrator.syncWith(<SnapshotEnvelope>[peer]),
        clock: clock,
        appVersion: '1.0.0',
      );
      addTearDown(server.stop);
      await server.start(port: 0, address: InternetAddress.loopbackIPv4);

      // Pair, the way the pairing screen does.
      final PairingWindow window = server.openPairingWindow();
      final LanClient client = LanClient();
      addTearDown(client.close);
      final LanPeer peer = await client.pair(
        host: '127.0.0.1',
        port: server.boundPort!,
        code: window.code,
        replicaId: 'replica-phone',
        deviceName: 'Pixel',
      );

      final InMemorySettings phoneSettings = InMemorySettings(
        Settings(syncLanEnabled: true, syncLanPeers: <LanPeer>[peer]),
      );
      final InMemoryDataset phoneData = InMemoryDataset()
        ..ideas = <Idea>[idea('idea-phone', 'Call the dentist')];
      final SyncOrchestrator phone = SyncOrchestrator(
        enabledTransports: () async => <SyncTransport>[
          LanSyncTransport(
            settings: phoneSettings,
            clock: clock,
            client: client,
          ),
        ],
        replicas: FakeReplicaRepository('replica-phone', 'Pixel'),
        ideas: phoneData.ideaRepository,
        tasks: phoneData.taskRepository,
        tombstones: phoneData.tombstoneStore,
        dataset: phoneData.datasetRepository,
        settings: phoneSettings,
        events: InMemoryEventLog(),
        mergeStrategy: const NameUnionMergeStrategy(),
        backups: BackupStore(directoryPath: '${root.path}/phone'),
        clock: clock,
        ids: SequentialIdGenerator(prefix: 'event-phone'),
        appVersion: '1.0.0',
      );

      final SyncOutcome outcome = await phone.sync();

      expect(outcome.isHealthy, isTrue, reason: outcome.toString());
      expect(outcome.peersMerged, 1);

      // MERGE-2: both ran the same merge over the same pair of inputs, so the
      // two datasets are the same without either trusting the other's result.
      final List<String> phoneIdeas =
          phoneData.ideas.map((Idea i) => i.id).toList()..sort();
      final List<String> desktopIdeas =
          desktop.data.ideas.map((Idea i) => i.id).toList()..sort();

      expect(phoneIdeas, <String>['idea-desktop', 'idea-phone']);
      expect(desktopIdeas, phoneIdeas);
      expect(
        phoneData.asSnapshot('r'),
        desktop.data.asSnapshot('r'),
        reason: 'field-for-field identical, not merely the same ids',
      );
    });

    test('a second pass changes nothing on either side', () async {
      // Idempotence across the wire: the exchange is safe to repeat, which is
      // what makes an interrupted round trip harmless (§11.6.4).
      final desktop = replica('replica-desktop', 'Jordan PC');
      desktop.data.ideas = <Idea>[idea('idea-desktop', 'Buy a kettle')];

      final LanSyncServer server = LanSyncServer(
        replicas: FakeReplicaRepository('replica-desktop', 'Jordan PC'),
        settings: desktop.settings,
        snapshotSource: () async => SnapshotEnvelope(
          replicaId: 'replica-desktop',
          deviceName: 'Jordan PC',
          generatedAt: clock.nowUtc(),
          appVersion: '1.0.0',
          snapshot: desktop.data.asSnapshot('replica-desktop'),
        ),
        inboundMerge: (SnapshotEnvelope peer) =>
            desktop.orchestrator.syncWith(<SnapshotEnvelope>[peer]),
        clock: clock,
        appVersion: '1.0.0',
      );
      addTearDown(server.stop);
      await server.start(port: 0, address: InternetAddress.loopbackIPv4);

      final PairingWindow window = server.openPairingWindow();
      final LanClient client = LanClient();
      addTearDown(client.close);
      final LanPeer peer = await client.pair(
        host: '127.0.0.1',
        port: server.boundPort!,
        code: window.code,
        replicaId: 'replica-phone',
        deviceName: 'Pixel',
      );

      final InMemorySettings phoneSettings = InMemorySettings(
        Settings(syncLanEnabled: true, syncLanPeers: <LanPeer>[peer]),
      );
      final InMemoryDataset phoneData = InMemoryDataset()
        ..ideas = <Idea>[idea('idea-phone', 'Call the dentist')];
      final SyncOrchestrator phone = SyncOrchestrator(
        enabledTransports: () async => <SyncTransport>[
          LanSyncTransport(
            settings: phoneSettings,
            clock: clock,
            client: client,
          ),
        ],
        replicas: FakeReplicaRepository('replica-phone', 'Pixel'),
        ideas: phoneData.ideaRepository,
        tasks: phoneData.taskRepository,
        tombstones: phoneData.tombstoneStore,
        dataset: phoneData.datasetRepository,
        settings: phoneSettings,
        events: InMemoryEventLog(),
        mergeStrategy: const NameUnionMergeStrategy(),
        backups: BackupStore(directoryPath: '${root.path}/phone'),
        clock: clock,
        ids: SequentialIdGenerator(prefix: 'event-phone'),
        appVersion: '1.0.0',
      );

      await phone.sync();
      final ReplicaSnapshot afterFirst = phoneData.asSnapshot('r');
      await phone.sync();

      expect(phoneData.asSnapshot('r'), afterFirst);
      expect(desktop.data.asSnapshot('r'), afterFirst);
    });
  });

  group('§11.6.4 the transport', () {
    late InMemorySettings settings;

    LanSyncTransport transportOver(
      List<LanPeer> peers, {
      LanClient? client,
      PeerDiscovery discovery = const NoPeerDiscovery(),
    }) {
      settings = InMemorySettings(Settings(syncLanPeers: peers));
      return LanSyncTransport(
        settings: settings,
        clock: clock,
        client: client ?? LanClient(),
        discovery: discovery,
      );
    }

    SnapshotEnvelope local() => SnapshotEnvelope(
      replicaId: 'replica-phone',
      deviceName: 'Pixel',
      generatedAt: t0,
      appVersion: '1.0.0',
      snapshot: snapshot('replica-phone'),
    );

    LanPeer peerAt(String host, int port) => LanPeer(
      replicaId: 'replica-desktop',
      deviceName: 'Jordan PC',
      host: host,
      port: port,
      psk: newPairingKey(),
    );

    test('with nothing paired it is unreachable, without a probe', () async {
      final TransportAvailability availability = await transportOver(
        const <LanPeer>[],
      ).availability();

      expect(availability.reachable, isFalse);
      expect(availability.reason, 'No devices paired yet.');
    });

    test('with a peer paired it reports reachable', () async {
      expect(
        (await transportOver(<LanPeer>[
          peerAt('127.0.0.1', 1),
        ]).availability()).reachable,
        isTrue,
      );
    });

    test('its id is the one §11.6.2 names', () {
      expect(transportOver(const <LanPeer>[]).id, 'lan');
    });

    test('publish is a no-op — the exchange already delivered it', () async {
      // §11.6.5 step 7. Writing here would post the snapshot a second time.
      await expectLater(
        transportOver(const <LanPeer>[]).publish(local()),
        completes,
      );
    });

    test('an unreachable desktop reports the copy §11.6.4 specifies', () async {
      // Port 1 on loopback: nothing listens, and the connection is refused at
      // once rather than hanging.
      final LanSyncTransport transport = transportOver(<LanPeer>[
        peerAt('127.0.0.1', 1),
      ]);

      await expectLater(
        transport.fetchPeerSnapshots(local()),
        throwsA(
          isA<LanSyncFailure>().having(
            (LanSyncFailure f) => f.message,
            'message',
            'Open Zen on your PC to sync.',
          ),
        ),
      );
    });

    test(
      'a desktop that never answers times out rather than hanging',
      () async {
        // §11.6.4: the exchange "runs inside the orchestrator's single-flight
        // lock … a desktop that accepts a connection and then stops answering …
        // would otherwise hang the pass forever, and every later trigger would
        // join that dead future". A server that accepts and says nothing is
        // exactly that desktop.
        final ServerSocket silent = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final StreamSubscription<Socket> held = silent.listen((Socket _) {});
        addTearDown(() async {
          await held.cancel();
          await silent.close();
        });

        final LanClient client = LanClient(
          syncTimeout: const Duration(milliseconds: 300),
        );
        addTearDown(client.close);
        final LanSyncTransport transport = transportOver(<LanPeer>[
          peerAt('127.0.0.1', silent.port),
        ], client: client);

        await expectLater(
          transport.fetchPeerSnapshots(local()),
          throwsA(
            isA<LanSyncFailure>().having(
              (LanSyncFailure f) => f.message,
              'message',
              contains('did not answer in time'),
            ),
          ),
        );
      },
    );

    test('a peer with no usable address falls back to discovery', () async {
      // The manual-entry and mDNS paths meeting: a peer record whose host is
      // empty — which is what a desktop's own record looks like, and what a
      // phone holds if it was paired by a QR carrying an address that has since
      // changed — is found by discovery instead.
      final LanSyncTransport transport = transportOver(
        <LanPeer>[peerAt('', 0)],
        discovery: const _FixedDiscovery(<DiscoveredPeer>[
          DiscoveredPeer(
            replicaId: 'replica-desktop',
            deviceName: 'Jordan PC',
            host: '127.0.0.1',
            port: 1,
          ),
        ]),
      );

      // Port 1 refuses, so the observable fact is that discovery was consulted
      // and its address was the one dialled.
      await expectLater(
        transport.fetchPeerSnapshots(local()),
        throwsA(isA<LanSyncFailure>()),
      );
    });

    test('discovery throwing is not a failure', () async {
      final LanSyncTransport transport = transportOver(<LanPeer>[
        peerAt('', 0),
      ], discovery: const _ThrowingDiscovery());

      // No address anywhere: nothing was reached, and nothing blew up either.
      expect(await transport.fetchPeerSnapshots(local()), isEmpty);
    });

    test('with no peers it returns nothing rather than throwing', () async {
      expect(
        await transportOver(const <LanPeer>[]).fetchPeerSnapshots(local()),
        isEmpty,
      );
    });
  });
}

/// A [PeerDiscovery] that always reports the same services.
final class _FixedDiscovery implements PeerDiscovery {
  const _FixedDiscovery(this.peers);

  final List<DiscoveredPeer> peers;

  @override
  Future<List<DiscoveredPeer>> discover(Duration timeout) async => peers;
}

/// A [PeerDiscovery] standing in for a network that blocks multicast.
final class _ThrowingDiscovery implements PeerDiscovery {
  const _ThrowingDiscovery();

  @override
  Future<List<DiscoveredPeer>> discover(Duration timeout) async =>
      throw StateError('mDNS is unavailable on this network');
}

/// §11.6.3. The file transport: naming, the write protocol, the read rules and
/// the temp sweep.
///
/// Run against a real temporary directory through [IoSnapshotDirectory], which
/// §11.13.1 puts squarely in the headless column: "M6 merge, orchestrator,
/// backup, and the file transport against ordinary directories."
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zen_domain/zen_domain.dart';
import 'package:zen_sync/zen_sync.dart';

import '../support/fixtures.dart';

void main() {
  late Directory folder;
  late List<String> warnings;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('zen_file_transport');
    warnings = <String>[];
  });

  tearDown(() => folder.deleteSync(recursive: true));

  FileSnapshotTransport transportFor(String replicaId) => FileSnapshotTransport(
    directory: IoSnapshotDirectory(folder.path),
    replicaId: replicaId,
    log: warnings.add,
  );

  SnapshotEnvelope envelope(
    String replicaId, {
    List<Idea> ideas = const <Idea>[],
    DateTime? generatedAt,
  }) => SnapshotEnvelope(
    replicaId: replicaId,
    deviceName: 'device-$replicaId',
    generatedAt: generatedAt ?? t0,
    appVersion: '1.0.0',
    snapshot: snapshot(replicaId, ideas: ideas),
  );

  List<String> namesIn() =>
      folder
          .listSync()
          .map((FileSystemEntity e) => e.uri.pathSegments.last)
          .toList()
        ..sort();

  group('§11.6.3 publish', () {
    test('writes zen-snapshot-<replicaId>.json', () async {
      await transportFor('replica-a').publish(envelope('replica-a'));

      expect(namesIn(), <String>['zen-snapshot-replica-a.json']);
    });

    test('leaves no temp file behind', () async {
      await transportFor('replica-a').publish(
        envelope('replica-a', ideas: <Idea>[idea('idea-1', 'Learn Dart')]),
      );

      expect(
        namesIn().where((String n) => n.contains('zen-tmp-')),
        isEmpty,
        reason: 'the temp file is renamed onto the target, not left beside it',
      );
    });

    test('the published file is a readable snapshot', () async {
      await transportFor('replica-a').publish(
        envelope('replica-a', ideas: <Idea>[idea('idea-1', 'Learn Dart')]),
      );

      final SnapshotEnvelope decoded = const SnapshotCodec()
          .decode(
            File('${folder.path}/zen-snapshot-replica-a.json')
                .readAsStringSync(),
          )
          .unwrap();
      expect(decoded.snapshot.ideas.single.id, 'idea-1');
    });

    test('replaces the previous snapshot rather than accumulating', () async {
      final FileSnapshotTransport transport = transportFor('replica-a');
      await transport.publish(envelope('replica-a'));
      await transport.publish(
        envelope('replica-a', ideas: <Idea>[idea('idea-1', 'Learn Dart')]),
      );

      expect(namesIn(), <String>['zen-snapshot-replica-a.json']);
      final SnapshotEnvelope decoded = const SnapshotCodec()
          .decode(
            File('${folder.path}/zen-snapshot-replica-a.json')
                .readAsStringSync(),
          )
          .unwrap();
      expect(decoded.snapshot.ideas, hasLength(1));
    });
  });

  group('§11.6.5 step 7: skip the write when the content is unchanged', () {
    test('an identical dataset is not rewritten', () async {
      final FileSnapshotTransport transport = transportFor('replica-a');
      final List<Idea> ideas = <Idea>[idea('idea-1', 'Learn Dart')];

      await transport.publish(envelope('replica-a', ideas: ideas));
      final File file = File('${folder.path}/zen-snapshot-replica-a.json');
      final DateTime firstWrite = file.lastModifiedSync();
      final String firstContent = file.readAsStringSync();

      // A later `generatedAt`, the same dataset. "An unchanged dataset
      // republished every 15 minutes wakes Syncthing or a cloud drive with an
      // identical payload under a new timestamp for no reason."
      await transport.publish(
        envelope('replica-a', ideas: ideas, generatedAt: at(60)),
      );

      expect(file.readAsStringSync(), firstContent);
      expect(file.lastModifiedSync(), firstWrite);
    });

    test('a changed dataset is written', () async {
      final FileSnapshotTransport transport = transportFor('replica-a');
      await transport.publish(envelope('replica-a'));
      await transport.publish(
        envelope(
          'replica-a',
          ideas: <Idea>[idea('idea-1', 'Learn Dart')],
          generatedAt: at(60),
        ),
      );

      final SnapshotEnvelope decoded = const SnapshotCodec()
          .decode(
            File('${folder.path}/zen-snapshot-replica-a.json')
                .readAsStringSync(),
          )
          .unwrap();
      expect(decoded.snapshot.ideas, hasLength(1));
      expect(decoded.generatedAt, at(60));
    });

    test(
      'an unreadable existing file is overwritten rather than trusted',
      () async {
        File('${folder.path}/zen-snapshot-replica-a.json')
            .writeAsStringSync('{ corrupt');

        await transportFor('replica-a').publish(envelope('replica-a'));

        expect(
          const SnapshotCodec()
              .decode(
                File('${folder.path}/zen-snapshot-replica-a.json')
                    .readAsStringSync(),
              )
              .isOk,
          isTrue,
        );
      },
    );
  });

  group('§11.6.3 fetchPeerSnapshots', () {
    test(
      'reads a peer and skips our own, by the body not the filename',
      () async {
        await transportFor('replica-b').publish(envelope('replica-b'));
        await transportFor('replica-a').publish(envelope('replica-a'));

        final List<SnapshotEnvelope> peers = await transportFor('replica-a')
            .fetchPeerSnapshots();

        expect(peers.map((SnapshotEnvelope e) => e.replicaId), <String>[
          'replica-b',
        ]);
      },
    );

    test('the body is authoritative when the filename disagrees', () async {
      // "The two disagree whenever a file is copied or renamed by hand."
      final String body = const SnapshotCodec().encode(envelope('replica-b'));
      File('${folder.path}/zen-snapshot-replica-zzz.json')
          .writeAsStringSync(body);

      final List<SnapshotEnvelope> peers = await transportFor('replica-a')
          .fetchPeerSnapshots();

      expect(peers.single.replicaId, 'replica-b');
    });

    test(
      'our own snapshot under someone else\'s filename is still skipped',
      () async {
        final String body = const SnapshotCodec().encode(envelope('replica-a'));
        File('${folder.path}/zen-snapshot-replica-b.json')
            .writeAsStringSync(body);

        expect(await transportFor('replica-a').fetchPeerSnapshots(), isEmpty);
      },
    );

    test(
      'an unparseable file is skipped, logged, and does not abort the read',
      () async {
        await transportFor('replica-b').publish(envelope('replica-b'));
        File('${folder.path}/zen-snapshot-broken.json')
            .writeAsStringSync('{ nope');

        final List<SnapshotEnvelope> peers = await transportFor('replica-a')
            .fetchPeerSnapshots();

        expect(peers.map((SnapshotEnvelope e) => e.replicaId), <String>[
          'replica-b',
        ]);
        expect(warnings.single, contains('zen-snapshot-broken.json'));
      },
    );

    test(
      'a snapshot from a newer format is skipped with its message',
      () async {
        File('${folder.path}/zen-snapshot-replica-c.json').writeAsStringSync(
          const SnapshotCodec()
              .encode(envelope('replica-c'))
              .replaceFirst('"formatVersion": 1', '"formatVersion": 2'),
        );

        expect(await transportFor('replica-a').fetchPeerSnapshots(), isEmpty);
        expect(warnings.single, contains('newer version of Zen'));
      },
    );

    test(
      'files that are not snapshots are ignored without a warning',
      () async {
        File('${folder.path}/notes.txt').writeAsStringSync('hello');
        File('${folder.path}/zen-snapshot-replica-b.json.bak')
            .writeAsStringSync('x');

        expect(await transportFor('replica-a').fetchPeerSnapshots(), isEmpty);
        expect(warnings, isEmpty);
      },
    );

    test('an empty folder is not a failure', () async {
      expect(await transportFor('replica-a').fetchPeerSnapshots(), isEmpty);
      expect(warnings, isEmpty);
    });
  });

  group('§11.6.3 temp files', () {
    test('a temp name does not match the read glob', () async {
      // The reason the prefix is `zen-tmp-` and not `zen-snapshot-`: a peer
      // must never try to parse a file that is still being written.
      File('${folder.path}/zen-tmp-replica-b-0190f3a1.json')
          .writeAsStringSync('half a file');

      expect(await transportFor('replica-a').fetchPeerSnapshots(), isEmpty);
      expect(warnings, isEmpty);
    });

    test('publish sweeps this replica\'s own leftovers', () async {
      File('${folder.path}/zen-tmp-replica-a-0190f3a1.json')
          .writeAsStringSync('crashed mid-write');

      await transportFor('replica-a').publish(envelope('replica-a'));

      expect(namesIn(), <String>['zen-snapshot-replica-a.json']);
    });

    test('publish leaves another device\'s temp alone', () async {
      // "It MUST NOT delete another device's temps, which may be in flight."
      // Deleting one would turn a crash-cleanup into the data loss it exists to
      // prevent.
      File('${folder.path}/zen-tmp-replica-b-0190f3a1.json')
          .writeAsStringSync('in flight on the other device');

      await transportFor('replica-a').publish(envelope('replica-a'));

      expect(namesIn(), contains('zen-tmp-replica-b-0190f3a1.json'));
    });

    test('the sweep runs even when the write itself was skipped', () async {
      final FileSnapshotTransport transport = transportFor('replica-a');
      await transport.publish(envelope('replica-a'));
      File('${folder.path}/zen-tmp-replica-a-0190f3a1.json')
          .writeAsStringSync('crashed mid-write');

      await transport.publish(envelope('replica-a', generatedAt: at(60)));

      expect(namesIn(), <String>['zen-snapshot-replica-a.json']);
    });
  });

  group('§11.6.2 availability', () {
    test('a missing folder reports the wording §11.6.3 specifies', () async {
      final FileSnapshotTransport transport = FileSnapshotTransport(
        directory: IoSnapshotDirectory('${folder.path}/gone'),
        replicaId: 'replica-a',
      );

      final TransportAvailability availability = await transport.availability();
      expect(availability.reachable, isFalse);
      expect(availability.reason, 'Sync folder not available');
    });

    test('an existing folder is reachable', () async {
      expect(
        (await transportFor('replica-a').availability()).reachable,
        isTrue,
      );
    });

    test('the transport identifies itself as "file"', () {
      expect(transportFor('replica-a').id, 'file');
    });
  });
}

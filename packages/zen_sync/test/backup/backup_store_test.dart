/// §11.6.6. Pre-merge backups: the filename, the de-duplication and retention.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zen_domain/zen_domain.dart';
import 'package:zen_sync/zen_sync.dart';

import '../support/fixtures.dart';

void main() {
  late Directory root;
  late BackupStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('zen_backups');
    store = BackupStore(directoryPath: '${root.path}/backups');
  });

  tearDown(() => root.deleteSync(recursive: true));

  SnapshotEnvelope envelope({
    List<Idea> ideas = const <Idea>[],
    DateTime? generatedAt,
  }) => SnapshotEnvelope(
    replicaId: 'replica-a',
    deviceName: 'desktop',
    generatedAt: generatedAt ?? t0,
    appVersion: '1.0.0',
    snapshot: snapshot('replica-a', ideas: ideas),
  );

  group('§11.6.6 the file name', () {
    test('holds no character Windows forbids', () {
      final String name = BackupStore.fileNameFor(
        DateTime.utc(2026, 9, 24, 18, 30, 0, 0),
      );

      // "**Plain ISO-8601 is not a legal Windows filename**, because `:` is
      // forbidden there." The rest of the forbidden set is checked too, since
      // the timestamp is the only variable part of the name.
      expect(name, 'pre-merge-2026-09-24T18-30-00-000Z.json');
      for (final String forbidden in <String>[
        ':',
        '<',
        '>',
        '"',
        '/',
        r'\',
        '|',
        '?',
        '*',
      ]) {
        expect(name, isNot(contains(forbidden)));
      }
    });

    test('round-trips back to the instant it encodes', () {
      final DateTime instant = DateTime.utc(2026, 9, 24, 18, 30, 5, 123);
      expect(
        BackupStore.takenAtFromFileName(BackupStore.fileNameFor(instant)),
        instant,
      );
    });

    test('sorts lexicographically in chronological order', () {
      final List<String> names = <String>[
        BackupStore.fileNameFor(at(120)),
        BackupStore.fileNameFor(at(0)),
        BackupStore.fileNameFor(at(60)),
      ]..sort();

      expect(names, <String>[
        BackupStore.fileNameFor(at(0)),
        BackupStore.fileNameFor(at(60)),
        BackupStore.fileNameFor(at(120)),
      ]);
    });

    test('a name that is not a backup is not mistaken for one', () {
      for (final String name in <String>[
        'notes.txt',
        'pre-merge-.json',
        'pre-merge-2026-09-24.json',
        'zen-snapshot-replica-a.json',
        'pre-merge-not-a-timestamp-at-all-Z.json',
      ]) {
        expect(BackupStore.takenAtFromFileName(name), isNull, reason: name);
      }
    });
  });

  group('§11.6.5 step 4: writing', () {
    test('creates the directory and writes a readable snapshot', () async {
      final BackupEntry? entry = await store.writeIfChanged(
        envelope(ideas: <Idea>[idea('idea-1', 'Learn Dart')]),
      );

      expect(entry, isNotNull);
      expect((await store.read(entry!)).unwrap().snapshot.ideas, hasLength(1));
    });

    test('lists newest first', () async {
      await store.writeIfChanged(envelope(generatedAt: at(0)));
      await store.writeIfChanged(
        envelope(
          ideas: <Idea>[idea('idea-1', 'Learn Dart')],
          generatedAt: at(60),
        ),
      );

      expect((await store.list()).map((BackupEntry e) => e.takenAt), <DateTime>[
        at(60),
        at(0),
      ]);
    });
  });

  group('§11.6.6 de-duplication', () {
    test('an unchanged dataset is not backed up again', () async {
      // Without this "the whole history spans about five hours — so a merge bug
      // noticed the next morning has no clean backup left, which is exactly the
      // failure this file exists to insure against."
      final List<Idea> ideas = <Idea>[idea('idea-1', 'Learn Dart')];
      await store.writeIfChanged(envelope(ideas: ideas, generatedAt: at(0)));

      final BackupEntry? second = await store.writeIfChanged(
        envelope(ideas: ideas, generatedAt: at(15)),
      );

      expect(second, isNull);
      expect(await store.list(), hasLength(1));
    });

    test('a changed dataset is backed up', () async {
      await store.writeIfChanged(envelope(generatedAt: at(0)));

      final BackupEntry? second = await store.writeIfChanged(
        envelope(
          ideas: <Idea>[idea('idea-1', 'Learn Dart')],
          generatedAt: at(15),
        ),
      );

      expect(second, isNotNull);
      expect(await store.list(), hasLength(2));
    });

    test('only the newest backup is compared against', () async {
      // Returning to an earlier state is a real change and must be recorded.
      final List<Idea> ideas = <Idea>[idea('idea-1', 'Learn Dart')];
      await store.writeIfChanged(envelope(ideas: ideas, generatedAt: at(0)));
      await store.writeIfChanged(envelope(generatedAt: at(15)));

      expect(
        await store.writeIfChanged(envelope(ideas: ideas, generatedAt: at(30))),
        isNotNull,
      );
      expect(await store.list(), hasLength(3));
    });
  });

  group('§11.6.6 retention', () {
    test('keeps the newest twenty and deletes the rest', () async {
      // Each write carries a distinct dataset, so none is de-duplicated away.
      for (int i = 0; i < 25; i++) {
        await store.writeIfChanged(
          envelope(
            ideas: <Idea>[idea('idea-$i', 'Idea number $i')],
            generatedAt: at(i),
          ),
        );
      }

      final List<BackupEntry> kept = await store.list();
      expect(kept, hasLength(BackupStore.retained));
      expect(kept.first.takenAt, at(24));
      expect(kept.last.takenAt, at(5));
    });

    test('files that are not backups are left alone', () async {
      Directory('${root.path}/backups').createSync(recursive: true);
      File('${root.path}/backups/notes.txt').writeAsStringSync('mine');

      await store.writeIfChanged(envelope());

      expect(File('${root.path}/backups/notes.txt').existsSync(), isTrue);
      expect(await store.list(), hasLength(1));
    });
  });

  group('§11.6.6 reading', () {
    test(
      'a corrupted backup reports rather than restoring part of itself',
      () async {
        final BackupEntry? entry = await store.writeIfChanged(envelope());
        File('${root.path}/backups/${entry!.fileName}')
            .writeAsStringSync('{ corrupt');

        expect((await store.read(entry)).errorOrNull, isA<SnapshotNotJson>());
      },
    );

    test('a missing backup reports rather than throwing', () async {
      final Result<SnapshotEnvelope, SnapshotFormatFailure> result = await store
          .read(BackupEntry(fileName: 'pre-merge-gone.json', takenAt: t0));

      expect(result.isErr, isTrue);
    });

    test('listing an absent directory is empty, not an error', () async {
      expect(await store.list(), isEmpty);
    });
  });
}

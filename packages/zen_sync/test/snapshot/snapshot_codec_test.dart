/// §11.6.1. The snapshot format: what it carries, what it refuses, and what it
/// deliberately leaves out.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zen_domain/zen_domain.dart';
import 'package:zen_sync/zen_sync.dart';

import '../support/fixtures.dart';

void main() {
  const SnapshotCodec codec = SnapshotCodec();

  SnapshotEnvelope envelopeOf(ReplicaSnapshot data) => SnapshotEnvelope(
    replicaId: data.replicaId,
    deviceName: 'desktop',
    generatedAt: t0,
    appVersion: '1.0.0',
    snapshot: data,
  );

  /// The full document, so a test can corrupt one field of an otherwise valid
  /// snapshot rather than asserting against a hand-built fragment.
  ///
  /// Taken back through `jsonDecode` rather than straight from `toJson`, for
  /// two reasons: the encoder emits fixed-length lists, which a corruption
  /// cannot append to, and going through the text exercises the path a peer
  /// file actually takes.
  Map<String, Object?> validDocument() => jsonDecode(
    codec.encode(
      envelopeOf(
        snapshot(
          'replica-a',
          ideas: <Idea>[
            idea('idea-1', 'Learn Dart', tags: <String>['work', 'study']),
          ],
          tasks: <Task>[
            task(
              'task-1',
              'Write report',
              subtasks: <Subtask>[
                subtask('sub-1', 'Draft', status: TaskStatus.done),
                subtask('sub-2', 'Proofread'),
              ],
            ),
          ],
          tombstones: <IdeaTombstone>[tombstone('idea-9')],
        ),
      ),
    ),
  ) as Map<String, Object?>;

  group('§11.6.1 round trip', () {
    test('a snapshot survives encoding and decoding field for field', () {
      final SnapshotEnvelope original = envelopeOf(
        snapshot(
          'replica-a',
          ideas: <Idea>[
            idea(
              'idea-1',
              'Learn Dart',
              timeframe: Timeframe.soon,
              tags: <String>['work'],
              context: 'line one\nline two',
              createdAt: at(0),
              updatedAt: at(5),
            ),
          ],
          tasks: <Task>[
            task(
              'task-1',
              'Write report',
              status: TaskStatus.done,
              tags: <String>['work', 'urgent'],
              description: 'the quarterly one',
              subtasks: <Subtask>[
                subtask('sub-1', 'Draft', status: TaskStatus.done),
                subtask('sub-2', 'Proofread', status: TaskStatus.done),
              ],
              completedAt: at(9),
              isArchived: true,
              archivedAt: at(10),
              sourceIdeaId: 'idea-7',
              sourceIdeaCreatedAt: at(-60),
            ),
            task('task-2', 'Deleted one', isDeleted: true, deletedAt: at(3)),
          ],
          tombstones: <IdeaTombstone>[
            tombstone(
              'idea-8',
              reason: TombstoneReason.converted,
              deletedAt: at(1),
            ),
            tombstone('idea-9'),
          ],
        ),
      );

      expect(codec.decode(codec.encode(original)).unwrap(), original);
    });

    test('MERGE-3A: subtask order is the array order and is preserved', () {
      final SnapshotEnvelope original = envelopeOf(
        snapshot(
          'replica-a',
          tasks: <Task>[
            task(
              'task-1',
              'Stretch',
              subtasks: <Subtask>[
                subtask('sub-3', 'Third'),
                subtask('sub-1', 'First'),
                subtask('sub-2', 'Second'),
              ],
            ),
          ],
        ),
      );

      final Task decoded = codec
          .decode(codec.encode(original))
          .unwrap()
          .snapshot
          .tasks
          .single;
      expect(decoded.subtasks.map((Subtask s) => s.id), <String>[
        'sub-3',
        'sub-1',
        'sub-2',
      ], reason: 'subtask order is user-controlled and visible (MERGE-3A)');
    });

    test('§9.3 step 8: equal datasets encode to equal bytes', () {
      // What §11.6.5 step 7's "skip the write when the content is unchanged"
      // rests on, and what makes the comparison cheap.
      final ReplicaSnapshot data = snapshot(
        'replica-a',
        ideas: <Idea>[idea('idea-1', 'Learn Dart')],
      );
      expect(codec.encode(envelopeOf(data)), codec.encode(envelopeOf(data)));
    });

    test('§3, INV-9: a peer\'s finer precision is truncated on the way in', () {
      final Map<String, Object?> document = validDocument();
      (document['ideas']! as List<Object?>).clear();
      (document['ideas']! as List<Object?>).add(<String, Object?>{
        'id': 'idea-1',
        'name': 'Learn Dart',
        'nameNormalized': 'learn dart',
        'tags': <String>[],
        'context': '',
        'timeframe': 'now',
        'createdAt': '2026-09-24T18:30:00.123456Z',
        'updatedAt': '2026-09-24T18:30:00.123456Z',
      });

      final Idea decoded = codec
          .fromJson(document)
          .unwrap()
          .snapshot
          .ideas
          .single;
      expect(decoded.createdAt.microsecond, 0);
      expect(decoded.createdAt.millisecond, 123);
      expect(decoded.invariantFailures, isEmpty, reason: 'INV-9');
    });
  });

  group('MERGE-3: settings and events never travel', () {
    test('the encoded document holds no settings key and no events', () {
      final Map<String, Object?> document = validDocument();

      // Named rather than counted, because the harm is specific: "Settings are
      // per replica and never merged (MERGE-3). A snapshot that carries them is
      // a bug that will quietly overwrite the other device's preferences."
      expect(document.keys, <String>[
        'formatVersion',
        'replicaId',
        'deviceName',
        'generatedAt',
        'appVersion',
        'ideas',
        'tasks',
        'tombstones',
      ]);

      final String encoded = jsonEncode(document);
      for (final String forbidden in <String>[
        'endOfDay',
        'theme',
        'decor',
        'strikethroughDone',
        'confirmDestructive',
        'defaultIdeaTimeframe',
        'expandedIdeaGroups',
        'syncFolderLocation',
        'syncLanPeers',
        'psk',
        'lastSyncAt',
        'events',
      ]) {
        expect(
          encoded,
          isNot(contains(forbidden)),
          reason: 'MERGE-3: "$forbidden" must never travel in a snapshot',
        );
      }
    });
  });

  group('§11.6.1 formatVersion', () {
    test('a higher version is refused rather than parsed optimistically', () {
      final Map<String, Object?> document = validDocument()
        ..['formatVersion'] = 2;

      final SnapshotFormatFailure failure = codec
          .fromJson(document)
          .errorOrNull!;
      expect(failure, isA<SnapshotVersionUnsupported>());
      expect(failure.message, contains('newer version of Zen'));
    });

    test('a lower version says something different from a higher one', () {
      final Map<String, Object?> document = validDocument()
        ..['formatVersion'] = 0;

      expect(
        codec.fromJson(document).errorOrNull!.message,
        contains('old format'),
      );
    });

    test('the version is checked before any record is read', () {
      // A future format may reshape `tasks` entirely. Reading it first would
      // report a field error for a file whose real problem is its version.
      final Map<String, Object?> document = validDocument()
        ..['formatVersion'] = 2
        ..['tasks'] = 'not even an array';

      expect(
        codec.fromJson(document).errorOrNull,
        isA<SnapshotVersionUnsupported>(),
      );
    });
  });

  group('§11.6.1 a peer snapshot is all-or-nothing', () {
    test('bytes that are not JSON are refused', () {
      expect(codec.decode('{ not json').errorOrNull, isA<SnapshotNotJson>());
    });

    /// Each of these corrupts exactly one value in an otherwise valid document.
    /// Every one must refuse the **whole** file: "Dropping the one bad record
    /// instead would be the quieter failure and therefore the worse one."
    final Map<String, void Function(Map<String, Object?>)> corruptions =
        <String, void Function(Map<String, Object?>)>{
          'an unrecognised task status': (Map<String, Object?> d) =>
              (d['tasks']! as List<Object?>).first as Map<String, Object?>
                ..['status'] = 'abandoned',
          'an unrecognised timeframe': (Map<String, Object?> d) =>
              (d['ideas']! as List<Object?>).first as Map<String, Object?>
                ..['timeframe'] = 'eventually',
          'an unrecognised tombstone reason': (Map<String, Object?> d) =>
              (d['tombstones']! as List<Object?>).first as Map<String, Object?>
                ..['reason'] = 'vanished',
          'a name NAME-2 rejects': (Map<String, Object?> d) =>
              (d['ideas']! as List<Object?>).first as Map<String, Object?>
                ..['name'] = 'ab',
          'a name NAME-4 rejects': (Map<String, Object?> d) =>
              (d['tasks']! as List<Object?>).first as Map<String, Object?>
                ..['name'] = 'two\nlines',
          'a tag TAG-2 rejects': (Map<String, Object?> d) =>
              (d['ideas']! as List<Object?>).first as Map<String, Object?>
                ..['tags'] = <String>['two words'],
          'a missing field': (Map<String, Object?> d) =>
              (d['tasks']! as List<Object?>).first as Map<String, Object?>
                ..remove('createdAt'),
          'a field of the wrong type': (Map<String, Object?> d) =>
              (d['tasks']! as List<Object?>).first as Map<String, Object?>
                ..['isArchived'] = 'yes',
          'a timestamp that is not ISO-8601': (Map<String, Object?> d) =>
              (d['ideas']! as List<Object?>).first as Map<String, Object?>
                ..['createdAt'] = 'yesterday',
          'a timestamp with no time zone': (Map<String, Object?> d) =>
              (d['ideas']! as List<Object?>).first as Map<String, Object?>
                ..['createdAt'] = '2026-09-24T18:30:00.000',
          'INV-1: Done with no completedAt': (Map<String, Object?> d) =>
              (d['tasks']! as List<Object?>).first as Map<String, Object?>
                ..['status'] = 'done'
                ..['completedAt'] = null,
          'INV-4: archived with no archivedAt': (Map<String, Object?> d) =>
              (d['tasks']! as List<Object?>).first as Map<String, Object?>
                ..['isArchived'] = true
                ..['archivedAt'] = null,
          'INV-5: createdAt after updatedAt': (Map<String, Object?> d) =>
              (d['ideas']! as List<Object?>).first as Map<String, Object?>
                ..['createdAt'] = '2099-01-01T00:00:00.000Z',
          'INV-8: a sourceIdeaId with no sourceIdeaCreatedAt':
              (Map<String, Object?> d) =>
                  (d['tasks']! as List<Object?>).first as Map<String, Object?>
                    ..['sourceIdeaId'] = 'idea-7',
          'a subtask INV-1 rejects': (Map<String, Object?> d) =>
              ((d['tasks']! as List<Object?>).first
                        as Map<String, Object?>)['subtasks']!
                    as List<Object?>
                ..[1] = <String, Object?>{
                  'id': 'sub-2',
                  'name': 'Proofread',
                  'status': 'todo',
                  'createdAt': '2026-09-24T18:30:00.000Z',
                  'updatedAt': '2026-09-24T18:30:00.000Z',
                  'completedAt': '2026-09-24T18:30:00.000Z',
                },
        };

    corruptions.forEach((
      String description,
      void Function(Map<String, Object?>) corrupt,
    ) {
      test('$description refuses the whole file', () {
        final Map<String, Object?> document = validDocument();
        corrupt(document);

        final Result<SnapshotEnvelope, SnapshotFormatFailure> result = codec
            .fromJson(document);
        expect(result.isErr, isTrue, reason: description);
        expect(result.errorOrNull, isA<SnapshotFieldInvalid>());
      });
    });

    test('the refusal names where the problem is', () {
      final Map<String, Object?> document = validDocument();
      (((document['tasks']! as List<Object?>).first
              as Map<String, Object?>)['subtasks']!
          as List<Object?>)[1] = <String, Object?>{
        'id': 'sub-2',
      };

      final SnapshotFieldInvalid failure =
          codec.fromJson(document).errorOrNull! as SnapshotFieldInvalid;
      expect(failure.path, 'tasks[0].subtasks[1].name');
    });

    test('INV-6: two active Ideas sharing a name refuse the file', () {
      // A replica's own database cannot produce this — the partial unique index
      // of §11.5.2 forbids it — so a snapshot that does is corrupt. It is *not*
      // the case the merge exists to handle: that one is two replicas each
      // internally consistent but disagreeing with each other.
      final Map<String, Object?> document = validDocument();
      (document['ideas']! as List<Object?>).add(<String, Object?>{
        'id': 'idea-2',
        'name': 'LEARN DART',
        'nameNormalized': 'learn dart',
        'tags': <String>[],
        'context': '',
        'timeframe': 'now',
        'createdAt': '2026-09-24T18:30:00.000Z',
        'updatedAt': '2026-09-24T18:30:00.000Z',
      });

      expect(codec.fromJson(document).errorOrNull, isA<SnapshotFieldInvalid>());
    });

    test('INV-7: an Idea that is also tombstoned refuses the file', () {
      final Map<String, Object?> document = validDocument();
      (document['tombstones']! as List<Object?>).add(<String, Object?>{
        'id': 'idea-1',
        'deletedAt': '2026-09-24T18:30:00.000Z',
        'reason': 'deleted',
      });

      expect(codec.fromJson(document).errorOrNull, isA<SnapshotFieldInvalid>());
    });
  });

  group('§11.6.1 nameNormalized is written but never read back', () {
    test('it is present in the document', () {
      final Map<String, Object?> encoded =
          (validDocument()['ideas']! as List<Object?>).first
              as Map<String, Object?>;
      expect(encoded['nameNormalized'], 'learn dart');
    });

    test('a disagreeing value is warned about and the local form is used', () {
      final List<String> warnings = <String>[];
      final SnapshotCodec logging = SnapshotCodec(log: warnings.add);

      final Map<String, Object?> document = validDocument();
      ((document['ideas']! as List<Object?>).first
              as Map<String, Object?>)['nameNormalized'] =
          'something else';

      final Idea decoded = logging
          .fromJson(document)
          .unwrap()
          .snapshot
          .ideas
          .single;

      // Honouring the peer's value "would let two replicas compute *different*
      // merges from the same inputs whenever their normalization disagreed,
      // breaking MERGE-2".
      expect(decoded.name.normalized, 'learn dart');
      expect(warnings.single, contains('nameNormalized'));
      expect(warnings.single, contains('MERGE-5'));
    });

    test('an agreeing value is not warned about', () {
      final List<String> warnings = <String>[];
      SnapshotCodec(log: warnings.add).fromJson(validDocument());
      expect(warnings, isEmpty);
    });
  });
}

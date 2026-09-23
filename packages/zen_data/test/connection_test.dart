/// §11.5.5. Opening the database, and what happens when it will not open.
///
/// "Do not crash to a blank screen and do not silently create an empty database
/// over the top, which would present as total data loss." Those two failures
/// are the ones worth a test: a corrupt file must be *reported*, and it must
/// still be on disk afterwards.
library;

import 'dart:io';

// `isNotNull` is a matcher here, not drift's SQL expression builder.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_data/zen_data.dart';

import 'support/harness.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('zen_data_test');
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  String path(String name) => '${dir.path}${Platform.pathSeparator}$name';

  group('§11.5.5: opening', () {
    test('a new file opens and the schema is created', () async {
      final OpenOutcome outcome = await openDatabase(
        path: path('zen.sqlite'),
        nowUtc: base,
      );

      expect(outcome, isA<DatabaseOpened>());
      final AppDatabase db = (outcome as DatabaseOpened).database;
      addTearDown(db.close);

      expect(await db.select(db.ideas).get(), isEmpty);
    });

    test('§11.5.5: WAL is on for a file-backed database', () async {
      final DatabaseOpened outcome = await openDatabase(
        path: path('zen.sqlite'),
        nowUtc: base,
      ) as DatabaseOpened;
      addTearDown(outcome.database.close);

      final QueryRow row = await outcome.database
          .customSelect('PRAGMA journal_mode')
          .getSingle();
      expect(row.data.values.first, 'wal');
    });

    test('data written survives a close and reopen', () async {
      final DatabaseOpened first = await openDatabase(
        path: path('zen.sqlite'),
        nowUtc: base,
      ) as DatabaseOpened;
      await insertIdeaRow(first.database);
      await first.database.close();

      final DatabaseOpened second = await openDatabase(
        path: path('zen.sqlite'),
        nowUtc: base,
      ) as DatabaseOpened;
      addTearDown(second.database.close);

      expect(
        await second.database.select(second.database.ideas).get(),
        hasLength(1),
      );
    });
  });

  group('§11.5.5: a file that cannot be read', () {
    test('is reported rather than thrown, and is not destroyed', () async {
      final File corrupt = File(path('zen.sqlite'))
        ..writeAsBytesSync(List<int>.filled(4096, 0x5a));

      final OpenOutcome outcome = await openDatabase(
        path: corrupt.path,
        nowUtc: base,
      );

      expect(outcome, isA<DatabaseUnreadable>());
      final DatabaseUnreadable failure = outcome as DatabaseUnreadable;
      expect(failure.originalPath, corrupt.path);
      expect(failure.cause, isNotNull);

      // "Keep the unreadable file in place, renamed with a timestamp, so
      // nothing is destroyed."
      expect(failure.quarantinedPath, isNotNull);
      expect(File(failure.quarantinedPath!).existsSync(), isTrue);
      expect(
        File(failure.quarantinedPath!).lengthSync(),
        4096,
        reason: 'byte for byte, so a later version can still try',
      );
    });

    test(
      'the quarantine name is derived from the instant it is given',
      () async {
        File(path('zen.sqlite')).writeAsBytesSync(List<int>.filled(4096, 0x5a));

        final DatabaseUnreadable failure = await openDatabase(
          path: path('zen.sqlite'),
          nowUtc: base,
        ) as DatabaseUnreadable;

        expect(
          failure.quarantinedPath,
          endsWith('.unreadable-2026-09-22T12-00-00-000Z'),
          reason: '§11.11: the instant is passed in, never read from a clock',
        );
      },
    );

    test(
      'nothing is left at the original path for a reopen to overwrite',
      () async {
        // The dangerous alternative is opening again and silently creating an
        // empty database over the top, which presents as total data loss.
        File(path('zen.sqlite')).writeAsBytesSync(List<int>.filled(4096, 0x5a));

        await openDatabase(path: path('zen.sqlite'), nowUtc: base);

        expect(File(path('zen.sqlite')).existsSync(), isFalse);
        expect(
          dir.listSync().whereType<File>().length,
          1,
          reason: 'the data is still there, under its quarantine name',
        );
      },
    );
  });
}

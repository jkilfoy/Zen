/// §9.3 step 4. The field-resolution rules, tested directly rather than only
/// through the strategy.
///
/// These three — the primary record, the tag union and the longest text — carry
/// the tie-breaks §9.3 spells out most carefully, so they get their own tests
/// where the inputs are visible on one screen.
library;

import 'package:test/test.dart';
import 'package:zen_domain/zen_domain.dart';

import '../support/fixtures.dart';

/// Reads the primary index out of [records], which must already be in record
/// order, for the chosen [id].
int primaryOf(List<Task> records, String id) => primaryRecordIndex<Task>(
  records,
  id: id,
  idOf: (Task t) => t.id,
  updatedAtOf: (Task t) => t.updatedAt,
  normalizedNameOf: (Task t) => t.name.normalized,
);

void main() {
  group('§9.3 step 4: the primary record', () {
    test('only records carrying the chosen id are candidates', () {
      // The record with the latest updatedAt does not carry the chosen id, so
      // it cannot be the primary however recent it is.
      final List<Task> records = <Task>[
        aTask(id: 'aaa', named: 'Chosen id', updatedAt: at(1)),
        aTask(id: 'zzz', named: 'Other id', updatedAt: at(99)),
      ];

      expect(primaryOf(records, 'aaa'), 0);
    });

    test('the latest updatedAt wins among them', () {
      final List<Task> records = <Task>[
        aTask(id: 'aaa', named: 'Older name', updatedAt: at(1)),
        aTask(id: 'aaa', named: 'Newer name', updatedAt: at(2)),
      ];

      expect(primaryOf(records, 'aaa'), 1);
    });

    test('on a tie the normalized name sorting first wins', () {
      final List<Task> records = <Task>[
        aTask(id: 'aaa', named: 'Zulu task', updatedAt: at(5)),
        aTask(id: 'aaa', named: 'Alpha task', updatedAt: at(5)),
      ];

      expect(primaryOf(records, 'aaa'), 1);
    });

    test('on a further tie the first in record order wins', () {
      // Identical updatedAt and identical normalized name: record order has
      // already placed them, so the earlier index holds.
      final List<Task> records = <Task>[
        aTask(id: 'aaa', named: 'ALPHA task', updatedAt: at(5)),
        aTask(id: 'aaa', named: 'alpha task', updatedAt: at(5)),
      ];

      expect(primaryOf(records, 'aaa'), 0);
    });
  });

  group('§9.3 step 4: the tag union', () {
    test('the primary record first, then the rest, de-duplicated', () {
      final List<Tag> merged = unionTags(<List<Tag>>[
        <Tag>[tag('first'), tag('shared')],
        <Tag>[tag('SHARED'), tag('second')],
        <Tag>[tag('third')],
      ], 1);

      expect(merged.map((Tag t) => t.value), <String>[
        'SHARED',
        'second',
        'first',
        'third',
      ]);
    });

    test('TAG-4: de-duplication is case-insensitive and keeps the first', () {
      final List<Tag> merged = unionTags(<List<Tag>>[
        <Tag>[tag('Work')],
        <Tag>[tag('WORK'), tag('work')],
      ], 0);

      expect(merged.map((Tag t) => t.value), <String>['Work']);
    });
  });

  group('§9.3 step 4: the longest text', () {
    ItemText textOf(String raw) => context(raw);

    test('the longest wins outright', () {
      expect(
        longestText(
          <ItemText>[textOf('short'), textOf('much longer text')],
          <DateTime>[at(99), at(1)],
          0,
        ).value,
        'much longer text',
      );
    });

    test('tied on length, the latest updatedAt wins', () {
      expect(
        longestText(
          <ItemText>[textOf('aaaa'), textOf('bbbb')],
          <DateTime>[at(1), at(2)],
          0,
        ).value,
        'bbbb',
      );
    });

    test('tied again, the primary wins when its text is among the tied', () {
      expect(
        longestText(
          <ItemText>[textOf('aaaa'), textOf('bbbb')],
          <DateTime>[at(5), at(5)],
          1,
        ).value,
        'bbbb',
      );
    });

    test('a primary whose text is not tied-longest has already lost', () {
      // "Ties, in order": length first. The primary's text is shorter, so it
      // never reaches the round where the primary is consulted.
      expect(
        longestText(
          <ItemText>[textOf('short'), textOf('much longer text')],
          <DateTime>[at(5), at(5)],
          0,
        ).value,
        'much longer text',
      );
    });

    test('a stale primary loses the updatedAt round before being asked', () {
      expect(
        longestText(
          <ItemText>[textOf('aaaa'), textOf('bbbb')],
          <DateTime>[at(1), at(2)],
          0,
        ).value,
        'bbbb',
      );
    });
  });

  group('§9.3 step 4: the small reducers', () {
    test('the most urgent timeframe and the highest-precedence status', () {
      expect(
        mostUrgentTimeframe(const <Timeframe>[
          Timeframe.distant,
          Timeframe.soon,
          Timeframe.later,
        ]),
        Timeframe.soon,
      );
      expect(
        highestPrecedenceStatus(const <TaskStatus>[
          TaskStatus.todo,
          TaskStatus.blocked,
        ]),
        TaskStatus.blocked,
      );
      expect(
        highestPrecedenceStatus(const <TaskStatus>[
          TaskStatus.todo,
          TaskStatus.done,
          TaskStatus.blocked,
        ]),
        TaskStatus.done,
      );
    });

    test('smallestId, earliestInstant and latestInstant', () {
      expect(smallestId(const <String>['zzz', 'aaa', 'mmm']), 'aaa');
      expect(earliestInstant(<DateTime>[at(5), at(1), at(9)]), at(1));
      expect(latestInstant(<DateTime>[at(5), at(1), at(9)]), at(9));
    });

    test('earliestNonNull ignores nulls and returns null when all are', () {
      expect(earliestNonNull(<DateTime?>[null, at(5), null, at(2)]), at(2));
      expect(earliestNonNull(const <DateTime?>[null, null]), isNull);
      expect(earliestNonNull(const <DateTime?>[]), isNull);
    });
  });

  group('§9.3: the record-order comparison helpers', () {
    test('nulls and false sort first', () {
      expect(compareNullableInstants(null, at(1)), isNegative);
      expect(compareNullableInstants(at(1), null), isPositive);
      expect(compareNullableInstants(null, null), 0);
      expect(compareNullableStrings(null, 'a'), isNegative);
      expect(compareNullableStrings('a', null), isPositive);
      expect(compareFlags(false, true), isNegative);
      expect(compareFlags(true, true), 0);
    });
  });
}

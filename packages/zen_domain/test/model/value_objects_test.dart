import 'package:test/test.dart';
import 'package:zen_domain/zen_domain.dart';

void main() {
  group('§3.1 ItemName', () {
    test('NAME-1: a name is trimmed before validation and storage', () {
      expect(ItemName.parse('   Buy milk   ').unwrap().value, 'Buy milk');
    });

    test('NAME-1: a name that is only whitespace is too short, not empty', () {
      expect(ItemName.parse('     ').errorOrNull, const NameTooShort());
    });

    test('NAME-2: fewer than 3 characters is rejected', () {
      expect(ItemName.parse('ab').errorOrNull, const NameTooShort());
      expect(
        ItemName.parse('ab').errorOrNull!.message,
        'Name must be at least 3 characters.',
      );
    });

    test('NAME-2: exactly 3 characters is accepted', () {
      expect(ItemName.parse('abc').isOk, isTrue);
    });

    test('NAME-2: length counts grapheme clusters, not code units', () {
      // A family emoji is one user-perceived character but many code units.
      // Counting code units would wrongly accept it as a 3-character name.
      expect(ItemName.parse('\u{1F468}‍\u{1F469}‍\u{1F467}').isOk, isFalse);
      // Three flag emoji are three user-perceived characters.
      expect(ItemName.parse('\u{1F1E8}\u{1F1E6}' * 3).isOk, isTrue);
    });

    test('NAME-3: more than 1000 characters is rejected', () {
      expect(ItemName.parse('a' * 1001).errorOrNull, const NameTooLong());
      expect(
        ItemName.parse('a' * 1001).errorOrNull!.message,
        'Name must be 1000 characters or fewer.',
      );
    });

    test('NAME-3: exactly 1000 characters is accepted', () {
      expect(ItemName.parse('a' * 1000).isOk, isTrue);
    });

    test('NAME-4: a name containing a line break is rejected', () {
      expect(
        ItemName.parse('two\nlines').errorOrNull,
        const NameContainsLineBreak(),
      );
      expect(
        ItemName.parse('two\r\nlines').errorOrNull,
        const NameContainsLineBreak(),
      );
    });

    test('NAME-5: names compare by normalized form', () {
      // AC-8's exact pair: differing case and a doubled internal space.
      expect(
        ItemName.parse('Buy milk').unwrap(),
        ItemName.parse('buy  MILK').unwrap(),
      );
    });

    test(
      'NAME-5: normalization trims, collapses whitespace and case-folds',
      () {
        expect(
          ItemName.parse('  Read   SICP  ').unwrap().normalized,
          'read sicp',
        );
      },
    );

    test('NAME-5: a name keeps the case and spacing the user typed', () {
      final ItemName parsed = ItemName.parse('Read   SICP').unwrap();
      expect(parsed.value, 'Read   SICP');
      expect(parsed.normalized, 'read sicp');
    });

    test('NAME-5: equal names hash equally', () {
      expect(
        ItemName.parse('Buy milk').unwrap().hashCode,
        ItemName.parse('buy  MILK').unwrap().hashCode,
      );
    });
  });

  group('§3.4 SubtaskName', () {
    test('a subtask name is trimmed', () {
      expect(SubtaskName.parse('  Pack  ').unwrap().value, 'Pack');
    });

    test('1 character is accepted: NAME-2 does not apply to subtasks', () {
      expect(SubtaskName.parse('a').isOk, isTrue);
    });

    test('an empty subtask name is rejected', () {
      expect(SubtaskName.parse('   ').errorOrNull, const SubtaskNameEmpty());
    });

    test('more than 1000 characters is rejected', () {
      expect(
        SubtaskName.parse('a' * 1001).errorOrNull,
        const SubtaskNameTooLong(),
      );
    });

    test('a line break is rejected', () {
      expect(
        SubtaskName.parse('a\nb').errorOrNull,
        const SubtaskNameContainsLineBreak(),
      );
    });

    test(
      'NAME-11: two subtask names that differ only in case are not equal',
      () {
        // Unlike ItemName: subtask names are not subject to uniqueness, so
        // equality is over the literal value.
        expect(
          SubtaskName.parse('Pack').unwrap() ==
              SubtaskName.parse('pack').unwrap(),
          isFalse,
        );
        // The normalized form is still available for merge matching (§9.3 step 5).
        expect(
          SubtaskName.parse('Pack').unwrap().normalized,
          SubtaskName.parse('pack').unwrap().normalized,
        );
      },
    );
  });

  group('§3.5 Tag', () {
    test('TAG-1: a leading @ is stripped', () {
      expect(Tag.parse('@work').unwrap().value, 'work');
      expect(Tag.parse('work').unwrap().value, 'work');
    });

    test('TAG-1: only one leading @ is stripped', () {
      expect(Tag.parse('@@work').unwrap().value, '@work');
    });

    test('TAG-2: a tag is trimmed', () {
      expect(Tag.parse('  work  ').unwrap().value, 'work');
    });

    test('TAG-2: internal whitespace is rejected', () {
      expect(Tag.parse('two words').errorOrNull, const TagContainsWhitespace());
      expect(
        Tag.parse('two words').errorOrNull!.message,
        'Tags cannot contain spaces.',
      );
    });

    test('TAG-2: any non-whitespace character is allowed', () {
      for (final String raw in <String>['c++', 'a/b', '#1', 'é', '🎯']) {
        expect(Tag.parse(raw).isOk, isTrue, reason: raw);
      }
    });

    test('TAG-3: 1 to 32 characters', () {
      expect(Tag.parse('a').isOk, isTrue);
      expect(Tag.parse('a' * 32).isOk, isTrue);
      expect(Tag.parse('a' * 33).errorOrNull, const TagTooLong());
    });

    test('TAG-3: an empty tag is refused silently', () {
      final RuleViolation violation = Tag.parse('@').errorOrNull!;
      expect(violation, const TagEmpty());
      expect(violation.hasMessage, isFalse);
    });

    test('TAG-4: tags compare case-insensitively', () {
      expect(Tag.parse('CS').unwrap(), Tag.parse('cs').unwrap());
    });

    test('TAG-4: tags keep the case the user typed', () {
      expect(Tag.parse('CS').unwrap().value, 'CS');
    });

    test(
      'TAG-4: adding a duplicate tag is a no-op, keeping the first case',
      () {
        final List<Tag> deduped = dedupeTags(<Tag>[
          Tag.parse('CS').unwrap(),
          Tag.parse('books').unwrap(),
          Tag.parse('cs').unwrap(),
        ]);
        expect(deduped.map((Tag t) => t.value), <String>['CS', 'books']);
      },
    );

    test('TAG-5: tags display with a leading @', () {
      expect(Tag.parse('work').unwrap().display, '@work');
    });
  });

  group('§3.2, §3.3 ItemText', () {
    test('10,000 characters is accepted', () {
      expect(ItemText.parseContext('a' * 10000).isOk, isTrue);
    });

    test('context over 10,000 characters is rejected', () {
      expect(
        ItemText.parseContext('a' * 10001).errorOrNull,
        const ContextTooLong(),
      );
    });

    test(
      'description over 10,000 characters is rejected with its own copy',
      () {
        expect(
          ItemText.parseDescription('a' * 10001).errorOrNull!.message,
          'Description must be 10,000 characters or fewer.',
        );
      },
    );

    test('Q10: text is plain and multi-line, and is not trimmed', () {
      expect(
        ItemText.parseContext('  a\n\n  b  ').unwrap().value,
        '  a\n\n  b  ',
      );
    });
  });

  group('§3.2, §3.3 enum ordering', () {
    test('§9.3: timeframe urgency is Now > Soon > Later > Distant', () {
      expect(Timeframe.now.isMoreUrgentThan(Timeframe.soon), isTrue);
      expect(Timeframe.soon.isMoreUrgentThan(Timeframe.later), isTrue);
      expect(Timeframe.later.isMoreUrgentThan(Timeframe.distant), isTrue);
      expect(Timeframe.distant.isMoreUrgentThan(Timeframe.now), isFalse);
      expect(Timeframe.later.mostUrgent(Timeframe.soon), Timeframe.soon);
    });

    test(
      'IDEAS-1: the four groups are in fixed order Now, Soon, Later, Distant',
      () {
        expect(Timeframe.values, <Timeframe>[
          Timeframe.now,
          Timeframe.soon,
          Timeframe.later,
          Timeframe.distant,
        ]);
      },
    );

    test('§9.3: status precedence is Done > Blocked > Todo', () {
      expect(TaskStatus.done.takesPrecedenceOver(TaskStatus.blocked), isTrue);
      expect(TaskStatus.blocked.takesPrecedenceOver(TaskStatus.todo), isTrue);
      expect(TaskStatus.todo.takesPrecedenceOver(TaskStatus.done), isFalse);
      expect(
        TaskStatus.todo.highestPrecedence(TaskStatus.blocked),
        TaskStatus.blocked,
      );
    });
  });
}

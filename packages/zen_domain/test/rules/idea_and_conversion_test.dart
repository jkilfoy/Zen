import 'package:test/test.dart';
import 'package:zen_domain/testing.dart';
import 'package:zen_domain/zen_domain.dart';

import '../support/fixtures.dart';

/// §4.1, §4.4, §4.6. Creating and editing Ideas, deleting them, and converting
/// one into a Task.
void main() {
  late SequentialIdGenerator ids;

  setUp(() => ids = SequentialIdGenerator(prefix: 'new'));

  group('§4.1 CREATE-1, CREATE-3: creating an Idea', () {
    test('CREATE-1: an Idea is created from a valid name alone', () {
      final Idea idea = createIdea(
        name: name('Read SICP'),
        timeframe: Timeframe.now,
        now: base,
        ids: ids,
      ).unwrap();

      expect(idea.name.value, 'Read SICP');
      expect(idea.tags, isEmpty);
      expect(idea.context, ItemText.empty);
      expect(idea.createdAt, base);
      expect(idea.updatedAt, base);
    });

    test('CREATE-1, §3.2: the timeframe default comes from settings', () {
      // The factory default is Now; the caller passes whatever the setting
      // holds rather than a literal.
      expect(Settings().defaultIdeaTimeframe, Timeframe.now);

      final Idea idea = createIdea(
        name: name('Read SICP'),
        timeframe: Settings(defaultIdeaTimeframe: Timeframe.later)
            .defaultIdeaTimeframe,
        now: base,
        ids: ids,
      ).unwrap();

      expect(idea.timeframe, Timeframe.later);
    });

    test('TAG-4: duplicate tags are dropped, keeping the first case typed', () {
      final Idea idea = createIdea(
        name: name('Read SICP'),
        timeframe: Timeframe.now,
        now: base,
        ids: ids,
        tags: <Tag>[tag('CS'), tag('books'), tag('cs')],
      ).unwrap();

      expect(idea.tags.map((Tag t) => t.value), <String>['CS', 'books']);
    });

    test('CREATE-3: creation is blocked on a name collision', () {
      expect(
        createIdea(
          name: name('Read SICP'),
          timeframe: Timeframe.now,
          now: base,
          ids: ids,
          activeIdeaNormalizedNames: <String>{'read sicp'},
        ).errorOrNull,
        const IdeaNameCollision(),
      );
    });
  });

  group('§4.1, NAME-8: editing an Idea', () {
    test('an edit moves updatedAt but not createdAt', () {
      final Idea idea = anIdea();
      final Idea result = updateIdea(
        idea,
        now: at(30),
        timeframe: Timeframe.soon,
      ).unwrap();

      expect(result.timeframe, Timeframe.soon);
      expect(result.createdAt, idea.createdAt);
      expect(result.updatedAt, at(30));
    });

    test('NAME-8: renaming to its own name is allowed', () {
      final Idea idea = anIdea(named: 'Read SICP');
      expect(
        updateIdea(
          idea,
          now: at(30),
          name: name('read  SICP'),
          activeIdeaNormalizedNames: <String>{'read sicp'},
        ).isOk,
        isTrue,
      );
    });

    test('NAME-8: renaming onto another active Idea is blocked', () {
      expect(
        updateIdea(
          anIdea(named: 'Read SICP'),
          now: at(30),
          name: name('Learn Rust'),
          activeIdeaNormalizedNames: <String>{'read sicp', 'learn rust'},
        ).errorOrNull,
        const IdeaNameCollision(),
      );
    });

    test('fields left out are left alone', () {
      final Idea idea = anIdea(
        tags: <Tag>[tag('cs')],
        contextText: context('Book'),
      );
      final Idea result = updateIdea(idea, now: at(30)).unwrap();

      expect(result.name, idea.name);
      expect(result.tags, idea.tags);
      expect(result.context, idea.context);
      expect(result.timeframe, idea.timeframe);
    });
  });

  group('§4.6 DEL-3: deleting an Idea', () {
    test('DEL-3: a tombstone is written with reason deleted', () {
      final Idea idea = anIdea(id: 'idea-7');
      final IdeaTombstone tombstone = deleteIdea(idea, at(30));

      expect(tombstone.id, 'idea-7');
      expect(tombstone.deletedAt, at(30));
      expect(tombstone.reason, TombstoneReason.deleted);
    });

    test('DEL-3, Q3: a tombstone stores no name', () {
      // Matching during a merge is by id only, which is what lets a deleted
      // name be used again by a new Idea (AC-18). Asserted structurally: there
      // is nowhere on the type to put a name.
      final IdeaTombstone tombstone = deleteIdea(
        anIdea(named: 'Call bank'),
        at(30),
      );
      expect(tombstone.toString(), isNot(contains('Call bank')));
    });
  });

  group('§4.4 CONVERT-1: the pre-filled draft', () {
    /// AC-11's Idea.
    Idea learnRust() => anIdea(
      id: 'idea-rust',
      named: 'Learn Rust',
      tags: <Tag>[tag('code')],
      contextText: context('Book + exercises'),
      timeframe: Timeframe.soon,
      createdAt: at(-500),
    );

    test('CONVERT-1: every field maps as the table says', () {
      final Task draft = draftTaskFromIdea(learnRust(), at(30), ids);

      expect(draft.name.value, 'Learn Rust');
      expect(draft.tags.map((Tag t) => t.value), <String>['code']);
      expect(draft.description.value, 'Book + exercises');
      expect(draft.subtasks, isEmpty);
      expect(draft.status, TaskStatus.todo);
      expect(draft.sourceIdeaId, 'idea-rust');
      expect(draft.sourceIdeaCreatedAt, at(-500));
    });

    test('CONVERT-1: the Idea\'s timeframe is discarded', () {
      final Task draft = draftTaskFromIdea(learnRust(), at(30), ids);
      // There is no timeframe on a Task at all — §3.3 has no such field.
      expect(draft.toString(), isNot(contains('soon')));
    });

    test('§3.3: a converted Task\'s createdAt is the conversion time', () {
      final Task draft = draftTaskFromIdea(learnRust(), at(30), ids);

      expect(draft.createdAt, at(30));
      expect(draft.updatedAt, at(30));
      // The Idea's own createdAt is preserved separately, so the lineage
      // records how long the item has existed.
      expect(draft.sourceIdeaCreatedAt, at(-500));
    });

    test('the draft gets a fresh Task id, not the Idea\'s', () {
      final Task draft = draftTaskFromIdea(learnRust(), at(30), ids);
      expect(draft.id, isNot('idea-rust'));
    });

    test('CONVERT-2: the user may edit every pre-filled field first', () {
      final Task edited = draftTaskFromIdea(learnRust(), at(30), ids).copyWith(
        name: name('Learn Rust properly'),
        tags: <Tag>[tag('code'), tag('books')],
        description: description('Just the book'),
      );

      expect(edited.name.value, 'Learn Rust properly');
      expect(edited.tags, hasLength(2));
      // The lineage survives the edit.
      expect(edited.sourceIdeaId, 'idea-rust');
    });

    test('CONVERT-4: the tombstone for a conversion says converted', () {
      final IdeaTombstone tombstone = tombstoneForConversion(
        learnRust(),
        at(30),
      );

      expect(tombstone.id, 'idea-rust');
      expect(tombstone.reason, TombstoneReason.converted);
      expect(tombstone.deletedAt, at(30));
    });
  });

  group('§4.4 CONVERT-3: confirmation is blocked on a name collision', () {
    test('a colliding draft is refused', () {
      final Task draft = draftTaskFromIdea(
        anIdea(named: 'Learn Rust'),
        at(30),
        ids,
      );
      final Result<Task, RuleViolation> result = checkConversionDraft(
        draft,
        activeTaskNormalizedNames: <String>{'learn rust'},
      );

      expect(result.errorOrNull, const TaskNameCollision());
    });

    test('a free draft passes through unchanged', () {
      final Task draft = draftTaskFromIdea(
        anIdea(named: 'Learn Rust'),
        at(30),
        ids,
      );

      expect(checkConversionDraft(draft).unwrap(), draft);
    });

    test(
      'CONVERT-3, CONVERT-5: nothing is produced for the Idea on refusal',
      () {
        // "The Idea is not touched." No tombstone comes out of a blocked check:
        // the tombstone is a separate call the caller makes only on confirm.
        final Idea idea = anIdea(named: 'Learn Rust');
        final Task draft = draftTaskFromIdea(idea, at(30), ids);

        expect(
          checkConversionDraft(
            draft,
            activeTaskNormalizedNames: <String>{'learn rust'},
          ).isErr,
          isTrue,
        );
        expect(idea.name.value, 'Learn Rust');
        expect(idea.timeframe, Timeframe.now);
      },
    );
  });
}

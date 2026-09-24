/// §5.10. `SearchQuery`: SEARCH-1's matching and SEARCH-2's filters.
library;

import 'package:test/test.dart';
import 'package:zen_domain/zen_domain.dart';

import '../support/fixtures.dart';

void main() {
  group('SEARCH-1: what counts as a match', () {
    test('an empty query matches everything the filters admit', () {
      expect(SearchQuery().matchesIdea(anIdea(named: 'Anything')), isTrue);
      expect(SearchQuery().matchesTask(aTask(named: 'Anything')), isTrue);
    });

    test('the name matches on a substring, case-insensitively', () {
      final Idea idea = anIdea(named: 'Read SICP');

      expect(SearchQuery(text: 'sicp').matchesIdea(idea), isTrue);
      expect(SearchQuery(text: 'ead SI').matchesIdea(idea), isTrue);
      expect(SearchQuery(text: 'lisp').matchesIdea(idea), isFalse);
    });

    test('§2: runs of whitespace and accent composition do not matter', () {
      // The same normalization NAME-5 uses, so a search behaves like the
      // uniqueness rule the user has already met.
      final Task task = aTask(named: 'Buy  milk');

      expect(SearchQuery(text: 'buy milk').matchesTask(task), isTrue);
      expect(SearchQuery(text: 'BUY   MILK').matchesTask(task), isTrue);
    });

    test('tags match, with or without the @', () {
      final Idea idea = anIdea(named: 'Read SICP', tags: <Tag>[tag('cs')]);

      expect(SearchQuery(text: 'cs').matchesIdea(idea), isTrue);
    });

    test("an idea's context matches", () {
      final Idea idea = anIdea(
        named: 'Read SICP',
        contextText: context('Wizard book, chapter 3'),
      );

      expect(SearchQuery(text: 'wizard').matchesIdea(idea), isTrue);
    });

    test("a task's description matches", () {
      final Task task = aTask(
        named: 'Move',
        describedAs: description('Hire a van'),
      );

      expect(SearchQuery(text: 'van').matchesTask(task), isTrue);
    });

    test('subtask names match', () {
      final Task task = aTask(
        named: 'Move',
        subtasks: <Subtask>[aSubtask(named: 'Pack the kitchen')],
      );

      expect(SearchQuery(text: 'kitchen').matchesTask(task), isTrue);
    });
  });

  group('SEARCH-2: filters', () {
    test('Kind excludes the other kind entirely', () {
      final Idea idea = anIdea(named: 'Read SICP');
      final Task task = aTask(named: 'Read SICP');
      final SearchQuery tasksOnly = SearchQuery(
        kinds: const <ItemKind>{ItemKind.task},
      );

      expect(tasksOnly.matchesIdea(idea), isFalse);
      expect(tasksOnly.matchesTask(task), isTrue);
    });

    test('the timeframe filter applies to ideas', () {
      final Idea soon = anIdea(named: 'Read SICP', timeframe: Timeframe.soon);
      final SearchQuery nowOnly = SearchQuery(
        timeframes: const <Timeframe>{Timeframe.now},
      );

      expect(nowOnly.matchesIdea(soon), isFalse);
      expect(SearchQuery().matchesIdea(soon), isTrue);
    });

    test('every task is in exactly one state, and Deleted wins', () {
      expect(TaskStateFilter.of(aTask()), TaskStateFilter.todo);
      expect(
        TaskStateFilter.of(aTask(status: TaskStatus.blocked)),
        TaskStateFilter.blocked,
      );
      expect(
        TaskStateFilter.of(aTask(status: TaskStatus.done)),
        TaskStateFilter.done,
      );
      // INV-3 makes an archived task Done, but it shows under Archived.
      expect(
        TaskStateFilter.of(aTask(status: TaskStatus.done, isArchived: true)),
        TaskStateFilter.archived,
      );
      // A task that is both archived and deleted is Deleted.
      expect(
        TaskStateFilter.of(
          aTask(status: TaskStatus.done, isArchived: true, isDeleted: true),
        ),
        TaskStateFilter.deleted,
      );
    });

    test('"The default is all except Deleted."', () {
      final SearchQuery defaults = SearchQuery();

      expect(defaults.matchesTask(aTask(named: 'Active')), isTrue);
      expect(
        defaults.matchesTask(
          aTask(named: 'Archived', status: TaskStatus.done, isArchived: true),
        ),
        isTrue,
      );
      expect(
        defaults.matchesTask(aTask(named: 'Deleted', isDeleted: true)),
        isFalse,
      );
    });

    test('selecting Deleted includes soft-deleted tasks', () {
      final SearchQuery withDeleted = SearchQuery(
        taskStates: const <TaskStateFilter>{TaskStateFilter.deleted},
      );

      expect(
        withDeleted.matchesTask(aTask(named: 'Deleted', isDeleted: true)),
        isTrue,
      );
      expect(withDeleted.matchesTask(aTask(named: 'Active')), isFalse);
    });

    test('the text and the filters both have to pass', () {
      final Task done = aTask(named: 'Buy milk', status: TaskStatus.done);
      final SearchQuery todoOnly = SearchQuery(
        text: 'milk',
        taskStates: const <TaskStateFilter>{TaskStateFilter.todo},
      );

      expect(todoOnly.matchesTask(done), isFalse);
    });
  });
}

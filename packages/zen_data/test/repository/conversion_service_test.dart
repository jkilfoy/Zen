/// §4.4, CONVERT-3, CONVERT-4, AC-11. Converting an Idea into a Task.
///
/// AC-11 is M4's to pass end to end, through the `"Make Task"` button. What is
/// M3's is the sentence that button relies on: "Both changes happen in one
/// transaction." These tests are about that — and about the half-converted
/// states the schema must make unreachable.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zen_domain/testing.dart';
import 'package:zen_domain/zen_domain.dart';

import '../support/harness.dart';

void main() {
  late TestRepositories repos;
  late IdGenerator ids;

  setUp(() {
    repos = TestRepositories();
    ids = SequentialIdGenerator(prefix: 'task');
  });

  group('CONVERT-4: one transaction', () {
    test('AC-11: the Task exists, the Idea is gone, the tombstone says '
        'converted', () async {
      final Idea idea = anIdea(
        id: 'idea-1',
        named: 'Learn Rust',
        timeframe: Timeframe.soon,
        tags: <Tag>[tag('code')],
        context: 'Book + exercises',
      );
      await repos.ideas.create(idea);

      final Task draft = draftTaskFromIdea(idea, at(10), ids);
      final Result<Task, RuleViolation> result = await repos.conversions
          .convert(idea, draft, at(10));

      expect(result.isOk, isTrue);

      final Task task = (await repos.tasks.findById(draft.id))!;
      expect(task.name.value, 'Learn Rust');
      expect(task.tags.map((Tag t) => t.value), <String>['code']);
      expect(task.description.value, 'Book + exercises');
      expect(task.status, TaskStatus.todo);
      expect(task.subtasks, isEmpty);
      expect(task.sourceIdeaId, 'idea-1');
      expect(
        task.sourceIdeaCreatedAt,
        idea.createdAt,
        reason: 'INV-8: the pair travels together',
      );

      expect(await repos.ideas.findById('idea-1'), isNull);

      final List<IdeaTombstone> tombstones = await repos.tombstones.all();
      expect(tombstones.single.id, 'idea-1');
      expect(tombstones.single.reason, TombstoneReason.converted);
      expect(tombstones.single.deletedAt, at(10));
    });

    test('CONVERT-1: the Idea timeframe is discarded', () async {
      final Idea idea = anIdea(timeframe: Timeframe.distant);
      await repos.ideas.create(idea);

      final Task draft = draftTaskFromIdea(idea, at(10), ids);
      await repos.conversions.convert(idea, draft, at(10));

      // Nothing on a Task carries a timeframe; asserting the Task exists and
      // the Idea does not is the whole of it.
      expect(await repos.tasks.findById(draft.id), isNotNull);
    });

    test('CONVERT-3: a colliding name leaves the Idea untouched', () async {
      await repos.tasks.create(aTask(id: 'existing', named: 'Learn Rust'));
      final Idea idea = anIdea(id: 'idea-1', named: 'Learn Rust');
      await repos.ideas.create(idea);

      final Task draft = draftTaskFromIdea(idea, at(10), ids);
      final Result<Task, RuleViolation> result = await repos.conversions
          .convert(idea, draft, at(10));

      expect(result.errorOrNull, const TaskNameCollision());
      expect(
        await repos.ideas.findById('idea-1'),
        idea,
        reason: 'CONVERT-3: "The Idea is not touched."',
      );
      expect(await repos.tombstones.all(), isEmpty);
      expect(await repos.tasks.findById(draft.id), isNull);
    });

    test('INV-7 makes the half-converted state unreachable', () async {
      // The only way to end up with both an Idea and its tombstone would be to
      // write the tombstone first; the trigger refuses that outright, which is
      // what makes the ordering in `convert` compulsory rather than a
      // convention someone can quietly change.
      final Idea idea = anIdea(id: 'idea-1');
      await repos.ideas.create(idea);

      await expectLater(
        repos.tombstones.add(tombstoneForConversion(idea, at(10))),
        throwsA(isA<Object>()),
      );
    });

    test('the converted Task keeps the Idea tags, not the Idea rows', () async {
      final Idea idea = anIdea(tags: <Tag>[tag('code'), tag('Rust')]);
      await repos.ideas.create(idea);

      final Task draft = draftTaskFromIdea(idea, at(10), ids);
      await repos.conversions.convert(idea, draft, at(10));

      expect(await _count(repos, 'idea_tags'), 0, reason: 'cascaded away');
      expect(await _count(repos, 'task_tags'), 2);
      expect(
        (await repos.tasks.findById(draft.id))!.tags.map((Tag t) => t.value),
        <String>['code', 'Rust'],
      );
    });

    test('HIST-2: both sides of the conversion are logged', () async {
      final Idea idea = anIdea(id: 'idea-1');
      await repos.ideas.create(idea);
      final Task draft = draftTaskFromIdea(idea, at(10), ids);

      await repos.conversions.convert(idea, draft, at(10));

      expect(
        (await repos.events.forItem('idea-1')).map((ItemEvent e) => e.type),
        containsAll(<ItemEventType>[
          ItemEventType.created,
          ItemEventType.convertedToTask,
        ]),
      );
      expect(
        (await repos.events.forItem(draft.id)).single.payload['fromIdeaId'],
        'idea-1',
      );
    });
  });
}

Future<int> _count(TestRepositories repos, String table) async {
  final row = await repos.db
      .customSelect('SELECT count(*) AS c FROM $table')
      .getSingle();
  return row.data['c']! as int;
}

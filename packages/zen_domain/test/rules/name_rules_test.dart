import 'package:test/test.dart';
import 'package:zen_domain/zen_domain.dart';

import '../support/fixtures.dart';

/// §3.1. NAME-6 through NAME-9, as far as they can be decided without a store.
///
/// §11.4.2: uniqueness itself is the repository's and ultimately the partial
/// unique index's job (§11.5.2). These functions are the *decision* — which
/// violation, and when — so the rule is testable in a second. AC-8, AC-9 and
/// AC-10 are re-run against a real database in M3.
void main() {
  group('NAME-6, NAME-8: saving an Item', () {
    test('a free name is available', () {
      expect(
        checkNameAvailable(
          name: name('Buy milk'),
          kind: ItemKind.task,
          activeNormalizedNames: <String>{'walk the dog'},
        ).isOk,
        isTrue,
      );
    });

    test('a taken Task name collides, with the Task copy', () {
      final Result<ItemName, RuleViolation> result = checkNameAvailable(
        name: name('Buy milk'),
        kind: ItemKind.task,
        activeNormalizedNames: <String>{'buy milk'},
      );

      expect(result.errorOrNull, const TaskNameCollision());
      expect(
        result.errorOrNull!.message,
        'A task with this name already exists.',
      );
    });

    test('a taken Idea name collides, with the Idea copy', () {
      final Result<ItemName, RuleViolation> result = checkNameAvailable(
        name: name('Read SICP'),
        kind: ItemKind.idea,
        activeNormalizedNames: <String>{'read sicp'},
      );

      expect(result.errorOrNull, const IdeaNameCollision());
      expect(
        result.errorOrNull!.message,
        'An idea with this name already exists.',
      );
    });

    test('NAME-5, AC-8: collision is by normalized name', () {
      // "buy  MILK" against an active "Buy milk".
      expect(
        checkNameAvailable(
          name: name('buy  MILK'),
          kind: ItemKind.task,
          activeNormalizedNames: <String>{'buy milk'},
        ).isErr,
        isTrue,
      );
    });

    test('AC-8: the two kinds are independent namespaces', () {
      // An active Task "Buy milk" does not stop an Idea of the same name: the
      // caller passes only its own kind's names.
      expect(
        checkNameAvailable(
          name: name('Buy milk'),
          kind: ItemKind.idea,
          activeNormalizedNames: const <String>{},
        ).isOk,
        isTrue,
      );
    });

    test(
      'NAME-8: renaming an Item to its own current name is not a collision',
      () {
        expect(
          checkNameAvailable(
            name: name('Buy Milk'),
            kind: ItemKind.task,
            activeNormalizedNames: <String>{'buy milk'},
            selfNormalizedName: 'buy milk',
          ).isOk,
          isTrue,
        );
      },
    );

    test(
      'NAME-8: renaming onto a different Item\'s name is still a collision',
      () {
        expect(
          checkNameAvailable(
            name: name('Walk the dog'),
            kind: ItemKind.task,
            activeNormalizedNames: <String>{'walk the dog', 'buy milk'},
            selfNormalizedName: 'buy milk',
          ).errorOrNull,
          const TaskNameCollision(),
        );
      },
    );

    test('NAME-7, AC-9: a name freed by archiving is available again', () {
      // The archived Task is simply not in the active set (§2).
      expect(
        checkNameAvailable(
          name: name('Water the plants'),
          kind: ItemKind.task,
          activeNormalizedNames: const <String>{},
        ).isOk,
        isTrue,
      );
    });
  });

  group('NAME-9: reactivation', () {
    test('a free name allows reactivation', () {
      expect(
        checkReactivationAllowed(
          name: name('Water the plants'),
          activeTaskNormalizedNames: const <String>{},
        ).isOk,
        isTrue,
      );
    });

    test('AC-10: a held name prohibits it, with the NAME-9 copy verbatim', () {
      final Result<ItemName, RuleViolation> result = checkReactivationAllowed(
        name: name('Water the plants'),
        activeTaskNormalizedNames: <String>{'water the plants'},
      );

      expect(result.errorOrNull, const ActiveTaskHoldsName());
      expect(
        result.errorOrNull!.message,
        'There is already an active task with this name in your To Do list. '
        'Complete and archive the active task in order to restore this one to '
        'your To Do list.',
      );
    });

    test('AC-10: no rename is offered as a way around it', () {
      // The refusal is the whole API: there is no alternative-name suggestion
      // to assert on, and NAME-9 requires that there never be one.
      final RuleViolation violation = checkReactivationAllowed(
        name: name('Water the plants'),
        activeTaskNormalizedNames: <String>{'water the plants'},
      ).errorOrNull!;

      expect(violation, isA<ActiveTaskHoldsName>());
      expect(violation.message, contains('Complete and archive'));
      expect(violation.message, isNot(contains('rename')));
    });
  });
}

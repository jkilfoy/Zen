/// §3.7. The invariants that span more than one record.
///
/// Per-entity invariants (INV-1 through INV-5) are checked by
/// `Task.invariantFailures`, `Subtask.invariantFailures` and
/// `Idea.invariantFailures`, and asserted by those entities' constructors.
/// INV-6 and INV-7 need the whole dataset, so they live here.
///
/// §3.7 says "The persistence layer MUST enforce these" — §11.5.2 does that
/// with partial unique indexes and CHECK constraints. This function is how the
/// domain's own tests, M2's merge property tests ("the output satisfies every
/// rule in §3.7 for any valid inputs", §11.12) and M6's convergence simulation
/// assert the same thing without a database.
library;

import 'idea.dart';
import 'task.dart';
import 'tombstone.dart';

/// §3.7. Returns every invariant a dataset breaks, empty when it is
/// well-formed.
///
/// Covers INV-1 through INV-5 for each record, INV-6's uniqueness among active
/// Items of the same kind (NAME-6), and INV-7.
///
/// NAME-6's scope is deliberately narrow: archived Tasks, soft-deleted Tasks
/// and tombstoned Ideas do not reserve their names (NAME-7), and an Idea and a
/// Task may share one, because the two kinds are independent namespaces.
List<String> datasetInvariantFailures({
  required Iterable<Idea> ideas,
  required Iterable<Task> tasks,
  Iterable<IdeaTombstone> tombstones = const <IdeaTombstone>[],
}) {
  final List<String> failures = <String>[];

  for (final Idea idea in ideas) {
    failures.addAll(
      idea.invariantFailures.map((String f) => 'Idea ${idea.id}: $f'),
    );
  }
  for (final Task task in tasks) {
    failures.addAll(
      task.invariantFailures.map((String f) => 'Task ${task.id}: $f'),
    );
  }

  // INV-6 / NAME-6: among active Items of the same kind, names are unique.
  failures.addAll(
    _duplicateActiveNames(
      kind: 'Idea',
      normalizedNames: ideas
          .where((Idea i) => i.isActive)
          .map((Idea i) => i.name.normalized),
    ),
  );
  failures.addAll(
    _duplicateActiveNames(
      kind: 'Task',
      normalizedNames: tasks
          .where((Task t) => t.isActive)
          .map((Task t) => t.name.normalized),
    ),
  );

  // INV-7: every tombstoned Idea id is absent from the Ideas table.
  final Set<String> tombstonedIds = tombstones
      .map((IdeaTombstone t) => t.id)
      .toSet();
  for (final Idea idea in ideas) {
    if (tombstonedIds.contains(idea.id)) {
      failures.add('INV-7: Idea ${idea.id} is present but tombstoned');
    }
  }

  return failures;
}

Iterable<String> _duplicateActiveNames({
  required String kind,
  required Iterable<String> normalizedNames,
}) {
  final Set<String> seen = <String>{};
  final Set<String> duplicates = <String>{};
  for (final String name in normalizedNames) {
    if (!seen.add(name)) {
      duplicates.add(name);
    }
  }
  return duplicates.map(
    (String name) =>
        'INV-6 / NAME-6: two active ${kind}s share the name "$name"',
  );
}

/// §4.4. Converting an Idea into a Task.
///
/// Conversion is one-way (Q31): there is no way to turn a Task back into an
/// Idea, and the MVP must not add one.
library;

import '../ids/id_generator.dart';
import '../model/enums.dart';
import '../model/idea.dart';
import '../model/item_name.dart';
import '../model/subtask.dart';
import '../model/task.dart';
import '../model/tombstone.dart';
import '../result.dart';
import 'name_rules.dart';

/// §4.4, CONVERT-1. Builds the Create Task screen's pre-filled draft from
/// [idea].
///
/// | Task field | Value |
/// |---|---|
/// | `name` | Idea `name` |
/// | `tags` | Idea `tags` |
/// | `description` | Idea `context` |
/// | `subtasks` | `[]` |
/// | `status` | `Todo` |
/// | `sourceIdeaId`, `sourceIdeaCreatedAt` | Idea `id`, `createdAt` |
///
/// The Idea's `timeframe` is discarded (CONVERT-1).
///
/// [now] is the instant the Task comes into existence. CONVERT-4 says nothing
/// is written before the user presses `"Create Task"`, and §3.3 says a
/// converted Task's `createdAt` "is the conversion time" — so callers build the
/// draft with the confirm instant, not with the instant the screen opened.
/// CONVERT-2 lets the user edit every pre-filled field first; those edits are
/// applied to the returned draft by the caller.
Task draftTaskFromIdea(Idea idea, DateTime now, IdGenerator ids) => Task(
  id: ids.newId(),
  name: idea.name,
  tags: idea.tags,
  description: idea.context,
  status: TaskStatus.todo,
  subtasks: const <Subtask>[],
  createdAt: now,
  updatedAt: now,
  sourceIdeaId: idea.id,
  sourceIdeaCreatedAt: idea.createdAt,
);

/// CONVERT-4. The tombstone written for an Idea consumed by a conversion.
///
/// `reason = converted`, which is what distinguishes it from a plain delete in
/// the merge report and in the event log (HIST-2).
IdeaTombstone tombstoneForConversion(Idea idea, DateTime now) => IdeaTombstone(
  id: idea.id,
  deletedAt: now,
  reason: TombstoneReason.converted,
);

/// §4.4, CONVERT-3, AC-11. Validates a conversion draft immediately before it
/// is committed.
///
/// CONVERT-3: "If the name collides with an active Task (NAME-8), confirmation
/// is blocked until the user edits the name. The Idea is not touched."
///
/// This is the last check before `ConversionService.convert` (§11.4.6) writes
/// the Task, removes the Idea and stores the tombstone in one transaction
/// (CONVERT-4). It returns the draft unchanged on success so that the call site
/// reads as a pipeline.
Result<Task, RuleViolation> checkConversionDraft(
  Task draft, {
  Set<String> activeTaskNormalizedNames = const <String>{},
}) {
  final Result<ItemName, RuleViolation> available = checkNameAvailable(
    name: draft.name,
    kind: ItemKind.task,
    activeNormalizedNames: activeTaskNormalizedNames,
  );
  if (available case Err<ItemName, RuleViolation>(:final RuleViolation error)) {
    return Err<Task, RuleViolation>(error);
  }
  return Ok<Task, RuleViolation>(draft);
}

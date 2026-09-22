/// §4.1, §4.6. Every rule that acts on an Idea.
library;

import '../ids/id_generator.dart';
import '../model/enums.dart';
import '../model/idea.dart';
import '../model/item_name.dart';
import '../model/item_text.dart';
import '../model/settings.dart';
import '../model/tag.dart';
import '../model/tombstone.dart';
import '../result.dart';
import 'name_rules.dart';

/// §4.1, CREATE-1, CREATE-3. Creates an Idea from a valid name.
///
/// "An Idea is created from a valid `name` alone. `tags`, `context` and
/// `timeframe` are optional and take the defaults in §3.2." The timeframe
/// default is `settings.defaultIdeaTimeframe`, whose factory default is
/// [Timeframe.now] — so callers pass [Settings.defaultIdeaTimeframe] rather
/// than a literal.
///
/// Creation is blocked if the name collides with an active Idea (NAME-8).
Result<Idea, RuleViolation> createIdea({
  required ItemName name,
  required Timeframe timeframe,
  required DateTime now,
  required IdGenerator ids,
  Iterable<Tag> tags = const <Tag>[],
  ItemText context = ItemText.empty,
  Set<String> activeIdeaNormalizedNames = const <String>{},
}) {
  final Result<ItemName, RuleViolation> available = checkNameAvailable(
    name: name,
    kind: ItemKind.idea,
    activeNormalizedNames: activeIdeaNormalizedNames,
  );
  if (available case Err<ItemName, RuleViolation>(:final RuleViolation error)) {
    return Err<Idea, RuleViolation>(error);
  }

  return Ok<Idea, RuleViolation>(
    Idea(
      id: ids.newId(),
      name: name,
      tags: dedupeTags(tags),
      context: context,
      timeframe: timeframe,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

/// §4.1, NAME-8. Applies an edit to an existing Idea.
///
/// Every field the Edit Idea screen offers (IDEAFORM-1) in one call, so that
/// the name check and the `updatedAt` bump cannot be forgotten. NAME-8's "
/// renaming an Item to its own current name is not a collision" is handled by
/// passing the Idea's own normalized name through.
Result<Idea, RuleViolation> updateIdea(
  Idea idea, {
  required DateTime now,
  ItemName? name,
  Timeframe? timeframe,
  Iterable<Tag>? tags,
  ItemText? context,
  Set<String> activeIdeaNormalizedNames = const <String>{},
}) {
  if (name != null) {
    final Result<ItemName, RuleViolation> available = checkNameAvailable(
      name: name,
      kind: ItemKind.idea,
      activeNormalizedNames: activeIdeaNormalizedNames,
      selfNormalizedName: idea.name.normalized,
    );
    if (available case Err<ItemName, RuleViolation>(
      :final RuleViolation error,
    )) {
      return Err<Idea, RuleViolation>(error);
    }
  }

  return Ok<Idea, RuleViolation>(
    idea.copyWith(
      name: name,
      timeframe: timeframe,
      tags: tags == null ? null : dedupeTags(tags),
      context: context,
      updatedAt: now,
    ),
  );
}

/// DEL-3, DEL-4, AC-17. Removes an Idea, producing its tombstone.
///
/// "Deleting an Idea removes it from the user-visible dataset permanently. It
/// cannot be restored in the UI." Unlike a Task this is not a soft delete, so
/// the caller drops the Idea and stores what this returns.
///
/// The tombstone carries no name (DEL-3, Q3): matching during a merge is by id
/// only, so a name that was deleted may be used again by a new Idea with a new
/// id, and the tombstone will not affect it (AC-18).
IdeaTombstone deleteIdea(Idea idea, DateTime now) =>
    IdeaTombstone(id: idea.id, deletedAt: now, reason: TombstoneReason.deleted);

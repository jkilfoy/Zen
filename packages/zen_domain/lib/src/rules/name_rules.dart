/// §3.1. Name uniqueness: NAME-6, NAME-8 and NAME-9.
///
/// §11.4.2 is explicit that uniqueness is *not* a property of [ItemName] — it
/// needs the store. These functions are the decision without the store: they
/// take the set of active normalized names and return the right violation, so
/// the rule can be tested in a second with no database. The actual guarantee is
/// the partial unique index in §11.5.2, and NAME-10 re-establishes it after
/// every merge.
library;

import '../model/enums.dart';
import '../model/item_name.dart';
import '../result.dart';

/// NAME-6, NAME-8, CREATE-3, CONVERT-3. Whether [name] may be saved on an
/// active Item of [kind].
///
/// [activeNormalizedNames] is every active Item of that kind's normalized name
/// (§2, NAME-7): archived Tasks, soft-deleted Tasks and tombstoned Ideas are
/// not in it, which is what makes recurring work possible (AC-9).
///
/// [selfNormalizedName] is the Item's own current normalized name when this is
/// an edit rather than a creation. NAME-8: "Renaming an Item to its own current
/// name is not a collision."
///
/// Ideas and Tasks are independent namespaces (NAME-6, AC-8), so callers pass
/// the names of one kind only, and [kind] chooses which message to return.
Result<ItemName, RuleViolation> checkNameAvailable({
  required ItemName name,
  required ItemKind kind,
  required Set<String> activeNormalizedNames,
  String? selfNormalizedName,
}) {
  if (selfNormalizedName != null && selfNormalizedName == name.normalized) {
    return Ok<ItemName, RuleViolation>(name);
  }
  if (!activeNormalizedNames.contains(name.normalized)) {
    return Ok<ItemName, RuleViolation>(name);
  }
  return Err<ItemName, RuleViolation>(switch (kind) {
    ItemKind.idea => const IdeaNameCollision(),
    ItemKind.task => const TaskNameCollision(),
  });
}

/// NAME-9, ARCH-4, AC-10. Whether a Task may be returned to the active set
/// under [name].
///
/// Restoring a deleted Task or unarchiving an archived one is prohibited when
/// an active Task already holds that name. "The user is not offered a rename as
/// a way around this. They must deal with the active Task first" (NAME-9), so
/// this returns a refusal and never a suggestion.
Result<ItemName, RuleViolation> checkReactivationAllowed({
  required ItemName name,
  required Set<String> activeTaskNormalizedNames,
}) {
  if (activeTaskNormalizedNames.contains(name.normalized)) {
    return const Err<ItemName, RuleViolation>(ActiveTaskHoldsName());
  }
  return Ok<ItemName, RuleViolation>(name);
}

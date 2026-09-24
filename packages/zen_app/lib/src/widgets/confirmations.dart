/// NAV-1, DEL-4, §4.2. The dialogs the specification gives copy for.
library;

import 'package:flutter/material.dart';
import 'package:zen_domain/zen_domain.dart';

/// NAV-1. "Leaving an Add or Edit screen with unsaved changes asks
/// `"Discard changes?"`"
///
/// Returns `true` when the user chose to discard.
Future<bool> confirmDiscard(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: const Text('Discard changes?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    ) ??
    false;

/// DEL-4. "If `settings.confirmDestructive` is true, both kinds of delete ask
/// for confirmation first. The dialog shows `"Delete this idea? This cannot be
/// undone."` or `"Delete this task?"`"
///
/// Returns `true` when the delete should go ahead. With [confirmDestructive]
/// false it asks nothing and returns `true`.
Future<bool> confirmDelete(
  BuildContext context, {
  required ItemKind kind,
  required bool confirmDestructive,
}) async {
  if (!confirmDestructive) {
    return true;
  }
  final String message = switch (kind) {
    ItemKind.idea => 'Delete this idea? This cannot be undone.',
    ItemKind.task => 'Delete this task?',
  };
  return await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
}

/// §4.2, AC-1, TASKFORM-4. Shows a [RuleViolation]'s copy.
///
/// The UI "renders [RuleViolation.message]; it never composes its own copy"
/// (§11.4.1), and a violation with no message is silent by design — §4.2's
/// `Blocked` rows change nothing and say nothing. So a silent violation shows
/// no dialog at all.
Future<void> showViolation(
  BuildContext context,
  RuleViolation violation,
) async {
  if (!violation.hasMessage) {
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      content: Text(violation.message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// SUB-2. "SHOULD show a one-line hint" rather than a dialog, because tapping a
/// locked circle in the To Do list is an ordinary mis-tap, not an error.
void showHint(BuildContext context, RuleViolation violation) {
  if (!violation.hasMessage) {
    return;
  }
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(violation.message)));
}

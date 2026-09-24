/// ROW-2, TAG-5. The one line of tags under an item's name.
library;

import 'package:flutter/material.dart';
import 'package:zen_domain/zen_domain.dart';

/// ROW-2. "Below the name is one line of tags, each shown as `@tag` and
/// separated by spaces. Tags that don't fit are cut off with an ellipsis. If
/// the item has no tags, the line is omitted."
///
/// The omission is the caller's to honour: [TagLine] renders nothing for an
/// empty list, so a `Column` containing one gains no stray gap.
class TagLine extends StatelessWidget {
  /// Renders [tags] as one ellipsized line.
  const TagLine(this.tags, {super.key});

  /// The item's tags, in their stored order (§3.2, §3.3).
  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      tags.map((Tag tag) => tag.display).join(' '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

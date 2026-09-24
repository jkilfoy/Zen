/// §5.6. The list-item rendering both tabs share.
library;

import 'package:flutter/material.dart';
import 'package:zen_domain/zen_domain.dart';

import 'tag_line.dart';

/// §5.6. One row: an optional leading control, the name, the tag line, and an
/// optional trailing action.
///
/// * ROW-1: the name shows in full up to **4 lines**, then ellipsizes.
/// * ROW-2: one line of `@tag`s below it, omitted when there are none.
/// * ROW-3: tapping the name or tag text opens the item's Edit screen.
/// * ROW-5: a trailing action is right-aligned, aligned with the first line of
///   the name, separated by at least 16 px, and outside the ROW-3 tap region.
///
/// ROW-4's spacing and divider belong to the list, not the row, so that a
/// divider is not drawn under the last item.
class ItemRow extends StatelessWidget {
  /// Builds a row for [name].
  const ItemRow({
    required this.name,
    required this.tags,
    required this.onOpen,
    this.leading,
    this.trailing,
    this.struckThrough = false,
    this.badge,
    this.children = const <Widget>[],
    super.key,
  });

  /// ROW-1. The item's name.
  final String name;

  /// ROW-2. The item's tags.
  final List<Tag> tags;

  /// ROW-3. Opens the item's Edit screen, or `null` where the row does not
  /// open one.
  final VoidCallback? onOpen;

  /// TODO-3, IDEAS-5. The completion circle, where the row has one.
  final Widget? leading;

  /// ROW-5. The trailing action, currently only `"Make Task"` (IDEAS-6).
  final Widget? trailing;

  /// TODO-3, §3.6. Whether to strike the name through.
  final bool struckThrough;

  /// SEARCH-3. The small kind badge (`Idea` / `Task`), on the Search screen
  /// only.
  final Widget? badge;

  /// TODO-4. The subtask rows, indented one step below the tag line.
  final List<Widget> children;

  /// ROW-1. "The item name shows in full up to 4 lines."
  static const int nameMaxLines = 4;

  /// ROW-5. "separated from the text block by at least 16 dp/px".
  static const double trailingGap = 16;

  /// ROW-5. "Consecutive rows' trailing buttons MUST be at least 24 dp/px apart
  /// vertically, so a mis-aimed tap cannot hit the neighbouring Item's button."
  ///
  /// Half above and half below, so two adjacent rows contribute the full 24
  /// between their buttons. A row with no trailing action does not need it.
  static const double trailingRowPadding = 12;

  /// ROW-3, ROW-5, B2. The region that opens the Edit screen.
  ///
  /// Named so that a test can measure it: ROW-5's "MUST NOT overlap the
  /// row-opens-Edit tap region" is a statement about *this* rectangle, not
  /// about where the glyphs happen to stop.
  static const Key tapRegionKey = Key('item-row-tap');

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Widget textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ?badge,
        Text(
          name,
          maxLines: nameMaxLines,
          overflow: TextOverflow.ellipsis,
          style: text.bodyLarge?.copyWith(
            decoration: struckThrough ? TextDecoration.lineThrough : null,
          ),
        ),
        TagLine(tags),
      ],
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: trailing == null ? 4 : trailingRowPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ?leading,
          Expanded(
            // ROW-3, B2. The tap region is the whole of the row's text column,
            // not the glyphs inside it: `Expanded` gives a tight width, so the
            // `InkWell` fills everything between the leading control and the
            // trailing action. ROW-5's separation is preserved because the
            // trailing button sits outside this `Expanded` entirely, beyond
            // [trailingGap].
            //
            // The subtask rows are inside the region too, so a tap on a subtask
            // name opens the parent Task. Their completion circles keep working:
            // a nested `InkResponse` wins the gesture arena against the
            // `InkWell` above it.
            child: InkWell(
              key: tapRegionKey,
              onTap: onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: textBlock,
                  ),
                  ...children,
                ],
              ),
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: trailingGap),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// §5.8. `SCR-IDEAS`: the Ideas tab.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zen_domain/zen_domain.dart';

import '../providers/app_providers.dart';
import '../router.dart';
import '../widgets/highlight.dart';
import '../widgets/item_row.dart';
import 'idea_form_screen.dart' show TimeframePicker;

/// §5.8. Four collapsible groups in fixed order, each listing its Ideas oldest
/// first, each row carrying `"Make Task"`.
///
/// IDEAS-5: Ideas have **no** completion circle.
class IdeasTab extends ConsumerStatefulWidget {
  /// Builds the tab, scrolling [highlight] into view if it is present.
  const IdeasTab({this.highlight, super.key});

  /// IDEAFORM-4. The id of an Idea just added.
  final String? highlight;

  @override
  ConsumerState<IdeasTab> createState() => _IdeasTabState();
}

class _IdeasTabState extends ConsumerState<IdeasTab> {
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};

  /// IDEAS-2. "On entering the tab, a group is expanded if and only if it is in
  /// `settings.expandedIdeaGroups`. Tapping a header toggles that group. The
  /// toggle lasts until the user leaves the Review screen; it does not change
  /// the setting."
  ///
  /// Hence local state seeded from the setting, rather than a write-back.
  Set<Timeframe>? _expanded;
  bool _scrolled = false;

  Set<Timeframe> _expandedGroups(Settings settings) =>
      _expanded ??= <Timeframe>{...settings.expandedIdeaGroups};

  /// IDEAFORM-4. "with the group containing the new Idea expanded and the new
  /// Idea scrolled into view".
  void _revealHighlight(List<Idea> ideas, Settings settings) {
    final String? id = widget.highlight;
    if (_scrolled || id == null) {
      return;
    }
    final Idea? target = ideas.where((Idea idea) => idea.id == id).firstOrNull;
    if (target == null) {
      return;
    }
    _expandedGroups(settings).add(target.timeframe);
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      final BuildContext? row = _rowKeys[id]?.currentContext;
      if (row != null && mounted) {
        _scrolled = true;
        unawaited(Scrollable.ensureVisible(row, alignment: 0.3));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Idea>> ideas = ref.watch(ideasProvider);
    final Settings settings = ref.watch(currentSettingsProvider);

    return ideas.when(
      loading: () => const SizedBox.shrink(),
      error: (Object error, StackTrace _) =>
          Center(child: Text('Could not read your ideas: $error')),
      data: (List<Idea> all) {
        // REVIEW-3. "An empty Ideas tab shows `"No ideas yet."`"
        if (all.isEmpty) {
          return const Center(child: Text('No ideas yet.'));
        }
        _revealHighlight(all, settings);
        final Set<Timeframe> expanded = _expandedGroups(settings);

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: <Widget>[
            // IDEAS-1. "four collapsible groups in fixed order Now, Soon,
            // Later, Distant". IDEAS-3 shows a header even when empty.
            for (final Timeframe timeframe in Timeframe.values)
              _Group(
                timeframe: timeframe,
                // IDEAS-4. "Within a group, Ideas are ordered by `createdAt`
                // ascending", which is the stream's own order.
                ideas: all
                    .where((Idea idea) => idea.timeframe == timeframe)
                    .toList(),
                expanded: expanded.contains(timeframe),
                onToggle: () => setState(() {
                  if (!expanded.remove(timeframe)) {
                    expanded.add(timeframe);
                  }
                }),
                highlight: widget.highlight,
                rowKeys: _rowKeys,
              ),
          ],
        );
      },
    );
  }
}

/// IDEAS-1, IDEAS-3. One timeframe group and its header.
class _Group extends StatelessWidget {
  const _Group({
    required this.timeframe,
    required this.ideas,
    required this.expanded,
    required this.onToggle,
    required this.highlight,
    required this.rowKeys,
  });

  final Timeframe timeframe;
  final List<Idea> ideas;
  final bool expanded;
  final VoidCallback onToggle;
  final String? highlight;
  final Map<String, GlobalKey> rowKeys;

  @override
  Widget build(BuildContext context) {
    // IDEAS-3. "Headers of empty groups are still shown, with count `(0)`, and
    // cannot be expanded."
    final bool canExpand = ideas.isNotEmpty;
    final String label =
        '${TimeframePicker.labels[timeframe]} '
        '(${ideas.length})';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ListTile(
          title: Text(label, style: Theme.of(context).textTheme.titleMedium),
          trailing: Icon(
            expanded && canExpand ? Icons.expand_less : Icons.expand_more,
          ),
          enabled: canExpand,
          onTap: canExpand ? onToggle : null,
        ),
        if (expanded && canExpand)
          for (int i = 0; i < ideas.length; i++) ...<Widget>[
            BriefHighlight(
              active: ideas[i].id == highlight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _IdeaRow(
                  key: rowKeys.putIfAbsent(ideas[i].id, GlobalKey.new),
                  idea: ideas[i],
                ),
              ),
            ),
            // ROW-4. A thin divider between items.
            if (i < ideas.length - 1) const Divider(height: 1),
          ],
      ],
    );
  }
}

/// §5.6, IDEAS-5, IDEAS-6. One Idea row.
class _IdeaRow extends StatelessWidget {
  const _IdeaRow({required this.idea, super.key});

  final Idea idea;

  @override
  Widget build(BuildContext context) => ItemRow(
    name: idea.name.value,
    tags: idea.tags,
    // ROW-3. Tapping the name or tag text opens Edit Idea.
    onOpen: () => context.push(Routes.editIdea(idea.id)),
    // IDEAS-6, ROW-5. "Every Idea row carries a trailing button labelled
    // `"Make Task"`."
    trailing: Semantics(
      // IDEAS-6. "The button's accessibility label is `"Make task from idea:
      // <idea name>"`."
      label: 'Make task from idea: ${idea.name.value}',
      button: true,
      child: ConstrainedBox(
        // ROW-5. "Its touch target is at least 48 × 48 dp."
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: OutlinedButton(
          onPressed: () => context.push(Routes.convertIdea(idea.id)),
          child: const ExcludeSemantics(child: Text('Make Task')),
        ),
      ),
    ),
  );
}

/// §5.10. `SCR-SEARCH`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zen_domain/zen_domain.dart';

import '../providers/app_providers.dart';
import '../router.dart';
import '../widgets/completion_circle.dart';
import '../widgets/item_row.dart';
import 'idea_form_screen.dart' show TimeframePicker;

/// §5.10. A text field and three filters over both kinds.
///
/// What counts as a match is `SearchQuery`'s (§11.7 keeps that decision in
/// `zen_domain`); this screen holds the controls and renders the results.
class SearchScreen extends ConsumerStatefulWidget {
  /// Builds the screen.
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _text = TextEditingController();

  // SEARCH-2's defaults: both kinds, all four timeframes, every Task state but
  // Deleted.
  final Set<ItemKind> _kinds = <ItemKind>{ItemKind.idea, ItemKind.task};
  final Set<Timeframe> _timeframes = Timeframe.values.toSet();
  final Set<TaskStateFilter> _states = <TaskStateFilter>{
    ...TaskStateFilter.defaults,
  };

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SearchQuery query = SearchQuery(
      text: _text.text,
      kinds: _kinds,
      timeframes: _timeframes,
      taskStates: _states,
    );
    final List<Idea> ideas = (ref.watch(ideasProvider).value ?? const <Idea>[])
        .where(query.matchesIdea)
        .toList();
    final List<Task> tasks =
        (ref.watch(allTasksProvider).value ?? const <Task>[])
            .where(query.matchesTask)
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // SEARCH-1. "A text field matches case-insensitive substrings
                  // of name, tags, context/description and subtask names."
                  TextField(
                    controller: _text,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (String _) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  // SEARCH-2. Kind: Ideas / Tasks / Both.
                  _FilterRow(
                    label: 'Kind',
                    children: <Widget>[
                      for (final ItemKind kind in ItemKind.values)
                        FilterChip(
                          label: Text(
                            kind == ItemKind.idea ? 'Ideas' : 'Tasks',
                          ),
                          selected: _kinds.contains(kind),
                          onSelected: (bool on) =>
                              setState(() => _toggle(_kinds, kind, on)),
                        ),
                    ],
                  ),
                  // SEARCH-2. Idea timeframe: multi-select, all four by
                  // default.
                  if (_kinds.contains(ItemKind.idea))
                    _FilterRow(
                      label: 'Idea timeframe',
                      children: <Widget>[
                        for (final Timeframe timeframe in Timeframe.values)
                          FilterChip(
                            label: Text(TimeframePicker.labels[timeframe]!),
                            selected: _timeframes.contains(timeframe),
                            onSelected: (bool on) => setState(
                              () => _toggle(_timeframes, timeframe, on),
                            ),
                          ),
                      ],
                    ),
                  // SEARCH-2. Task state: multi-select, all except Deleted.
                  if (_kinds.contains(ItemKind.task))
                    _FilterRow(
                      label: 'Task state',
                      children: <Widget>[
                        for (final TaskStateFilter state
                            in TaskStateFilter.values)
                          FilterChip(
                            label: Text(_stateLabels[state]!),
                            selected: _states.contains(state),
                            onSelected: (bool on) =>
                                setState(() => _toggle(_states, state, on)),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: (ideas.isEmpty && tasks.isEmpty)
                  ? const Center(child: Text('No matches.'))
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      children: <Widget>[
                        for (final Idea idea in ideas) ...<Widget>[
                          _IdeaResult(idea: idea),
                          const Divider(height: 1),
                        ],
                        for (final Task task in tasks) ...<Widget>[
                          _TaskResult(task: task),
                          const Divider(height: 1),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static void _toggle<T>(Set<T> set, T value, bool on) {
    if (on) {
      set.add(value);
    } else {
      set.remove(value);
    }
  }

  /// SEARCH-2's five Task states, labelled as the specification writes them.
  static const Map<TaskStateFilter, String> _stateLabels =
      <TaskStateFilter, String>{
        TaskStateFilter.todo: 'Todo',
        TaskStateFilter.blocked: 'Blocked',
        TaskStateFilter.done: 'Done',
        TaskStateFilter.archived: 'Archived',
        TaskStateFilter.deleted: 'Deleted',
      };
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 4, children: children),
      ],
    ),
  );
}

/// SEARCH-3. "Results use §5.6 rendering with a small kind badge."
class _KindBadge extends StatelessWidget {
  const _KindBadge(this.kind);

  final ItemKind kind;

  @override
  Widget build(BuildContext context) => Text(
    kind == ItemKind.idea ? 'Idea' : 'Task',
    style: Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.primary),
  );
}

class _IdeaResult extends StatelessWidget {
  const _IdeaResult({required this.idea});

  final Idea idea;

  @override
  Widget build(BuildContext context) => ItemRow(
    name: idea.name.value,
    tags: idea.tags,
    badge: const _KindBadge(ItemKind.idea),
    // SEARCH-3. "Tapping a result opens the corresponding Edit screen."
    onOpen: () => context.push(Routes.editIdea(idea.id)),
  );
}

class _TaskResult extends StatelessWidget {
  const _TaskResult({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) => ItemRow(
    name: task.name.value,
    tags: task.tags,
    badge: const _KindBadge(ItemKind.task),
    // SEARCH-3. A deleted or archived Task opens read-only with its one
    // action; the form reads that from the Task rather than from here.
    onOpen: () => context.push(Routes.editTask(task.id)),
    leading: CompletionCircle(status: task.status, onTap: null),
  );
}

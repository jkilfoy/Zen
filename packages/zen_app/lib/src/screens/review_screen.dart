/// §5.5. `SCR-REVIEW`: the two tabs and the top bar they share.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import 'ideas_tab.dart';
import 'todo_tab.dart';

/// §5.5. "The top bar has a back arrow, two tabs `"To Do"` and `"Ideas"`, a
/// search icon and the settings gear."
///
/// REVIEW-4 (v1.9): each tab carries an add button that creates an Item of that
/// tab's kind. REVIEW-5 is what still does not happen here — no subtask
/// creation, and `"Make Task"` is not an add button.
class ReviewScreen extends StatefulWidget {
  /// Opens on [tab], scrolling [highlight] into view if it is on that tab.
  const ReviewScreen({required this.tab, this.highlight, super.key});

  /// REVIEW-2. The tab to open on.
  final ReviewTab tab;

  /// IDEAFORM-4, TASKFORM-8. The id of an Item just created, or `null`.
  final String? highlight;

  /// REVIEW-4. "The list MUST reserve bottom padding at least the button's
  /// height plus its margin, so the button never covers the last row or
  /// TODO-6's `"Archived tasks"` link."
  ///
  /// A Material floating action button is 56 and its margin 16, so 72 is the
  /// floor; the rest is breathing room, and it is the tabs that apply it.
  static const double fabClearance = 88;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 2,
    initialIndex: widget.tab.index,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    // REVIEW-4. The add button is per tab, so the screen rebuilds when the tab
    // changes. `TabController` notifies during the swipe as well as at the end
    // of it, which is what makes the button swap over mid-gesture rather than
    // snapping once the animation finishes.
    _tabs.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  /// REVIEW-4. Which kind the visible tab adds.
  ReviewTab get _visibleTab =>
      ReviewTab.values[_tabs.index.clamp(0, ReviewTab.values.length - 1)];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Review'),
      bottom: TabBar(
        controller: _tabs,
        tabs: const <Widget>[
          Tab(text: 'To Do'),
          Tab(text: 'Ideas'),
        ],
      ),
      actions: <Widget>[
        // REVIEW-1. The search icon and the settings gear.
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          onPressed: () => context.push(Routes.search),
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Settings',
          onPressed: () => context.push(Routes.settings),
        ),
      ],
    ),
    body: SafeArea(
      child: TabBarView(
        controller: _tabs,
        children: <Widget>[
          TodoTab(
            highlight: widget.tab == ReviewTab.todo ? widget.highlight : null,
          ),
          IdeasTab(
            highlight: widget.tab == ReviewTab.ideas ? widget.highlight : null,
          ),
        ],
      ),
    ),
    // REVIEW-4. "a floating action button in the bottom-right of the list
    // area, showing a `+` icon, with the accessibility label `"Add task"` or
    // `"Add idea"` according to the tab."
    //
    // `push`, not `go`: REVIEW-4 requires both save and cancel to return to
    // "the tab the button was pressed from", and pushing keeps this very
    // `ReviewScreen` — with its tab selection and its scroll position —
    // underneath. The save paths land back here through IDEAFORM-4 and
    // TASKFORM-8 as they already did.
    floatingActionButton: switch (_visibleTab) {
      ReviewTab.todo => FloatingActionButton(
        tooltip: 'Add task',
        onPressed: () => context.push(Routes.addTask),
        child: const Icon(Icons.add),
      ),
      ReviewTab.ideas => FloatingActionButton(
        tooltip: 'Add idea',
        onPressed: () => context.push(Routes.addIdea),
        child: const Icon(Icons.add),
      ),
    },
  );
}

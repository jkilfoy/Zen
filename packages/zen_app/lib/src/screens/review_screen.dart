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
/// REVIEW-4: "The Review screen is for reviewing, completing and processing
/// what already exists. It offers no way to author a new Item from blank."
/// There is deliberately no floating action button here.
class ReviewScreen extends StatefulWidget {
  /// Opens on [tab], scrolling [highlight] into view if it is on that tab.
  const ReviewScreen({required this.tab, this.highlight, super.key});

  /// REVIEW-2. The tab to open on.
  final ReviewTab tab;

  /// IDEAFORM-4, TASKFORM-8. The id of an Item just created, or `null`.
  final String? highlight;

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
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

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
  );
}

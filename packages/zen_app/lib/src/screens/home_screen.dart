/// §5.2. `SCR-HOME`.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';

/// §5.2. "The screen has two large regions that together fill the screen: the
/// top half labelled `"Add"` and the bottom half labelled `"Review"`. A gear
/// icon sits in the top-right corner."
///
/// NFR-2: from cold start to a focused name field on Add Idea is two taps —
/// `"Add"` then `"Idea"` — which is why HOME-2 expands in place rather than
/// navigating.
class HomeScreen extends StatefulWidget {
  /// Builds the Home screen.
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// HOME-2. Whether the Add region has expanded into its two buttons.
  bool _addExpanded = false;

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    // HOME-2. "Tapping outside them or pressing Back restores the `"Add"`
    // label." Back collapses the region before it leaves the screen.
    canPop: !_addExpanded,
    onPopInvokedWithResult: (bool didPop, Object? _) {
      if (!didPop && _addExpanded) {
        setState(() => _addExpanded = false);
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Zen'),
        actions: <Widget>[
          // HOME-1, NAV-2.
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: SafeArea(
        // HOME-2. A tap anywhere outside the two buttons collapses the region.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _addExpanded
              ? () => setState(() => _addExpanded = false)
              : null,
          child: Column(
            children: <Widget>[
              Expanded(
                child: _addExpanded ? const _AddChoices() : _addLabel(context),
              ),
              const Divider(height: 1),
              // HOME-4. "Tapping `"Review"` opens the Review screen on the To
              // Do tab."
              Expanded(
                child: _HomeRegion(
                  label: 'Review',
                  onTap: () => context.push(Routes.reviewTab(ReviewTab.todo)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _addLabel(BuildContext context) => _HomeRegion(
    label: 'Add',
    onTap: () => setState(() => _addExpanded = true),
  );
}

/// HOME-2. "Tapping `"Add"` replaces the Add region, in place and without
/// navigating, with two equal buttons: `"Idea"` and `"Task"`."
class _AddChoices extends StatelessWidget {
  const _AddChoices();

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      // HOME-3. Both open a form whose name field is focused.
      Expanded(
        child: _HomeRegion(
          label: 'Idea',
          onTap: () => context.push(Routes.addIdea),
        ),
      ),
      const VerticalDivider(width: 1),
      Expanded(
        child: _HomeRegion(
          label: 'Task',
          onTap: () => context.push(Routes.addTask),
        ),
      ),
    ],
  );
}

/// HOME-1. One of the screen's large tappable regions.
class _HomeRegion extends StatelessWidget {
  const _HomeRegion({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      onTap: onTap,
      child: SizedBox.expand(
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}

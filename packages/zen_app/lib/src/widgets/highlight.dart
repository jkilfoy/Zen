/// IDEAFORM-4. The brief highlight on an Item just added.
library;

import 'package:flutter/material.dart';

/// IDEAFORM-4. "It SHOULD be briefly highlighted."
///
/// A tint that fades out once, on first build. `SHOULD` rather than `MUST`, so
/// this stays deliberately small: one colour, one fade, no sequencing with the
/// scroll that put the row on screen.
class BriefHighlight extends StatefulWidget {
  /// Wraps [child], tinting it when [active].
  const BriefHighlight({required this.active, required this.child, super.key});

  /// How long the tint takes to fade.
  static const Duration duration = Duration(milliseconds: 1200);

  /// Whether this is the highlighted row.
  final bool active;

  /// The row.
  final Widget child;

  @override
  State<BriefHighlight> createState() => _BriefHighlightState();
}

class _BriefHighlightState extends State<BriefHighlight> {
  bool _faded = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      // After the first frame, so the tint is visible before it starts to go.
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (mounted) {
          setState(() => _faded = true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return widget.child;
    }
    return AnimatedContainer(
      duration: BriefHighlight.duration,
      color: _faded
          ? Colors.transparent
          : Theme.of(context).colorScheme.primaryContainer,
      child: widget.child,
    );
  }
}

/// TODO-3, TODO-4, NFR-6. The completion circle.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zen_domain/zen_domain.dart';

import '../providers/app_providers.dart';
import '../theme/decor_pack.dart';

/// TODO-3. The three states of a completion circle, as one widget.
///
/// * `Todo`: empty circle outline.
/// * `Done`: circle with a green checkmark.
/// * `Blocked`: circle filled with a grey ✕.
///
/// TODO-4 and SUB-1: when the parent Task is `Done`, a subtask's circle is
/// rendered "in a visibly disabled state". [locked] is that state; it dims the
/// circle without changing which of the three it draws.
///
/// The colours come from the active [DecorPack], never from a literal, so a
/// later pack changes them without touching this file (DECOR-3).
///
/// NFR-6: "Completion circles expose their state and whether they are locked
/// (e.g. 'Todo, button'; 'Done, locked')." That is [Semantics] below, and it is
/// why the label is built from [status] and [locked] rather than passed in.
class CompletionCircle extends ConsumerWidget {
  /// Draws the circle for [status].
  const CompletionCircle({
    required this.status,
    required this.onTap,
    this.locked = false,
    this.size = 24,
    super.key,
  });

  /// Which of TODO-3's three to draw.
  final TaskStatus status;

  /// SUB-1, TODO-4. Whether the status is locked by a `Done` parent.
  final bool locked;

  /// The circle's diameter in logical pixels.
  final double size;

  /// What a tap does, or `null` where the circle is not tappable (ARCH-2).
  ///
  /// A locked circle still has a callback: SUB-2 says the tap "does nothing"
  /// but SHOULD show a hint, which the caller renders.
  final VoidCallback? onTap;

  /// NFR-6. The state this circle announces.
  static String semanticLabelFor(TaskStatus status, {required bool locked}) {
    final String state = switch (status) {
      TaskStatus.todo => 'Todo',
      TaskStatus.done => 'Done',
      TaskStatus.blocked => 'Blocked',
    };
    return locked ? '$state, locked' : state;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DecorPack decor = ref.watch(activeDecorProvider);
    final Brightness brightness = Theme.of(context).brightness;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: onTap != null,
      enabled: onTap != null && !locked,
      label: semanticLabelFor(status, locked: locked),
      child: InkResponse(
        onTap: onTap,
        radius: size,
        // NFR-6, ROW-5. A 48 × 48 target regardless of the drawn diameter.
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: CustomPaint(
              size: Size.square(size),
              painter: _CirclePainter(
                status: status,
                locked: locked,
                outline: scheme.outline,
                done: decor.doneAccent.of(brightness),
                blocked: decor.blockedAccent.of(brightness),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// TODO-3's three states, drawn as paths rather than glyphs.
///
/// A checkmark and a ✕ drawn from an icon font would make the golden tests of
/// §11.12 depend on font rasterization; as paths they depend only on the
/// rasterizer, which is one fewer thing to differ between machines.
class _CirclePainter extends CustomPainter {
  const _CirclePainter({
    required this.status,
    required this.locked,
    required this.outline,
    required this.done,
    required this.blocked,
  });

  /// SUB-1, TODO-4. How much of its colour a locked circle keeps.
  static const double _lockedOpacity = 0.38;

  final TaskStatus status;
  final bool locked;
  final Color outline;
  final Color done;
  final Color blocked;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset centre = Offset(radius, radius);
    final double stroke = size.width / 12;

    Color dim(Color colour) =>
        locked ? colour.withValues(alpha: _lockedOpacity) : colour;

    switch (status) {
      // "Todo: empty circle outline."
      case TaskStatus.todo:
        canvas.drawCircle(
          centre,
          radius - stroke / 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..color = dim(outline),
        );

      // "Done: circle with a green checkmark."
      case TaskStatus.done:
        canvas.drawCircle(
          centre,
          radius - stroke / 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..color = dim(done),
        );
        canvas.drawPath(
          Path()
            ..moveTo(size.width * 0.28, size.height * 0.52)
            ..lineTo(size.width * 0.44, size.height * 0.68)
            ..lineTo(size.width * 0.73, size.height * 0.34),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke * 1.4
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = dim(done),
        );

      // "Blocked: circle filled with a grey ✕."
      case TaskStatus.blocked:
        canvas.drawCircle(centre, radius, Paint()..color = dim(blocked));
        final Paint cross = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 1.4
          ..strokeCap = StrokeCap.round
          ..color = dim(const Color(0xFFFFFFFF));
        canvas.drawLine(
          Offset(size.width * 0.32, size.height * 0.32),
          Offset(size.width * 0.68, size.height * 0.68),
          cross,
        );
        canvas.drawLine(
          Offset(size.width * 0.68, size.height * 0.32),
          Offset(size.width * 0.32, size.height * 0.68),
          cross,
        );
    }
  }

  @override
  bool shouldRepaint(_CirclePainter old) =>
      old.status != status ||
      old.locked != locked ||
      old.outline != outline ||
      old.done != done ||
      old.blocked != blocked;
}

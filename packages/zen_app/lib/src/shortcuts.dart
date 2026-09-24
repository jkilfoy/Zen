/// HOME-5, §11.7. The desktop keyboard shortcuts, registered once.
///
/// "Desktop shortcuts (HOME-5) are registered with `Shortcuts`/`Actions` at the
/// router level, not per screen."
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';

/// HOME-5. Navigate to a fixed location.
@immutable
class _GoIntent extends Intent {
  const _GoIntent(this.location);

  final String location;
}

/// HOME-5. `Esc` goes back.
@immutable
class _BackIntent extends Intent {
  const _BackIntent();
}

/// HOME-5. "Keyboard shortcuts MUST exist: `Ctrl+I` opens Add Idea, `Ctrl+T`
/// opens Add Task, `Ctrl+R` opens Review, `Ctrl+F` opens Search, `Esc` goes
/// back."
///
/// Wrapped around the whole app rather than around each screen, so there is one
/// place to read and no screen can disagree with another. Bound on both
/// `Control` and `Meta` so the same keys work if this ever runs on macOS; the
/// MVP targets Windows and Android (§11.2).
class ZenShortcuts extends StatelessWidget {
  /// Wraps [child] in the shortcut bindings.
  const ZenShortcuts({required this.child, super.key});

  /// The application below the bindings.
  final Widget child;

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.keyI, control: true):
          const _GoIntent(Routes.addIdea),
      const SingleActivator(LogicalKeyboardKey.keyI, meta: true):
          const _GoIntent(Routes.addIdea),
      const SingleActivator(LogicalKeyboardKey.keyT, control: true):
          const _GoIntent(Routes.addTask),
      const SingleActivator(LogicalKeyboardKey.keyT, meta: true):
          const _GoIntent(Routes.addTask),
      const SingleActivator(LogicalKeyboardKey.keyR, control: true):
          const _GoIntent(Routes.review),
      const SingleActivator(LogicalKeyboardKey.keyR, meta: true):
          const _GoIntent(Routes.review),
      const SingleActivator(LogicalKeyboardKey.keyF, control: true):
          const _GoIntent(Routes.search),
      const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
          const _GoIntent(Routes.search),
      const SingleActivator(LogicalKeyboardKey.escape): const _BackIntent(),
    },
    child: Actions(
      actions: <Type, Action<Intent>>{
        _GoIntent: CallbackAction<_GoIntent>(
          onInvoke: (_GoIntent intent) {
            final BuildContext? nav = rootNavigatorKey.currentContext;
            if (nav != null) {
              GoRouter.of(nav).push(intent.location);
            }
            return null;
          },
        ),
        // NAV-1. `maybePop` rather than `pop`, so that an open dialog closes
        // first and Home — which has nothing to pop — does nothing.
        _BackIntent: CallbackAction<_BackIntent>(
          onInvoke: (_BackIntent intent) {
            unawaited(rootNavigatorKey.currentState?.maybePop());
            return null;
          },
        ),
      },
      child: child,
    ),
  );
}

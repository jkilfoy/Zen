/// The application root: theme, router and shortcuts.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zen_domain/zen_domain.dart' as domain;

import 'providers/app_providers.dart';
import 'router.dart';
import 'shortcuts.dart';
import 'theme/app_theme.dart';
import 'theme/decor_pack.dart';

/// The root widget.
///
/// DECOR-1: the decor supplies both `ThemeData`s and `settings.theme` chooses
/// between them, so neither axis overrides the other. SET-2: both are watched,
/// so a change in Settings applies immediately.
class ZenApp extends ConsumerStatefulWidget {
  /// Builds the app.
  const ZenApp({super.key});

  @override
  ConsumerState<ZenApp> createState() => _ZenAppState();
}

class _ZenAppState extends ConsumerState<ZenApp> {
  // The router is built once: rebuilding it on a theme change would reset the
  // navigation stack.
  late final GoRouter _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    final DecorPack decor = ref.watch(activeDecorProvider);
    final domain.ThemeMode theme = ref.watch(currentSettingsProvider).theme;

    return MaterialApp.router(
      title: 'Zen',
      debugShowCheckedModeBanner: false,
      theme: decorTheme(decor, Brightness.light),
      darkTheme: decorTheme(decor, Brightness.dark),
      themeMode: materialThemeMode(theme),
      routerConfig: _router,
      builder: (BuildContext context, Widget? child) =>
          ZenShortcuts(child: child ?? const SizedBox.shrink()),
    );
  }
}

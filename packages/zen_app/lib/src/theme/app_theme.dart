/// §3.6.1. Turning the active decor pack and the user's theme choice into the
/// two `ThemeData`s `MaterialApp` needs.
library;

import 'package:flutter/material.dart';
import 'package:zen_domain/zen_domain.dart' as domain;

import 'decor_pack.dart';

/// DECOR-1. The light/dark axis, as Flutter spells it.
///
/// The two enums are the same three values; this is the one place they meet, so
/// that no screen has to know both.
ThemeMode materialThemeMode(domain.ThemeMode theme) => switch (theme) {
  domain.ThemeMode.system => ThemeMode.system,
  domain.ThemeMode.light => ThemeMode.light,
  domain.ThemeMode.dark => ThemeMode.dark,
};

/// Builds the theme for [pack] in [brightness].
///
/// DECOR-1: the pack supplies the colours and the brightness comes from the
/// user's independent choice, so neither overrides the other.
ThemeData decorTheme(DecorPack pack, Brightness brightness) {
  final ColorScheme scheme = pack.schemeFor(brightness);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    // NFR-6 and ROW-5 both depend on real touch targets, and Material's
    // density default shrinks them on desktop.
    visualDensity: VisualDensity.standard,
    // §5.6 draws its own dividers between rows (ROW-4); a list tile that adds
    // another one on top reads as a double rule.
    dividerTheme: DividerThemeData(
      space: 1,
      thickness: 1,
      color: scheme.outlineVariant,
    ),
  );
}

/// §3.6.1, §11.7. The decor pack: a named bundle of colour and ornament data.
library;

import 'package:flutter/material.dart';

/// DECOR-2. The optional non-colour parts of a pack.
///
/// DECOR-3 requires packs to be "declarative data (not hard-coded widgets)", so
/// these slots name assets rather than carrying builders. A pack that fills
/// none of them — as `Basic` does — renders the plain default.
@immutable
final class DecorOrnaments {
  /// A set of ornament slots. Every slot is optional.
  const DecorOrnaments({this.backgroundAsset, this.headerOrnamentAsset});

  /// Nothing: the plain default.
  static const DecorOrnaments none = DecorOrnaments();

  /// An image drawn behind the screen's content, or `null` for none.
  final String? backgroundAsset;

  /// An image drawn in the top bar, or `null` for none.
  final String? headerOrnamentAsset;

  @override
  bool operator ==(Object other) =>
      other is DecorOrnaments &&
      other.backgroundAsset == backgroundAsset &&
      other.headerOrnamentAsset == headerOrnamentAsset;

  @override
  int get hashCode => Object.hash(backgroundAsset, headerOrnamentAsset);
}

/// DECOR-2, §11.7. "A `DecorPack` data class holding a light and a dark
/// `ColorScheme` plus optional ornament slots."
///
/// DECOR-1: a pack supplies **both** variants, so choosing one never overrides
/// the user's light/dark choice. DECOR-3: adding "Autumn" later is a new const
/// plus a registry line — no screen changes, which is why the accents below are
/// pack data and not literals in the widgets that draw them.
@immutable
final class DecorPack {
  /// Declares a pack. [id] is what `settings.decor` stores.
  const DecorPack({
    required this.id,
    required this.displayName,
    required this.light,
    required this.dark,
    required this.doneAccent,
    required this.blockedAccent,
    this.ornaments = DecorOrnaments.none,
  });

  /// §3.6. The stored id, e.g. `Basic`.
  final String id;

  /// DECOR-4. What the Settings picker shows, e.g. `"Basic"`.
  final String displayName;

  /// The light variant.
  final ColorScheme light;

  /// The dark variant.
  final ColorScheme dark;

  /// TODO-3. The `Done` checkmark colour — "a green checkmark". One value per
  /// brightness, because green on a dark surface is not green on a light one.
  final DecorAccent doneAccent;

  /// TODO-3. The `Blocked` ✕ colour, by brightness — "filled with a grey ✕".
  final DecorAccent blockedAccent;

  /// DECOR-2's optional slots.
  final DecorOrnaments ornaments;

  /// DECOR-1. The scheme for [brightness], whichever pack is active.
  ColorScheme schemeFor(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// One accent colour in both brightnesses, so DECOR-2's "complete light variant
/// and dark variant" holds for accents as well as for the schemes.
@immutable
final class DecorAccent {
  /// Declares an accent.
  const DecorAccent({required this.light, required this.dark});

  /// The colour on a light surface.
  final Color light;

  /// The colour on a dark surface.
  final Color dark;

  /// The colour for [brightness].
  Color of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  @override
  bool operator ==(Object other) =>
      other is DecorAccent && other.light == light && other.dark == dark;

  @override
  int get hashCode => Object.hash(light, dark);
}

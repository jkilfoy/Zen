/// §3.6.1, §11.7. The decor registry, and the one pack the MVP ships.
library;

import 'package:flutter/material.dart';
import 'package:zen_domain/zen_domain.dart' show Settings;

import 'decor_pack.dart';

/// DECOR-3. The plain default: `id` `Basic`, display name `"Basic"`.
///
/// Both schemes come from one seed, so the light and dark variants are
/// guaranteed to be complete and consistent (DECOR-2). The two accents are
/// named here rather than in the widget that draws them, so that a later pack
/// can change them without touching screen code.
final DecorPack basicDecor = DecorPack(
  id: Settings.basicDecorId,
  displayName: 'Basic',
  light: _basicLight,
  dark: _basicDark,
  doneAccent: const DecorAccent(
    light: Color(0xFF2E7D32),
    dark: Color(0xFF81C784),
  ),
  blockedAccent: const DecorAccent(
    light: Color(0xFF757575),
    dark: Color(0xFF9E9E9E),
  ),
);

final ColorScheme _basicLight = ColorScheme.fromSeed(
  seedColor: const Color(0xFF4A6572),
);

final ColorScheme _basicDark = ColorScheme.fromSeed(
  seedColor: const Color(0xFF4A6572),
  brightness: Brightness.dark,
);

/// §11.7, DECOR-3. Every pack the app knows, keyed by id.
///
/// "The MVP registers exactly one pack, id `Basic`. Adding 'Autumn' later is a
/// new const plus a registry line, which is what DECOR-3 requires."
final class DecorRegistry {
  /// Wraps [packs], which must contain [Settings.basicDecorId].
  DecorRegistry(List<DecorPack> packs)
    : _byId = <String, DecorPack>{
        for (final DecorPack pack in packs) pack.id: pack,
      } {
    assert(
      _byId.containsKey(Settings.basicDecorId),
      'DECOR-3: the Basic pack is the fallback and must always be registered',
    );
  }

  /// The MVP's registry: exactly one pack.
  DecorRegistry.mvp() : this(<DecorPack>[basicDecor]);

  final Map<String, DecorPack> _byId;

  /// DECOR-4. Every pack, for the Settings picker.
  List<DecorPack> get all => List<DecorPack>.unmodifiable(_byId.values);

  /// The pack [id] names, or [basicDecor] if it names none.
  ///
  /// A `settings.decor` written by a newer version — or by a build that had a
  /// pack this one does not — reads as `Basic` rather than crashing the app,
  /// which is the same posture D-M3-12 takes for every other setting.
  DecorPack byId(String id) => _byId[id] ?? basicDecor;
}

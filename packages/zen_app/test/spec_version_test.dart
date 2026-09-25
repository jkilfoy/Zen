/// §5.11, SET-3. The About row names the specification version this build
/// implements, and it has drifted behind `ZEN_SPEC.md` twice — reaching M7 with
/// the spec at v1.14 and the constant still reading `'1.11'`. Both times the
/// constant was simply forgotten, because nothing was comparing it to anything.
///
/// This test is the comparison. It reads the `Document version` row out of the
/// specification's own header table and requires it to equal
/// `SettingsScreen.specVersion`. Bumping the spec without bumping the constant
/// now fails here and in CI, which is the only place a fix of this kind holds:
/// a convention that says "remember to update it" is what failed twice.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zen_app/src/screens/settings_screen.dart';

void main() {
  test('SET-3: specVersion matches the Document version row in ZEN_SPEC.md', () {
    // `flutter test` runs with the package directory as the working directory,
    // so the repository root is two levels up. Asserting the file exists keeps a
    // moved spec from presenting as a version mismatch.
    final File spec = File('../../ZEN_SPEC.md');
    expect(
      spec.existsSync(),
      isTrue,
      reason:
          'ZEN_SPEC.md was not found at ${spec.absolute.path}. If the layout '
          'changed, fix this path rather than deleting the check.',
    );

    // The header is a two-column Markdown table: `| Document version | 1.15 |`.
    final RegExp row = RegExp(
      r'^\|\s*Document version\s*\|\s*([0-9]+\.[0-9]+)\s*\|',
      multiLine: true,
    );
    final RegExpMatch? match = row.firstMatch(spec.readAsStringSync());
    expect(
      match,
      isNotNull,
      reason:
          'No `| Document version | x.y |` row in ZEN_SPEC.md. The header table '
          'is where SET-3 takes its number from.',
    );

    expect(
      SettingsScreen.specVersion,
      match!.group(1),
      reason:
          'ZEN_SPEC.md is at v${match.group(1)} but SettingsScreen.specVersion '
          'reads ${SettingsScreen.specVersion}, so the About row reports the '
          'wrong specification version. Update the constant in '
          'lib/src/screens/settings_screen.dart.',
    );
  });
}

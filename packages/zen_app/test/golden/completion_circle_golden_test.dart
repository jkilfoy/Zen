/// §11.12 item 6. Golden tests for TODO-3's three completion-circle states
/// plus their disabled variants, "since those are visual specifications".
///
/// **These run on Windows only (D-M4-8).** Goldens are platform-sensitive;
/// `ci.yaml` runs on `ubuntu-latest` and the images here can only be generated
/// on the owner's machine, so committing one set would mean failing every push.
/// They are skipped elsewhere with the reason given, and they run in
/// `tools/verify.ps1`, which is what is run before every commit.
///
/// D-M4-7 is what keeps them meaningful at all: the checkmark and the ✕ are
/// drawn as paths rather than glyphs, so these images depend on the rasterizer
/// and not on which fonts the machine has.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_app/src/providers/app_providers.dart';
import 'package:zen_app/src/theme/app_theme.dart';
import 'package:zen_app/src/theme/decor_registry.dart';
import 'package:zen_app/src/widgets/completion_circle.dart';
import 'package:zen_domain/zen_domain.dart';

/// The boundary the golden captures: the circle alone, not the screen.
const Key circleKey = Key('completion-circle');

void main() {
  /// One circle on a plain surface, at a size a golden can be read at.
  ///
  /// The settings are overridden because the circle reads the active
  /// `DecorPack` through them (§11.7), and `main.dart` is what normally
  /// supplies them.
  Widget circle(TaskStatus status, {required bool locked}) => ProviderScope(
    overrides: [initialSettingsProvider.overrideWithValue(Settings())],
    child: MaterialApp(
      theme: decorTheme(basicDecor, Brightness.light),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: circleKey,
            child: ColoredBox(
              color: basicDecor.light.surface,
              child: CompletionCircle(
                status: status,
                locked: locked,
                size: 48,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// TODO-3's three states, each in its ordinary and its TODO-4 locked form.
  const Map<TaskStatus, String> states = <TaskStatus, String>{
    TaskStatus.todo: 'todo',
    TaskStatus.done: 'done',
    TaskStatus.blocked: 'blocked',
  };

  for (final MapEntry<TaskStatus, String> state in states.entries) {
    for (final bool locked in <bool>[false, true]) {
      final String variant = locked ? '${state.value}_locked' : state.value;

      testWidgets(
        'TODO-3: the $variant completion circle',
        (WidgetTester tester) async {
          await tester.pumpWidget(circle(state.key, locked: locked));
          await tester.pumpAndSettle();

          await expectLater(
            find.byKey(circleKey),
            matchesGoldenFile('goldens/circle_$variant.png'),
          );
        },
        // D-M4-8. `testWidgets` takes a bool here, so the reason is in this
        // library's doc comment rather than in the runner's output.
        skip: !Platform.isWindows,
      );
    }
  }
}

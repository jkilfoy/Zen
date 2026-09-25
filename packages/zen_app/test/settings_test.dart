/// §5.11. `SCR-SETTINGS`, and §3.6.1's two independent axes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_app/src/screens/settings_screen.dart';
import 'package:zen_app/src/theme/decor_pack.dart';
import 'package:zen_app/src/theme/decor_registry.dart';
import 'package:zen_domain/zen_domain.dart' as domain;
import 'package:zen_domain/zen_domain.dart' show Settings, Timeframe;

import 'support/harness.dart';

void main() {
  /// Opens Settings through the gear on the Home screen (NAV-2).
  Future<void> openSettings(WidgetTester tester, ZenHarness harness) async {
    await harness.pumpApp(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
  }

  testWidgets('SET-1: every setting in §3.6 has a control', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await openSettings(tester, harness);

    expect(find.text('Default idea timeframe'), findsOneWidget);
    expect(find.text('Idea groups expanded by default'), findsOneWidget);
    expect(find.text('Strike through completed items'), findsOneWidget);
    expect(find.text('Confirm before deleting'), findsOneWidget);
    expect(find.text('End of day'), findsOneWidget);
    // "presented as two separate controls under an `"Appearance"` heading"
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Decor'), findsOneWidget);
    // SET-4.
    expect(find.text('Sync'), findsOneWidget);
    // SET-3.
    expect(find.text('About'), findsOneWidget);
  });

  testWidgets('SET-2: a change applies immediately and persists', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await openSettings(tester, harness);

    expect((await harness.settings.read()).strikethroughDone, isTrue);

    await tapItem(
      tester,
      find.widgetWithText(SwitchListTile, 'Strike through completed items'),
    );

    // No Save button: the write happens on change.
    expect((await harness.settings.read()).strikethroughDone, isFalse);
  });

  testWidgets('SET-2, TODO-3: turning strikethrough off changes the list', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await harness.settings.write(Settings(strikethroughDone: false));
    await seedTask(harness, name: 'Ship it', status: domain.TaskStatus.done);
    await harness.pumpApp(tester);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    final Text name = tester.widget<Text>(find.text('Ship it'));
    expect(name.style?.decoration, isNot(TextDecoration.lineThrough));
  });

  testWidgets('SET-1, §3.2: the default idea timeframe reaches the Add form', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await openSettings(tester, harness);

    await tapItem(
      tester,
      find.descendant(
        of: find.byType(SegmentedButton<Timeframe>),
        matching: find.text('Later'),
      ),
    );
    expect(
      (await harness.settings.read()).defaultIdeaTimeframe,
      Timeframe.later,
    );

    // §3.2. "Timeframe preselected on the Add Idea screen."
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Idea'));
    await tester.pumpAndSettle();

    final SegmentedButton<Timeframe> picker = tester
        .widget<SegmentedButton<Timeframe>>(
          find.byType(SegmentedButton<Timeframe>),
        );
    expect(picker.selected, <Timeframe>{Timeframe.later});
  });

  testWidgets('SET-1, IDEAS-2: the expanded-groups checklist reaches the tab', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await seedIdea(
      harness,
      name: 'Someday thing',
      timeframe: Timeframe.distant,
    );
    await openSettings(tester, harness);

    // §3.6's factory default leaves Distant collapsed; tick it.
    await tapItem(tester, find.widgetWithText(CheckboxListTile, 'Distant'));
    expect(
      (await harness.settings.read()).expandedIdeaGroups,
      contains(Timeframe.distant),
    );

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ideas'));
    await tester.pumpAndSettle();

    expect(find.text('Someday thing'), findsOneWidget);
  });

  testWidgets('DECOR-1: theme and decor are independent axes', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await openSettings(tester, harness);

    await tapItem(
      tester,
      find.descendant(
        of: find.byType(SegmentedButton<domain.ThemeMode>),
        matching: find.text('Dark'),
      ),
    );

    final Settings stored = await harness.settings.read();
    expect(stored.theme, domain.ThemeMode.dark);
    // "Choosing a decor MUST NOT override the user's light/dark choice", and
    // the converse: choosing a theme leaves the decor alone.
    expect(stored.decor, Settings.basicDecorId);

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.themeMode, ThemeMode.dark);
    // DECOR-2. Both variants are supplied, whichever theme is chosen.
    expect(app.theme?.brightness, Brightness.light);
    expect(app.darkTheme?.brightness, Brightness.dark);
  });

  testWidgets(
    'DECOR-3, DECOR-4: the MVP ships exactly one pack, and shows it',
    (WidgetTester tester) async {
      final ZenHarness harness = ZenHarness();
      await openSettings(tester, harness);

      final DecorRegistry registry = DecorRegistry.mvp();
      expect(registry.all.length, 1);
      expect(registry.all.single.id, Settings.basicDecorId);
      expect(registry.all.single.displayName, 'Basic');

      // "The Settings screen shows the decor picker even with one option."
      expect(find.byType(DropdownButton<String>), findsOneWidget);
      expect(find.text('Basic'), findsWidgets);
    },
  );

  testWidgets('DECOR-3: an unknown decor id falls back to Basic', (
    WidgetTester tester,
  ) async {
    // A `settings.decor` written by a build that had a pack this one does not
    // must not crash the app; D-M3-12 takes the same posture for every setting.
    final DecorRegistry registry = DecorRegistry.mvp();
    final DecorPack pack = registry.byId('Autumn');

    expect(pack.id, Settings.basicDecorId);
  });

  testWidgets('SET-3: About names the app version and the spec version', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await openSettings(tester, harness);

    expect(
      find.textContaining(
        'specification v${SettingsScreen.specVersion}',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('SET-4: the Sync section is present and wired', (
    WidgetTester tester,
  ) async {
    // D-M4-9 left this section's controls disabled under a line saying sync was
    // not built yet. M6 built it. What the section *does* is covered in
    // `sync_settings_test.dart`; this only holds SET-4's place on the screen,
    // beside the other settings sections.
    final ZenHarness harness = ZenHarness();
    await openSettings(tester, harness);

    expect(find.text('Sync now'), findsOneWidget);
    expect(
      find.text('Sync is not built yet. Your data stays on this device.'),
      findsNothing,
    );
  });

  testWidgets('EOD-1: the end-of-day row shows the stored time', (
    WidgetTester tester,
  ) async {
    final ZenHarness harness = ZenHarness();
    await harness.settings.write(
      Settings(endOfDay: const domain.LocalTime(3, 30)),
    );
    await openSettings(tester, harness);

    expect(find.text('03:30'), findsOneWidget);
  });
}

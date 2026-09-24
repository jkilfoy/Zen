/// §5.11. `SCR-SETTINGS`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zen_domain/zen_domain.dart' as domain;
import 'package:zen_domain/zen_domain.dart' show LocalTime, Settings, Timeframe;

import '../providers/app_providers.dart';
import '../theme/decor_pack.dart';
import '../theme/decor_registry.dart';
import 'idea_form_screen.dart' show TimeframePicker;

/// §5.11. "Lists every setting in §3.6 with an appropriate control."
///
/// SET-2: "Changes apply immediately and persist." Every control writes through
/// [SettingsRepository] on change; there is no Save button, and no local copy
/// that could drift from the stored one.
class SettingsScreen extends ConsumerWidget {
  /// Builds the screen.
  const SettingsScreen({super.key});

  /// SET-3. The specification version this build implements.
  ///
  /// Read from the document's own header when it changes; the app version comes
  /// from the package metadata.
  static const String specVersion = '1.9';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Settings settings = ref.watch(currentSettingsProvider);
    final DecorRegistry registry = ref.watch(decorRegistryProvider);

    Future<void> write(Settings next) =>
        ref.read(settingsRepositoryProvider).write(next);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: <Widget>[
            // SET-1. Timeframe picker (`defaultIdeaTimeframe`).
            _Section(
              title: 'Default idea timeframe',
              child: TimeframePicker(
                value: settings.defaultIdeaTimeframe,
                onChanged: (Timeframe next) =>
                    write(settings.copyWith(defaultIdeaTimeframe: next)),
              ),
            ),
            // SET-1. Checklist of the four timeframes (`expandedIdeaGroups`).
            _Section(
              title: 'Idea groups expanded by default',
              child: Column(
                children: <Widget>[
                  for (final Timeframe timeframe in Timeframe.values)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(TimeframePicker.labels[timeframe]!),
                      value: settings.expandedIdeaGroups.contains(timeframe),
                      onChanged: (bool? on) {
                        final Set<Timeframe> next = <Timeframe>{
                          ...settings.expandedIdeaGroups,
                        };
                        if (on ?? false) {
                          next.add(timeframe);
                        } else {
                          next.remove(timeframe);
                        }
                        unawaited(
                          write(settings.copyWith(expandedIdeaGroups: next)),
                        );
                      },
                    ),
                ],
              ),
            ),
            // SET-1. Toggles.
            SwitchListTile(
              title: const Text('Strike through completed items'),
              value: settings.strikethroughDone,
              onChanged: (bool on) =>
                  write(settings.copyWith(strikethroughDone: on)),
            ),
            SwitchListTile(
              title: const Text('Confirm before deleting'),
              value: settings.confirmDestructive,
              onChanged: (bool on) =>
                  write(settings.copyWith(confirmDestructive: on)),
            ),
            // SET-1. Time picker (`endOfDay`).
            ListTile(
              title: const Text('End of day'),
              subtitle: Text(
                '${settings.endOfDay.format()} — tasks completed before this '
                'time belong to the previous day',
              ),
              trailing: Text(settings.endOfDay.format()),
              onTap: () async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: settings.endOfDay.hour,
                    minute: settings.endOfDay.minute,
                  ),
                );
                if (picked != null) {
                  // EOD-4. "Changing `endOfDay` applies to future sweeps only."
                  // The scheduler re-reads the setting on its next sweep, so
                  // nothing here needs to reach for it.
                  await write(
                    settings.copyWith(
                      endOfDay: LocalTime(picked.hour, picked.minute),
                    ),
                  );
                }
              },
            ),
            // SET-1. "Theme picker and Decor picker, presented as two separate
            // controls under an `"Appearance"` heading." DECOR-1: two axes.
            _Section(
              title: 'Appearance',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Theme'),
                  const SizedBox(height: 4),
                  SegmentedButton<domain.ThemeMode>(
                    segments: const <ButtonSegment<domain.ThemeMode>>[
                      ButtonSegment<domain.ThemeMode>(
                        value: domain.ThemeMode.system,
                        label: Text('System'),
                      ),
                      ButtonSegment<domain.ThemeMode>(
                        value: domain.ThemeMode.light,
                        label: Text('Light'),
                      ),
                      ButtonSegment<domain.ThemeMode>(
                        value: domain.ThemeMode.dark,
                        label: Text('Dark'),
                      ),
                    ],
                    selected: <domain.ThemeMode>{settings.theme},
                    showSelectedIcon: false,
                    onSelectionChanged: (Set<domain.ThemeMode> next) =>
                        write(settings.copyWith(theme: next.single)),
                  ),
                  const SizedBox(height: 16),
                  const Text('Decor'),
                  const SizedBox(height: 4),
                  // DECOR-4. "The Settings screen shows the decor picker even
                  // with one option."
                  DropdownButton<String>(
                    value: registry.byId(settings.decor).id,
                    items: <DropdownMenuItem<String>>[
                      for (final DecorPack pack in registry.all)
                        DropdownMenuItem<String>(
                          value: pack.id,
                          child: Text(pack.displayName),
                        ),
                    ],
                    onChanged: (String? id) {
                      if (id != null) {
                        unawaited(write(settings.copyWith(decor: id)));
                      }
                    },
                  ),
                ],
              ),
            ),
            // SET-4. The sync section, whose transports arrive in M6 and M7.
            const _SyncSection(),
            const Divider(),
            // SET-3. "A read-only `"About"` row shows the app version and this
            // spec's version number."
            const _AboutRow(),
          ],
        ),
      ),
    );
  }
}

/// SET-4. "A `"Sync"` section holds the sync settings and actions. It is
/// specified in §11.8."
///
/// Every control §11.8 names — the two transport toggles, the folder picker,
/// pairing, `"Sync now"`, the snapshot import and export — belongs to
/// `zen_sync`, which M6 and M7 build. The section is present and says so rather
/// than being omitted, because a missing section reads as a feature that was
/// forgotten. Recorded in `DECISIONS.md`, D-M4-9.
class _SyncSection extends StatelessWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context) => _Section(
    title: 'Sync',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text('Sync through a shared folder'),
          value: false,
          onChanged: null,
        ),
        const SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text('Sync over the local network'),
          value: false,
          onChanged: null,
        ),
        const SizedBox(height: 8),
        Text(
          'Sync is not built yet. Your data stays on this device.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

/// SET-3. The About row.
class _AboutRow extends StatelessWidget {
  const _AboutRow();

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
    future: PackageInfo.fromPlatform(),
    builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
      final String version = snapshot.data == null
          ? '…'
          : '${snapshot.data!.version}+${snapshot.data!.buildNumber}';
      return ListTile(
        title: const Text('About'),
        subtitle: Text(
          'Zen $version · specification v${SettingsScreen.specVersion}',
        ),
      );
    },
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

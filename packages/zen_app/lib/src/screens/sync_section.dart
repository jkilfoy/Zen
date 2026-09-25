/// SET-4, §11.8. The Settings screen's `"Sync"` section.
///
/// Its own file because `settings_screen.dart` was already near §11.11's
/// four-hundred-line guide before this arrived.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zen_domain/zen_domain.dart';
import 'package:zen_sync/zen_sync.dart';

import '../providers/app_providers.dart';
import '../providers/sync_actions.dart';
import '../widgets/lan_sync_block.dart';
import '../providers/sync_providers.dart';
import '../widgets/confirmations.dart';

/// SET-4. "A `"Sync"` section holds the sync settings and actions. It is
/// specified in §11.8."
///
/// §11.8 lists what it shows: "each transport's toggle and status, the folder
/// picker, the pairing flow, the paired-device list with an unpair action,
/// `"Sync now"`, the last sync time and result, `"Export snapshot…"`,
/// `"Import snapshot…"`, and `"Restore from backup…"`." The pairing flow and
/// the paired-device list are `LanSyncBlock`'s, because §11.6.4's two roles
/// make that part of the section read differently on each platform and this
/// file is already near §11.11's four-hundred-line guide.
class SyncSection extends ConsumerWidget {
  /// Builds the section.
  const SyncSection({super.key});

  /// §11.8. The intervals the picker offers. `0` is the spec's "disables".
  static const List<int> intervalChoices = <int>[0, 5, 15, 30, 60];

  /// Vertical space between the rule above `"Sync now"` and the button.
  ///
  /// Named so the widget test can assert the same number the layout uses, which
  /// is what stops the two drifting apart.
  static const double dividerToButtonGap = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Settings settings = ref.watch(currentSettingsProvider);
    final SyncState sync = ref.watch(syncControllerProvider);
    final SyncController controller = ref.read(syncControllerProvider.notifier);
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // §11.8, `syncFolderEnabled`.
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Sync through a shared folder'),
          subtitle: Text(settings.syncFolderLocation ?? 'No folder chosen yet'),
          value: settings.syncFolderEnabled,
          // Enabling with no folder chosen would switch on a transport that
          // cannot do anything, so the toggle waits for the folder.
          onChanged: settings.syncFolderLocation == null
              ? null
              : (bool on) => controller.update(
                  (Settings s) => s.copyWith(syncFolderEnabled: on),
                ),
        ),
        Row(
          children: <Widget>[
            TextButton(
              onPressed: () async {
                if (await controller.chooseFolder()) {
                  await controller.update(
                    (Settings s) => s.copyWith(syncFolderEnabled: true),
                  );
                }
              },
              child: Text(
                settings.syncFolderLocation == null
                    ? 'Choose folder…'
                    : 'Change folder…',
              ),
            ),
            if (settings.syncFolderLocation != null)
              TextButton(
                onPressed: controller.forgetFolder,
                child: const Text('Forget folder'),
              ),
          ],
        ),

        // §11.8, `syncLanEnabled`, and §11.6.4's pairing flow.
        const LanSyncBlock(),

        const Divider(),

        // §11.8, `syncOnForeground`.
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Sync when Zen opens'),
          value: settings.syncOnForeground,
          onChanged: (bool on) => controller.update(
            (Settings s) => s.copyWith(syncOnForeground: on),
          ),
        ),

        // §11.8, `syncIntervalMinutes`.
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Sync every'),
          trailing: DropdownButton<int>(
            value: intervalChoices.contains(settings.syncIntervalMinutes)
                ? settings.syncIntervalMinutes
                : null,
            hint: Text('${settings.syncIntervalMinutes} minutes'),
            items: <DropdownMenuItem<int>>[
              for (final int minutes in intervalChoices)
                DropdownMenuItem<int>(
                  value: minutes,
                  child: Text(minutes == 0 ? 'Never' : '$minutes minutes'),
                ),
            ],
            onChanged: (int? minutes) => minutes == null
                ? null
                : controller.update(
                    (Settings s) => s.copyWith(syncIntervalMinutes: minutes),
                  ),
          ),
        ),

        const Divider(),
        // A `Divider` leaves only its own 8 px below the rule, and unlike the
        // text-only buttons further down, `"Sync now"` is filled — so its
        // surface reads as touching the rule at that distance. The gap is
        // asserted in `sync_settings_test.dart` rather than eyeballed (D-M5-6).
        const SizedBox(height: dividerToButtonGap),

        // §11.8, `"Sync now"` plus "the last sync time and result".
        Row(
          children: <Widget>[
            FilledButton.tonal(
              onPressed: sync.running ? null : controller.syncNow,
              child: const Text('Sync now'),
            ),
            const SizedBox(width: 12),
            if (sync.running)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(_status(settings.lastSyncAt, sync.message), style: text.bodySmall),

        const Divider(),

        // §11.8's three file actions.
        TextButton(
          onPressed: () => _export(context, ref),
          child: const Text('Export snapshot…'),
        ),
        TextButton(
          onPressed: () => _import(context, ref),
          child: const Text('Import snapshot…'),
        ),
        TextButton(
          onPressed: () => _restore(context, ref),
          child: const Text('Restore from backup…'),
        ),
      ],
    );
  }

  /// §11.8. "The last sync time and result."
  static String _status(DateTime? lastSyncAt, String? message) {
    final String when = lastSyncAt == null
        ? 'Not synced yet'
        : 'Last synced ${DateFormat.yMMMd().add_jm().format(lastSyncAt.toLocal())}';
    return message == null ? when : '$when · $message';
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final SyncController controller = ref.read(syncControllerProvider.notifier);
    final String replicaId = await ref
        .read(replicaRepositoryProvider)
        .replicaId();
    final String contents = await controller.exportSnapshot();
    final String? written = await ref
        .read(snapshotFileExchangeProvider)
        .write(FileSnapshotTransport.snapshotFileName(replicaId), contents);
    if (context.mounted && written != null) {
      _say(context, 'Exported to $written.');
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final String? contents = await ref
        .read(snapshotFileExchangeProvider)
        .read();
    if (contents == null) {
      return;
    }
    // No confirmation: §11.8 makes an import a merge, which adds and reconciles
    // but never replaces, and it takes a pre-merge backup on the way through.
    // The destructive action in this section is the restore below, and that one
    // asks.
    final String result = await ref
        .read(syncControllerProvider.notifier)
        .importSnapshot(contents);
    if (context.mounted) {
      _say(context, result);
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final SyncController controller = ref.read(syncControllerProvider.notifier);
    final List<BackupEntry> backups = await controller.backups();
    if (!context.mounted) {
      return;
    }
    if (backups.isEmpty) {
      _say(
        context,
        'There are no backups yet. Zen writes one before it merges.',
      );
      return;
    }

    final BackupEntry? chosen = await showDialog<BackupEntry>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: const Text('Restore from backup'),
        children: <Widget>[
          for (final BackupEntry entry in backups)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(entry),
              child: Text(
                DateFormat.yMMMd().add_jm().format(entry.takenAt.toLocal()),
              ),
            ),
        ],
      ),
    );
    if (chosen == null || !context.mounted) {
      return;
    }

    // §11.6.6: "restores one … after an explicit confirmation". This is the one
    // replace in the app, and it is not undoable.
    final bool confirmed = await confirmDestructiveAction(
      context: context,
      title: 'Restore this backup?',
      message:
          'Every idea and task on this device will be replaced by the backup '
          'from ${DateFormat.yMMMd().add_jm().format(chosen.takenAt.toLocal())}. '
          'This cannot be undone.',
      confirmLabel: 'Restore',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final String result = await controller.restore(chosen);
    if (context.mounted) {
      _say(context, result);
    }
  }

  /// NFR-1: "a sync failure is never surfaced as a blocking dialog". A snack bar
  /// reports and gets out of the way.
  static void _say(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
}

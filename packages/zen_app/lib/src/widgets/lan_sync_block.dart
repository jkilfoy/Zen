/// §11.6.4, §11.8. The LAN transport's part of the Settings `"Sync"` section.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zen_domain/zen_domain.dart';

import '../providers/app_providers.dart';
import '../providers/lan_controller.dart';
import '../providers/sync_actions.dart';
import '../providers/sync_providers.dart';
import '../router.dart';
import 'confirmations.dart';

/// §11.8. "Each transport's toggle and status … the pairing flow, the
/// paired-device list with an unpair action."
///
/// **It reads differently on each platform, because §11.6.4's roles differ.**
/// The desktop serves: it shows whether it is listening, on what port, and a
/// "Pair a device" button that displays a code. The phone dials: it shows the
/// paired PCs and a "Pair with a PC" button that opens the scanner. Neither
/// pretends to be the other, and the limitation §11.6.4 asks to be documented —
/// "Open Zen on your PC to sync" — is stated on the phone, where it bites.
class LanSyncBlock extends ConsumerWidget {
  /// Builds the block.
  const LanSyncBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Settings settings = ref.watch(currentSettingsProvider);
    final LanState lan = ref.watch(lanControllerProvider);
    final TextTheme text = Theme.of(context).textTheme;
    final bool client = ref.watch(isLanClientProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Sync over the local network'),
          subtitle: Text(_status(settings, lan, client)),
          value: settings.syncLanEnabled,
          onChanged: (bool on) => ref
              .read(syncControllerProvider.notifier)
              .update((Settings s) => s.copyWith(syncLanEnabled: on)),
        ),
        if (settings.syncLanEnabled) ...<Widget>[
          Row(
            children: <Widget>[
              TextButton(
                onPressed: () => context.push(
                  client ? Routes.pairWithPc : Routes.pairDevice,
                ),
                child: Text(client ? 'Pair with a PC' : 'Pair a device'),
              ),
            ],
          ),
          if (settings.syncLanPeers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                client
                    ? 'No PC paired yet.'
                    : 'No devices paired yet. Pair one to sync over Wi-Fi.',
                style: text.bodySmall,
              ),
            )
          else
            for (final LanPeer peer in settings.syncLanPeers)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(peer.deviceName),
                // The desktop's records carry no address (§11.6.4 step 4), so
                // there is nothing to show there and the row says so rather
                // than printing ":0".
                subtitle: peer.host.isEmpty
                    ? null
                    : Text('${peer.host}:${peer.port}'),
                trailing: TextButton(
                  onPressed: () => _unpair(context, ref, peer),
                  child: const Text('Unpair'),
                ),
              ),
        ],
      ],
    );
  }

  /// §11.8. "Each transport's … status."
  static String _status(Settings settings, LanState lan, bool client) {
    if (!settings.syncLanEnabled) {
      return client
          ? 'Sync directly with your PC over Wi-Fi.'
          : 'Let your phone sync with this PC over Wi-Fi.';
    }
    if (client) {
      // §11.6.4: "Document this in the UI ('Open Zen on your PC to sync')."
      return settings.syncLanPeers.isEmpty
          ? 'Pair with your PC to start.'
          : 'Open Zen on your PC to sync.';
    }
    if (lan.error case final String error) {
      return error;
    }
    return lan.listening
        ? 'Listening on port ${lan.port}. Keep Zen open on this PC.'
        : 'Starting…';
  }

  Future<void> _unpair(
    BuildContext context,
    WidgetRef ref,
    LanPeer peer,
  ) async {
    final bool confirmed = await confirmDestructiveAction(
      context: context,
      title: 'Unpair ${peer.deviceName}?',
      // Stated rather than glossed: unpairing is one-sided, and a user who
      // expects it to be mutual would leave the other device holding a key and
      // wonder why its list still shows this one.
      message:
          'This device will stop syncing with ${peer.deviceName}. Unpair it on '
          '${peer.deviceName} as well, or pair again from scratch to resume.',
      confirmLabel: 'Unpair',
    );
    if (confirmed) {
      await ref.read(lanControllerProvider.notifier).unpair(peer.replicaId);
    }
  }
}

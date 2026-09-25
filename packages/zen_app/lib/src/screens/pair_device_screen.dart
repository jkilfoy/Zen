/// §11.6.4 step 1. The desktop's "Pair a device" screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zen_sync/zen_sync.dart';

import '../providers/lan_controller.dart';

/// §11.6.4 step 1. "Opens a 5-minute pairing window, generates a single-use
/// 6-digit code, and displays both a QR code and the code with the host and
/// port in text."
///
/// The text is not a fallback for a camera that will not focus. §11.6.4 makes
/// the manual path first-class — "a manual host:port entry is mandatory, not
/// optional" — because mDNS and cameras both fail on real networks and in real
/// rooms, so the host, the port and the code are all shown large enough to read
/// across a desk.
class PairDeviceScreen extends ConsumerStatefulWidget {
  /// Builds the screen.
  const PairDeviceScreen({super.key});

  @override
  ConsumerState<PairDeviceScreen> createState() => _PairDeviceScreenState();
}

class _PairDeviceScreenState extends ConsumerState<PairDeviceScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the screen opens the window: the user asked to pair, and a
    // screen showing no code with a button to produce one is a step that
    // exists only because it was easier to build.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(lanControllerProvider.notifier).openPairingWindow(),
    );
  }

  @override
  void dispose() {
    // Leaving the screen closes the window. A live code behind a closed screen
    // is a credential nobody is watching.
    ref.read(lanControllerProvider.notifier).closePairingWindow();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LanState lan = ref.watch(lanControllerProvider);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Pair a device')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: switch (lan) {
              LanState(listening: false, error: final String? error) =>
                _notListening(theme, error),
              LanState(invitation: final LanPairingInvitation? invitation)
                  when invitation != null =>
                _invitation(theme, invitation),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ),
      ),
    );
  }

  Widget _notListening(ThemeData theme, String? error) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        error ?? 'Turn on "Sync over the local network" in Settings first.',
        style: theme.textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
    ],
  );

  Widget _invitation(
    ThemeData theme,
    LanPairingInvitation invitation,
  ) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(
        'On your phone, open Zen ▸ Settings ▸ Sync ▸ "Pair with a PC".',
        style: theme.textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: QrImageView(
          // Deliberately `QrVersions.auto`: the payload's length varies with
          // the device name, and a fixed version would fail on a long one.
          data: invitation.toPayload(),
          version: QrVersions.auto,
          size: 220,
          backgroundColor: Colors.white,
        ),
      ),
      const SizedBox(height: 24),
      Text(
        'Or type these in:',
        style: theme.textTheme.titleSmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      _row(theme, 'Address', '${invitation.host}:${invitation.port}'),
      _row(theme, 'Code', invitation.code),
      const SizedBox(height: 16),
      Text(
        'The code works once, and for five minutes. If this PC has more than '
        'one network address, the one above is a guess — try another from '
        'your network settings if the phone cannot reach it.',
        style: theme.textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    ],
  );

  Widget _row(ThemeData theme, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text('$label  ', style: theme.textTheme.bodyMedium),
        SelectableText(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            letterSpacing: 2,
          ),
        ),
      ],
    ),
  );
}

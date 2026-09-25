/// §11.6.4 steps 2–4. The phone's "Pair with a PC" screen.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:zen_sync/zen_sync.dart';

import '../providers/lan_controller.dart';

/// §11.6.4 step 2. "Scans the QR (`mobile_scanner`) or types host, port and
/// code."
///
/// **Neither path pairs without a confirmation.** §11.6.4: "before sending the
/// code the phone displays the host, port and device name it is about to pair
/// with, and requires an explicit confirmation" — because a QR naming an
/// attacker's host would otherwise yield "a code, an attacker-chosen key, and
/// the phone posting its entire dataset there on every pass". Strict parsing
/// cannot see that; a person looking at an address can.
class PairScanScreen extends ConsumerStatefulWidget {
  /// Builds the screen.
  const PairScanScreen({super.key});

  @override
  ConsumerState<PairScanScreen> createState() => _PairScanScreenState();
}

class _PairScanScreenState extends ConsumerState<PairScanScreen> {
  final TextEditingController _host = TextEditingController();
  final TextEditingController _port = TextEditingController(
    text: '$lanDefaultPort',
  );
  final TextEditingController _code = TextEditingController();
  MobileScannerController? _scanner;

  /// True while a confirmation is up or a pairing is in flight, so a camera
  /// that keeps firing cannot stack dialogs.
  bool _busy = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    // `mobile_scanner` has no Windows implementation, and the desktop is the
    // server anyway (§11.6.4): there is nothing for it to scan.
    if (Platform.isAndroid) {
      _scanner = MobileScannerController(
        formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
      );
    }
  }

  @override
  void dispose() {
    unawaited(_scanner?.dispose());
    _host.dispose();
    _port.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Pair with a PC')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            'On your PC, open Zen ▸ Settings ▸ Sync ▸ "Pair a device".',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          if (_scanner case final MobileScannerController scanner)
            SizedBox(
              height: 260,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MobileScanner(
                  controller: scanner,
                  onDetect: _onDetect,
                  // A camera that cannot start is not a failure of pairing:
                  // everything below still works.
                  errorBuilder:
                      (
                        BuildContext context,
                        MobileScannerException e,
                      ) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'The camera is unavailable. Type the address and '
                            'code below instead.',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text('Or type what the PC shows:', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _host,
            decoration: const InputDecoration(
              labelText: 'Address',
              hintText: '192.168.1.20',
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _port,
            decoration: const InputDecoration(labelText: 'Port'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _code,
            decoration: const InputDecoration(labelText: 'Code'),
            keyboardType: TextInputType.number,
            maxLength: LanPairing.codeDigits,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _pairFromForm,
            child: const Text('Pair'),
          ),
          if (_problem case final String problem) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              problem,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// §11.6.4. A scanned payload, treated as hostile until the user agrees.
  void _onDetect(BarcodeCapture capture) {
    if (_busy) {
      return;
    }
    for (final Barcode barcode in capture.barcodes) {
      final String? raw = barcode.rawValue;
      final LanPairingInvitation? invitation = raw == null
          ? null
          : LanPairingInvitation.parse(raw);
      if (invitation != null) {
        unawaited(
          _confirmThenPair(
            host: invitation.host,
            port: invitation.port,
            code: invitation.code,
          ),
        );
        return;
      }
    }
  }

  Future<void> _pairFromForm() => _confirmThenPair(
    host: _host.text.trim(),
    port: int.tryParse(_port.text.trim()) ?? -1,
    code: _code.text.trim(),
  );

  /// §11.6.4. Greet, show the user what they are about to trust, then pair.
  Future<void> _confirmThenPair({
    required String host,
    required int port,
    required String code,
  }) async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final LanController controller = ref.read(lanControllerProvider.notifier);

      // The name shown is the one *that host* reports, not the one the QR
      // claimed. A hostile host can lie about its name too — the address is
      // the field the user can actually check, so it is shown first.
      final ({LanHello? hello, String? problem}) greeting = await controller
          .greet(host, port);
      if (greeting.hello == null) {
        setState(() => _problem = greeting.problem);
        return;
      }
      if (!mounted) {
        return;
      }

      final bool confirmed = await _confirm(
        host: host,
        port: port,
        deviceName: greeting.hello!.deviceName,
      );
      if (!confirmed) {
        return;
      }

      final String? problem = await controller.pairWith(
        host: host,
        port: port,
        code: code,
      );
      if (!mounted) {
        return;
      }
      if (problem != null) {
        setState(() => _problem = problem);
        return;
      }
      Navigator.of(context).pop(greeting.hello!.deviceName);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> _confirm({
    required String host,
    required int port,
    required String deviceName,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Pair with this PC?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '$host:$port',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('It calls itself "$deviceName".'),
              const SizedBox(height: 16),
              const Text(
                'Zen will send this device\'s ideas and tasks to that address '
                'every time it syncs. Only continue if it is your own PC.',
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Pair'),
            ),
          ],
        ),
      ) ??
      false;
}

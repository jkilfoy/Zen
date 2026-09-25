/// §11.5.5. The screen shown when the database will not open.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zen_data/zen_data.dart';
import 'package:zen_sync/zen_sync.dart';

import '../sync/database_recovery.dart';
import '../theme/app_theme.dart';
import '../theme/decor_registry.dart';
import '../widgets/confirmations.dart';

/// §11.5.5. "Show a dedicated screen naming the problem, offering `"Restore
/// from backup…"` and `"Import snapshot…"`, and keep the unreadable file in
/// place, renamed with a timestamp, so nothing is destroyed."
///
/// The quarantine is `openDatabase`'s (D-M3-11); this only reports it. Its own
/// `MaterialApp`, because the providers below the ordinary one all need a
/// database and there is none.
///
/// Both offered actions now work: `"Restore from backup…"` is §11.6.6 and
/// `"Import snapshot…"` is §11.8, and M6 built both. D-M4-9 rendered them
/// disabled until it had. They rest on the quarantine D-M3-11 performs — once
/// the unreadable file is moved aside, a fresh database can be created in its
/// place and the recovered data written into it. When it could *not* be moved
/// aside there is nowhere to put one, and the buttons stay disabled with the
/// reason, because a button that cannot work is worse than one that is plainly
/// unavailable.
class UnreadableDatabaseApp extends StatelessWidget {
  /// Reports [outcome], offering [recovery]'s two ways back.
  const UnreadableDatabaseApp(
    this.outcome, {
    required this.recovery,
    super.key,
  });

  /// What `openDatabase` returned.
  final DatabaseUnreadable outcome;

  /// §11.5.5. The restore and import paths.
  final DatabaseRecovery recovery;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Zen',
    debugShowCheckedModeBanner: false,
    theme: decorTheme(basicDecor, Brightness.light),
    darkTheme: decorTheme(basicDecor, Brightness.dark),
    home: Scaffold(
      appBar: AppBar(title: const Text('Zen cannot open its database')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Your data has not been deleted. Zen could not read the '
                'database file, so it has left it where it was rather than '
                'starting over with an empty one.',
              ),
              const SizedBox(height: 16),
              _Detail('Database', outcome.originalPath),
              if (outcome.quarantinedPath case final String path)
                _Detail('Moved aside to', path)
              else
                const _Detail(
                  'Moved aside to',
                  'Nowhere — the file is still where it was, and intact.',
                ),
              _Detail('Reported error', '${outcome.cause}'),
              const SizedBox(height: 24),
              _RecoveryActions(recovery),
            ],
          ),
        ),
      ),
    ),
  );
}

/// §11.5.5. The two ways back, and what they say when there is none.
class _RecoveryActions extends StatefulWidget {
  const _RecoveryActions(this.recovery);

  final DatabaseRecovery recovery;

  @override
  State<_RecoveryActions> createState() => _RecoveryActionsState();
}

class _RecoveryActionsState extends State<_RecoveryActions> {
  String? _result;
  bool _busy = false;
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.recovery.canRecover && !_busy && !_done;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FilledButton(
          onPressed: enabled ? _restore : null,
          child: const Text('Restore from backup…'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: enabled ? _import : null,
          child: const Text('Import snapshot…'),
        ),
        const SizedBox(height: 12),
        Text(
          _result ??
              (widget.recovery.canRecover
                  ? 'Zen writes a backup before every sync. Restoring one '
                        'creates a fresh database; the file above is left '
                        'exactly where it is.'
                  : 'Zen could not move the unreadable file aside, so it will '
                        'not create a new database next to it. Copy the file '
                        'named above somewhere safe, then reinstall Zen.'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _restore() async {
    final List<BackupEntry> backups = await widget.recovery.list();
    if (!mounted) {
      return;
    }
    if (backups.isEmpty) {
      setState(() => _result = 'There are no backups on this device.');
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
    if (chosen == null || !mounted) {
      return;
    }
    await _run(() => widget.recovery.restore(chosen));
  }

  Future<void> _import() async {
    // §11.8's import is a merge everywhere else. Here there is nothing to merge
    // with — the database is unreadable — so it writes a fresh one, and the
    // confirmation says so rather than letting the word "import" imply the
    // gentler operation it means on the Settings screen.
    final bool confirmed = await confirmDestructiveAction(
      context: context,
      title: 'Import a snapshot?',
      message:
          'Zen will create a new database containing only what the snapshot '
          'holds. The unreadable file is left where it is.',
      confirmLabel: 'Choose file…',
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _run(widget.recovery.importSnapshot);
  }

  Future<void> _run(Future<RecoveryResult?> Function() action) async {
    setState(() => _busy = true);
    final RecoveryResult? result = await action();
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      // Locked after a success: a second write would land on the database the
      // next launch is going to open, and the user has just been told to
      // restart.
      _done = result?.succeeded ?? false;
      _result = result?.message;
    });
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        SelectableText(value),
      ],
    ),
  );
}

/// §11.5.5. The screen shown when the database will not open.
library;

import 'package:flutter/material.dart';
import 'package:zen_data/zen_data.dart';

import '../theme/app_theme.dart';
import '../theme/decor_registry.dart';

/// §11.5.5. "Show a dedicated screen naming the problem, offering `"Restore
/// from backup…"` and `"Import snapshot…"`, and keep the unreadable file in
/// place, renamed with a timestamp, so nothing is destroyed."
///
/// The quarantine is `openDatabase`'s (D-M3-11); this only reports it. Its own
/// `MaterialApp`, because the providers below the ordinary one all need a
/// database and there is none.
///
/// Both offered actions belong to features that do not exist yet — `"Restore
/// from backup…"` is §11.6.6 (M6) and `"Import snapshot…"` is §11.8 (M6) — so
/// they are rendered disabled with a line saying so, rather than omitted. An
/// absent button would read as "there is no way back", which is the opposite of
/// what §11.5.5 wants this screen to say. Recorded in `DECISIONS.md`, D-M4-9.
class UnreadableDatabaseApp extends StatelessWidget {
  /// Reports [outcome].
  const UnreadableDatabaseApp(this.outcome, {super.key});

  /// What `openDatabase` returned.
  final DatabaseUnreadable outcome;

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
              // §11.6.6 and §11.8. Present but not yet wired: both belong to
              // the sync layer, which M6 adds.
              const FilledButton(
                onPressed: null,
                child: Text('Restore from backup…'),
              ),
              const SizedBox(height: 8),
              const OutlinedButton(
                onPressed: null,
                child: Text('Import snapshot…'),
              ),
              const SizedBox(height: 8),
              Text(
                'Both arrive with sync, which is not built yet. Until then, '
                'copy the file named above somewhere safe and reinstall.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );
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

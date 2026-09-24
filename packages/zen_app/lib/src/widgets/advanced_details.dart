/// IDEAFORM-6, TASKFORM-9. The read-only `"Advanced details"` panel.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// One labelled, read-only row of the panel.
@immutable
class DetailRow {
  /// A row showing [value] under [label].
  const DetailRow(this.label, this.value, {this.copyable = false});

  /// IDEAFORM-6. A row for an instant, `"—"` when it is null.
  ///
  /// "Timestamps are shown in local time with the time zone abbreviation."
  factory DetailRow.instant(String label, DateTime? instant) =>
      DetailRow(label, instant == null ? absent : formatInstant(instant));

  /// TASKFORM-9. "Null fields are shown as `"—"`."
  static const String absent = '—';

  /// The field's name, e.g. `createdAt`.
  final String label;

  /// Its rendered value.
  final String value;

  /// IDEAFORM-6. "The id row offers a copy action."
  final bool copyable;

  /// IDEAFORM-6. Local time plus the zone abbreviation, e.g.
  /// `2026-09-23 14:05:09 NDT`.
  static String formatInstant(DateTime instant) {
    final DateTime local = instant.toLocal();
    return '${DateFormat('yyyy-MM-dd HH:mm:ss').format(local)} '
        '${local.timeZoneName}';
  }
}

/// IDEAFORM-6, TASKFORM-9. "A collapsible section labelled `"Advanced
/// details"`, collapsed by default, shown in Edit mode only. It is
/// **read-only**."
///
/// The panel takes its rows already rendered, because the two screens show
/// different fields and neither set is this widget's business.
class AdvancedDetails extends StatelessWidget {
  /// Shows [rows], collapsed.
  const AdvancedDetails({required this.rows, super.key});

  /// The fields to show, in order.
  final List<DetailRow> rows;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Advanced details'),
    initiallyExpanded: false,
    childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
    children: <Widget>[
      for (final DetailRow row in rows)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(row.label, style: Theme.of(context).textTheme.labelSmall),
          subtitle: SelectableText(row.value),
          trailing: row.copyable
              ? IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy ${row.label}',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: row.value));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${row.label} copied')),
                      );
                    }
                  },
                )
              : null,
        ),
    ],
  );
}

/// §5.9. `SCR-ARCHIVE`: Archived Tasks.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:zen_domain/zen_domain.dart';

import '../providers/app_providers.dart';
import '../router.dart';
import '../widgets/completion_circle.dart';
import '../widgets/item_row.dart';

/// §5.9. "Lists all Tasks with `isArchived == true` and `isDeleted == false`,
/// grouped by the logical day they were completed, newest first."
///
/// ARCH-3's read-only Edit screen is `TaskFormScreen.edit`, which reads the
/// Task's own state rather than taking a flag — an archived Task is read-only
/// wherever it is opened from.
class ArchiveScreen extends ConsumerWidget {
  /// Builds the screen.
  const ArchiveScreen({super.key});

  /// ARCH-1. "Group headers show dates such as `"Mon, Sep 21 2026"`."
  static final DateFormat headerFormat = DateFormat('EEE, MMM d yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Task>> archived = ref.watch(archivedTasksProvider);
    final Settings settings = ref.watch(currentSettingsProvider);
    final Clock clock = ref.watch(clockProvider);
    final TimeZoneRules zone = ref.watch(timeZoneRulesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Archived tasks')),
      body: SafeArea(
        child: archived.when(
          loading: () => const SizedBox.shrink(),
          error: (Object error, StackTrace _) =>
              Center(child: Text('Could not read the archive: $error')),
          data: (List<Task> tasks) {
            if (tasks.isEmpty) {
              return const Center(child: Text('Nothing archived yet.'));
            }
            final List<_DayGroup> groups = _group(
              tasks,
              endOfDay: settings.endOfDay,
              zoneId: clock.localZoneId(),
              zone: zone,
            );
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: <Widget>[
                for (final _DayGroup group in groups) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      headerFormat.format(group.day),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (int i = 0; i < group.tasks.length; i++) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _ArchivedRow(task: group.tasks[i]),
                    ),
                    // ROW-4.
                    if (i < group.tasks.length - 1) const Divider(height: 1),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// ARCH-1, AC-6. Groups by `logicalDayOf(completedAt)`, newest day first.
  ///
  /// The grouping key is the *completion's* logical day, not the archive
  /// instant's: AC-6's task completed Tue 23:10 and archived Wed 02:00 belongs
  /// under Tuesday. INV-3 makes every archived Task `Done`, and INV-1 then
  /// makes its `completedAt` non-null, so the key always exists.
  static List<_DayGroup> _group(
    List<Task> tasks, {
    required LocalTime endOfDay,
    required String zoneId,
    required TimeZoneRules zone,
  }) {
    final Map<DateTime, List<Task>> byDay = <DateTime, List<Task>>{};
    for (final Task task in tasks) {
      final DateTime? completedAt = task.completedAt;
      if (completedAt == null) {
        continue;
      }
      byDay
          .putIfAbsent(
            logicalDayOf(completedAt, endOfDay, zoneId, zone),
            () => <Task>[],
          )
          .add(task);
    }
    final List<DateTime> days = byDay.keys.toList()
      ..sort((DateTime a, DateTime b) => b.compareTo(a));
    return <_DayGroup>[
      for (final DateTime day in days) _DayGroup(day, byDay[day]!),
    ];
  }
}

class _DayGroup {
  const _DayGroup(this.day, this.tasks);

  final DateTime day;
  final List<Task> tasks;
}

/// ARCH-2. "Rows use §5.6 rendering with a checkmark circle that cannot be
/// tapped."
class _ArchivedRow extends StatelessWidget {
  const _ArchivedRow({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) => ItemRow(
    name: task.name.value,
    tags: task.tags,
    // ARCH-3. "Tapping a Task opens Edit Task in **read-only** mode."
    onOpen: () => context.push(Routes.editTask(task.id)),
    // ARCH-2. `onTap: null` is what makes it untappable, and NFR-6 still
    // announces the state.
    leading: CompletionCircle(status: task.status, onTap: null),
  );
}

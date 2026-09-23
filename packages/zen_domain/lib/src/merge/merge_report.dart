/// §9.3 step 7. What a merge did, in a form the caller can log and show.
library;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../model/enums.dart';

const ListEquality<Object?> _listEquality = ListEquality<Object?>();

/// §9.3 step 6, §9.4. The kinds of invariant repair a merge can perform.
///
/// There is exactly one in the MVP. It is an enum rather than a bool so that a
/// second repair can be added without changing the report's shape.
enum MergeRepairKind {
  /// §9.3 step 6, INV-2. The component resolved to `Done`, but the unioned
  /// subtasks included one that is not `Done`, so the Task was set back to
  /// `Todo` and `completedAt`, `isArchived` and `archivedAt` cleared.
  ///
  /// "The one place where a Task's status changes without the user asking"
  /// (§9.4, STATUS-3). It only ever moves a Task from `Done` to `Todo`.
  reopenedForIncompleteSubtasks,
}

/// §9.3 step 6, step 7. One invariant repair, recorded so it is never silent.
@immutable
final class MergeRepair {
  /// Records that [kind] was applied to the Item resolved as [itemId].
  const MergeRepair({required this.kind, required this.itemId});

  /// What was repaired.
  final MergeRepairKind kind;

  /// The `id` of the resolved Item the repair was applied to.
  final String itemId;

  @override
  bool operator ==(Object other) =>
      other is MergeRepair && other.kind == kind && other.itemId == itemId;

  @override
  int get hashCode => Object.hash(kind, itemId);

  @override
  String toString() => 'MergeRepair(${kind.name}, $itemId)';
}

/// §9.3 step 7. One conflict component that was resolved into a single record.
///
/// Components of size 1 pass through unchanged (§9.3 step 3) and are not
/// reported: nothing happened to them.
@immutable
final class MergedComponent {
  /// Records that [inputIds] were resolved into [outputId].
  MergedComponent({
    required this.kind,
    required this.pass,
    required this.outputId,
    required List<String> inputIds,
    List<MergeRepair> repairs = const <MergeRepair>[],
  }) : inputIds = List<String>.unmodifiable(inputIds),
       repairs = List<MergeRepair>.unmodifiable(repairs);

  /// Whether this component held Ideas or Tasks. The two never mix (MERGE-5).
  final ItemKind kind;

  /// Which pass resolved it: `0` for the conflict components of §9.3 step 3,
  /// and `1`, `2`, … for the name re-passes of step 6.
  ///
  /// A step-6 pass combines Items that earlier passes already resolved, so its
  /// [inputIds] are those passes' [outputId]s rather than ids from any input
  /// snapshot. Recording the pass keeps that chain readable, and makes
  /// `(kind, pass, outputId)` a strict total order over a report's components:
  /// within one pass the output ids are distinct, because each pass partitions
  /// its records and each part takes the smallest id among its own members.
  final int pass;

  /// The distinct ids that went in, ascending.
  final List<String> inputIds;

  /// The `id` the component resolved to: the smallest of [inputIds]
  /// (§9.3 step 4).
  final String outputId;

  /// Any invariant repairs applied while resolving it (§9.3 step 6).
  final List<MergeRepair> repairs;

  @override
  bool operator ==(Object other) =>
      other is MergedComponent &&
      other.kind == kind &&
      other.pass == pass &&
      other.outputId == outputId &&
      _listEquality.equals(other.inputIds, inputIds) &&
      _listEquality.equals(other.repairs, repairs);

  @override
  int get hashCode => Object.hash(
    kind,
    pass,
    outputId,
    _listEquality.hash(inputIds),
    _listEquality.hash(repairs),
  );

  @override
  String toString() =>
      'MergedComponent(${kind.name}, pass $pass, '
      '${inputIds.join("+")} -> $outputId'
      '${repairs.isEmpty ? "" : ", ${repairs.length} repairs"})';
}

/// §9.3 step 7. Everything a merge did that was not a pass-through.
///
/// HIST-2 asks for a `merged` event per merged component. The merge is pure
/// and owns no event log (§11.4.5), so it reports here and the caller — M6's
/// orchestrator, which holds the [EventLog] — appends. That keeps §9.1's "pure,
/// side-effect-free component" literally true.
///
/// [components] are ordered by `(kind, pass, outputId)`, which is a strict
/// total order (see [MergedComponent.pass]), so two merges of the same content
/// produce equal reports and AC-19 can compare whole [MergeResult]s.
@immutable
final class MergeReport {
  /// Wraps [components], which the strategy has already put in canonical
  /// order.
  MergeReport(List<MergedComponent> components)
    : components = List<MergedComponent>.unmodifiable(components);

  /// An empty report: nothing conflicted.
  static final MergeReport empty = MergeReport(const <MergedComponent>[]);

  /// Every component that was resolved from more than one record.
  final List<MergedComponent> components;

  /// Whether nothing conflicted.
  bool get isEmpty => components.isEmpty;

  /// Every repair across every component, in component order.
  List<MergeRepair> get repairs => <MergeRepair>[
    for (final MergedComponent component in components) ...component.repairs,
  ];

  @override
  bool operator ==(Object other) =>
      other is MergeReport &&
      _listEquality.equals(other.components, components);

  @override
  int get hashCode => _listEquality.hash(components);

  @override
  String toString() =>
      'MergeReport(${components.length} merged, ${repairs.length} repaired)';
}

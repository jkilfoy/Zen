/// Zen's domain layer: entities, value objects, the business rules of
/// ZEN_SPEC.md §4, the End-of-Day calculator of §4.5 and the merge of §9.
///
/// §11.1. This library is pure Dart. Nothing beneath it may import `dart:io`,
/// `dart:ui` or `package:flutter`, and `DateTime.now()` may not appear in it
/// (§11.11). `test/architecture_test.dart` enforces both.
///
/// The layout follows §11.3:
///
/// * `model/` — [Idea], [Task], [Subtask], [Tag], [ItemName], the enums.
/// * `merge/` — [MergeStrategy], [NameUnionMergeStrategy] and §9's types.
/// * `rules/` — the rules of §4, each returning a [Result].
/// * `time/` — [Clock], [LocalTime], [TimeZoneRules], the End-of-Day calculator,
///   and §3's millisecond-precision rule.
/// * `search/` — §5.10's matching and filters.
/// * `ids/` — [IdGenerator].
/// * `repository/` — interfaces only; `zen_data` implements them.
/// * `result.dart` — [Result] and every [RuleViolation].
///
/// Test doubles for the injected ports live in
/// `package:zen_domain/testing.dart`.
library;

export 'src/ids/id_generator.dart';
export 'src/merge/conflict_components.dart';
export 'src/merge/field_resolution.dart';
export 'src/merge/merge_report.dart';
export 'src/merge/merge_strategy.dart';
export 'src/merge/name_union_merge_strategy.dart';
export 'src/merge/record_order.dart';
export 'src/merge/replica_snapshot.dart';
export 'src/merge/subtask_merge.dart';
export 'src/model/enums.dart';
export 'src/model/idea.dart';
export 'src/model/invariants.dart';
export 'src/model/item_event.dart';
export 'src/model/item_name.dart';
export 'src/model/item_text.dart';
export 'src/model/lan_peer.dart';
export 'src/model/normalize.dart';
export 'src/model/settings.dart';
export 'src/model/subtask.dart';
export 'src/model/subtask_name.dart';
export 'src/model/tag.dart';
export 'src/model/task.dart';
export 'src/model/tombstone.dart';
export 'src/repository/repositories.dart';
export 'src/result.dart';
export 'src/rules/conversion_rules.dart';
export 'src/rules/idea_rules.dart';
export 'src/rules/name_rules.dart';
export 'src/rules/subtask_rules.dart';
export 'src/rules/task_rules.dart';
export 'src/search/search_query.dart';
export 'src/time/clock.dart';
export 'src/time/end_of_day.dart';
export 'src/time/instant_precision.dart';
export 'src/time/local_time.dart';
export 'src/time/time_zone_rules.dart';

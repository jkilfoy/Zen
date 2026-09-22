/// Zen's domain layer: entities, value objects, the business rules of
/// ZEN_SPEC.md §4, the End-of-Day calculator of §4.5 and the merge of §9.
///
/// §11.1. This library is pure Dart. Nothing beneath it may import `dart:io`,
/// `dart:ui` or `package:flutter`, and `DateTime.now()` may not appear in it
/// (§11.11). `test/architecture_test.dart` enforces both.
library;

// M1 fills this barrel with the model, time, ids, rules and repository
// exports. M2 adds the merge.

/// §3. Identifier generation.
library;

import 'package:uuid/uuid.dart';

/// §3. The source of new entity ids.
///
/// §11.4.1 gives `addSubtask(Task task, String name, DateTime now)`, but §3.4
/// requires every Subtask to carry a generated UUIDv7, and that signature has
/// no way to produce one without reaching for a global. That is the same
/// objection §11.11 raises against `DateTime.now()`, so ids are injected the
/// way time already is. Recorded in `DECISIONS.md` (D-M1-6).
///
/// Tests use a deterministic generator so that ids are reproducible; see
/// `package:zen_domain/testing.dart`.
abstract interface class IdGenerator {
  /// Returns a fresh id, unique across replicas without coordination.
  String newId();
}

/// §3. The production [IdGenerator]: UUIDv7.
///
/// "UUIDv7 is time-ordered and collision-safe across replicas without
/// coordination", which is what makes the merge's smallest-id tie-break (§9.3
/// step 4) both deterministic and stable.
final class UuidV7IdGenerator implements IdGenerator {
  /// Constructs a generator over [Uuid]'s v7 implementation.
  const UuidV7IdGenerator();

  static const Uuid _uuid = Uuid();

  @override
  String newId() => _uuid.v7();
}

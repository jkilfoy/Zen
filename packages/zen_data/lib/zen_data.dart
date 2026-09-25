/// Zen's data layer: the Drift schema of §11.5, its constraints, and the
/// repository implementations of §11.4.6.
///
/// §11.1. `zen_data` depends on `zen_domain` and nothing depends on it but
/// `zen_app`. It holds no product rules of its own: the rules live in
/// `zen_domain` and are called from here, so that a later remote-backed
/// implementation can replace this package without touching them (STORE-2).
///
/// What is worth knowing before reading it:
///
/// * **The schema is SQL**, under `src/tables/*.drift`, not the Dart table DSL.
///   §11.5.2's constraints then read as the specification writes them and
///   `drift_dev` validates every one at build time.
/// * **The constraints are the guarantee, not the repositories.** §11.5.2:
///   `zen_domain` guards its invariants with `assert`, which Dart strips from
///   release builds, so the `CHECK` constraints, the triggers and the partial
///   unique indexes are the only enforcement that executes in the app you run.
/// * **Violations are detected by attempting the write**, never by a `SELECT`
///   first — that has a time-of-check-to-time-of-use window, and it would mean
///   the index the tests are meant to exercise never fires.
/// * **Timestamps are ISO-8601 text at exact millisecond precision** (§3,
///   INV-9). Uniform width is what makes text comparison chronological, which
///   INV-5 and every `ORDER BY` here rely on.
library;

export 'src/archive_sweeper.dart';
export 'src/connection.dart';
export 'src/database.dart'
    show
        AppDatabase,
        EventRow,
        IdeaRow,
        IdeaTagRow,
        IdeaTombstoneRow,
        ReplicaRow,
        SettingRow,
        SubtaskRow,
        TaskRow,
        TaskTagRow;
export 'src/mapping/entity_mapping.dart';
export 'src/mapping/instants.dart';
export 'src/repository/constraint_failures.dart';
export 'src/repository/drift_conversion_service.dart';
export 'src/repository/drift_dataset_repository.dart';
export 'src/repository/drift_event_log.dart';
export 'src/repository/drift_idea_repository.dart';
export 'src/repository/drift_replica_repository.dart';
export 'src/repository/drift_settings_repository.dart';
export 'src/repository/drift_task_repository.dart';
export 'src/repository/drift_tombstone_store.dart';
export 'src/repository/events.dart';
export 'src/time/timezone_rules_adapter.dart';

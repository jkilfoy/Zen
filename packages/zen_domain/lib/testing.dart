/// Test doubles for `zen_domain`'s injected ports: [FakeClock],
/// [SequentialIdGenerator], [FixedOffsetTimeZoneRules] and
/// [TorontoTimeZoneRules].
///
/// Import this from tests only. It ships in `lib/` so that `zen_data`,
/// `zen_sync` and `zen_app` can all reach it — a package's `test/` directory is
/// not importable from a sibling package. Everything here is pure Dart, so
/// §11.1 holds (D-M1-8).
library;

export 'src/testing/fakes.dart';

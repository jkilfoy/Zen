/// §11.6.3, §11.6.5. Where this package's warnings go.
library;

/// §11.6.3. Receives a warning that must not abort the sync.
///
/// §11.6 asks for a logged warning in three places and for none of them to stop
/// the pass: a snapshot file that fails to parse, a `nameNormalized` that
/// disagrees with the locally recomputed form (§11.6.1), and a transport that
/// fails outright (§11.6.5 step 3). A callback rather than `print` or a logging
/// package, so tests can assert what was warned about and `zen_app` can route
/// it wherever it routes the rest.
typedef SyncLogger = void Function(String message);

/// The default [SyncLogger]: discards everything.
///
/// Used where a caller has no interest in the warnings — chiefly tests of
/// behaviour other than logging. Production wiring passes a real one.
void discardSyncLog(String message) {}

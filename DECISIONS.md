# Decisions

Every choice `ZEN_SPEC.md` left open, per §0.1: *"If something is not specified
here, the implementer MUST NOT invent product behaviour. It MUST instead choose
the simplest behaviour consistent with this document and record the choice in
`DECISIONS.md` at the repository root."*

Each entry names the milestone it was made in, the spec clause that prompted it,
and the reasoning. Entries are append-only: if a decision is reversed, the old
entry stays and a new one supersedes it.

---

## Resolved package versions (§11.2)

§11.2 requires that each package's current version, null-safety status and
maintenance state be checked on pub.dev before use, and the resolved version
recorded here. Checked **2026-09-22**.

### Toolchain

| Thing | Spec said | Resolved | Notes |
|---|---|---|---|
| Flutter | stable, "3.47.x with Dart 3.13" | **3.47.5** (Dart 3.13.4) | Current stable per the release manifest. Pinned in `.fvmrc` and in `ci.yaml`. |

### `zen_domain` (M1)

| Role | Package | Constraint | Notes |
|---|---|---|---|
Resolved by `dart pub get` on 2026-09-22 and taken from `pubspec.lock`, not
from the constraint:

| Role | Package | Constraint | **Resolved** | Notes |
|---|---|---|---|---|
| Grapheme clusters | `characters` | `^1.4.1` | **1.4.1** | Not named in §11.2, but NAME-2 defines "characters" as Unicode extended grapheme clusters and `dart:core` cannot count those. |
| Collections | `collection` | `^1.19.0` | **1.19.1** | `ListEquality`/`UnmodifiableListView` for hand-written `==` on immutable entities (§11.11). |
| Annotations | `meta` | `^1.16.0` | **1.19.0** | `@immutable`, `@useResult`. |
| IDs | `uuid` | `^4.6.0` | **4.6.0** | UUIDv7 confirmed: 4.6.0 supports RFC 9562 v6, v7 and v8. Pure Dart. |
| Unicode NFC | `unorm_dart` | `^0.3.2` | **0.3.2** | §2's NFC pass, added by spec v1.2. Unicode 17.0, verified publisher, **no transitive dependencies at all**, so §11.1 holds. |
| Lints | `lints` | `^6.1.0` | **6.1.0** | `package:flutter_lints` cannot be used here — it would pull Flutter into `zen_domain` (§11.1). See D-M0-3. |
| Testing (dev) | `test` | `^1.32.0` | **1.32.0** | |
| YAML (dev) | `yaml` | `^3.1.3` | **3.1.4** | Read by `architecture_test.dart` only; a dev dependency, so it never ships. |

`uuid` pulls three transitive dependencies — `crypto` 3.0.7, `fixnum` 1.1.1 and
`typed_data` 1.4.0. All three are pure Dart with no route to IO, so §11.1 holds.
The allow-list in `architecture_test.dart` checks direct dependencies only,
which is what §11.1's wording ("its `pubspec.yaml` MUST NOT depend on") covers.

### `flutter_lints`

| Role | Package | Constraint |
|---|---|---|
| Lints for `zen_data`, `zen_app` | `flutter_lints` | `^6.0.0` |

### `zen_data` (M3)

Resolved by `flutter pub get` on 2026-09-23 and taken from `pubspec.lock`.

| Role | Package | Constraint | **Resolved** | Notes |
|---|---|---|---|---|
| Database | `drift` | `^2.35.0` | **2.35.0** | §11.2's claim holds: since 2.32 SQLite is bundled through a build hook, and `NativeDatabase.memory()` works under `flutter test` on Windows with nothing extra installed (sqlite3 **3.53.4**). |
| Database (Flutter glue) | `drift_flutter` | `^0.3.1` | **0.3.1** | For M4's composition root; M3 opens its own connection (`connection.dart`). |
| Codegen | `drift_dev` | `^2.35.0` | **2.35.0** | Also supplies `schema dump` / `generate` / `steps` (§11.5.3) and `package:drift_dev/api/migrations_native.dart`. |
| Codegen driver | `build_runner` | `^2.16.1` | **2.16.1** | **`--delete-conflicting-outputs` was removed in 2.16** and now warns; `dart run build_runner build` is the whole command. |
| SQLite | `sqlite3` | `^3.6.0` | **3.6.0** | A direct runtime dependency, not only a test one: §11.5.2's error mapping reads `SqliteException.extendedResultCode`. |
| IANA time zones | `timezone` | `^0.11.1` | **0.11.1** | `zen_data` only (§11.2, D-M1-2). `TimeZone.offset` is already a `Duration`, and the bundled database is Dart source, so the adapter reads no files. |
| Lints | `flutter_lints` | `^6.0.0` | **6.0.0** | |

`sqlite3_flutter_libs` is now published as **`0.6.0+eol`** — end of life, exactly
as §11.2 predicted. Nothing here depends on it.

### `zen_app` (M4)

Resolved by `flutter pub get` on 2026-09-23 and taken from `pubspec.lock`. Each
was checked on pub.dev for its current version, null-safety and maintenance
state, as §11.2 requires; all are null-safe and all published within the last
four months.

| Role | Package | Constraint | **Resolved** | Notes |
|---|---|---|---|---|
| State | `flutter_riverpod` | `^3.4.3` | **3.4.3** | §11.2's "3.x". Plain `Provider` / `StreamProvider`, no annotations and no build step, as §11.0 requires. Note that `Override` — the element type of `ProviderContainer.overrides` — is *not* in 3.x's public export list, so that list's type is inferred rather than written out. |
| Routing | `go_router` | `^18.0.1` | **18.0.1** | |
| Formatting | `intl` | `^0.20.3` | **0.20.3** | ARCH-1's date headers and the Advanced details panels (§11.2). |
| Paths | `path_provider`, `path` | `^2.1.6`, `^1.9.1` | **2.1.6**, **1.9.1** | `getApplicationSupportDirectory` is where STORE-1's one database file lives. |
| App metadata | `package_info_plus` | `^10.2.1` | **10.2.1** | SET-3's About row. |
| Device metadata | `device_info_plus` | `^13.2.0` | **13.2.0** | D-M3-15's injected device name; the pairing screen (§11.6.4) will reuse it. |
| Device time zone | `flutter_timezone` | `^5.1.0` | **5.1.0** | **Not in §11.2's table** — see D-M4-3. |
| Database (test only) | `drift` | `^2.35.0` | **2.35.0** | A dev dependency: the widget tests build `NativeDatabase.memory()` directly rather than mocking the repositories (D-M4-15). |

`shelf`, `http`, `cryptography`, `nsd`, `qr_flutter` and `mobile_scanner` are
still unresolved: they are M7's, and §11.2 says to check each at the milestone
that first needs it.

### `zen_sync` and the sync platform glue (M6)

Resolved by `flutter pub get` on 2026-09-24 and taken from `pubspec.lock`. Each
was checked on pub.dev for its current version, null-safety and maintenance
state, as §11.2 requires.

| Role | Package | Constraint | **Resolved** | Notes |
|---|---|---|---|---|
| Collections | `collection` | `^1.19.0` | **1.19.1** | `zen_sync`. List equality on the outcome types. |
| Annotations | `meta` | `^1.16.0` | **1.19.0** | `zen_sync`. |
| Paths | `path` | `^1.9.1` | **1.9.1** | `zen_sync`. Joining names onto the backup and snapshot directories; the IO itself is `dart:io`'s. |
| IDs | `uuid` | `^4.6.0` | **4.6.0** | `zen_sync`. §11.6.3's temp-file names. The same version `zen_domain` resolves for entity ids. |
| Desktop folder picker | `file_selector` | `^1.1.0` | **1.1.0** | `zen_app`. flutter.dev, verified publisher, Windows 10+. `getDirectoryPath` is §11.6.3's Windows picker. |
| Android folder access | `saf_util` | `^3.1.0` | **3.1.0** | `zen_app`. `pickDirectory` is `ACTION_OPEN_DOCUMENT_TREE`; `persistablePermission: true` is `takePersistableUriPermission`. §11.2 notes `shared_storage` is discontinued and MUST NOT be used; it is not here. |
| Android file IO | `saf_stream` | `^4.0.1` | **4.0.1** | `zen_app`. **Not optional.** `saf_util` deliberately excludes reading and writing and points at this package for them — §11.2 anticipated the pair with "with `saf_stream` if streaming is needed", and it is needed. Same publisher. |

`file_selector` pulls in `file_selector_android`, which implements `openFile`,
`openFiles` and `getDirectoryPath` — and **no save dialog**. That gap is what
D-M6-11 is about.

---

## M0 — repository skeleton

**D-M0-1 — The repository root is the existing `Zen` folder.**
§11.3 shows `ZEN_SPEC.md` at the root of the tree, which it already was.
`git init` was run in place rather than creating a nested `zen/` directory.

**D-M0-2 — Shared analyzer config lives in one root `analysis_options.yaml`.**
§11.11 lists lint rules but not where to put them. Each package's
`analysis_options.yaml` includes its lint-set package *and then* the root file,
using the analyzer's list-form `include:`, so the §11.11 rules are declared
once. Simplest arrangement that keeps the four packages consistent.

**D-M0-3 — `zen_domain` and `zen_sync` use `lints`, not `flutter_lints`.**
§11.11 says "`flutter_lints` plus …", but `flutter_lints` depends on Flutter,
and §11.1 forbids that in `zen_domain`. `package:lints/recommended.yaml` is the
set `flutter_lints` itself is built on, so the pure Dart packages get the same
rules minus the Flutter-specific ones. `zen_sync` is pure Dart too and follows
`zen_domain` for consistency.

**D-M0-4 — `public_member_api_docs` is switched on repository-wide.**
NFR-4 requires "doc comments on public types" and §11.11 repeats it. The
available lint is `public_member_api_docs`, which is slightly stricter — it
also wants docs on public *members*, including enum values. Accepted rather
than weakened: this is a spec-driven domain where every enum value maps to a
requirement, so the documentation is worth writing.

**D-M0-5 — Strict analyzer language modes are on.**
`strict-casts`, `strict-inference` and `strict-raw-types` are enabled. Not
required by the spec; justified by NFR-4 ("no clever metaprogramming", readable
without prior context) and free at this stage. Reversible if it proves noisy.

**D-M0-6 — `zen_app` has no `android/` or `windows/` folder yet.**
Those are generated by `flutter create --platforms=windows,android .`, which
needs the SDK and, for anything beyond generation, the platform toolchains
§11.13.1 puts on the owner's hardware. M0 needs only that the package exists,
resolves and analyzes. The folders are generated in M4, and the resulting
`build.gradle` settings (`compileSdk` 36, `targetSdk` 36, `minSdk` 26, §11.2)
recorded here then.

**D-M0-7 — The `DateTime.now()` ban is enforced by a CI grep, not a custom lint.**
§11.11 permits either. A custom lint would mean a fifth package and a
`custom_lint` dependency; the grep is `tools/check_no_datetime_now.sh`, fifteen
lines with no dependency, which is what §11.13's "prefer deleting code to
adding configuration" asks for. `zen_domain` additionally asserts the same rule
as a unit test so it fails locally, not only in CI.

**D-M0-8 — CI is one job on `ubuntu-latest`.**
§11.10 lists four steps and does not name a platform. Everything through M6 is
verifiable headlessly on Linux (§11.13.1), so one Linux job is the simplest
thing that satisfies the spec. The tagged-release job that builds the Windows
installer and the signed APK needs a Windows runner and a keystore secret, and
is added in M8.

**D-M0-9 — `git config core.autocrlf false` plus `.gitattributes eol=lf`.**
CI runs `dart format --set-exit-if-changed` on Linux while the working copy is
on Windows. Without this, line endings alone would fail the format check.

**D-M0-10 — All four `pubspec.lock` files are committed.**
Dart convention commits lockfiles for applications and not for libraries, which
would mean committing only `zen_app`'s. Committed all four instead: §11.2 wants
the machines and the build to agree on versions, three of the four packages are
consumed only inside this repository, and a silent transitive bump between the
Windows checkout and the CI runner is exactly the kind of drift the pin in
`.fvmrc` exists to prevent.

**D-M0-11 — The `DateTime.now()` checks ignore comments.**
Their first run flagged `zen_domain.dart`'s own doc comment, which names the
rule it documents. Both the shell grep and the unit test now strip comments
before scanning. The unit test's stripper also removes `//` inside string
literals; that can only cause a false negative, and only for a string
containing `//` followed by a banned construct, which is not worth a real
parser.

**D-M0-12 — Generated Drift output is committed.**
`*.g.dart` is not in `.gitignore`. §11.5.3 requires generated schema-migration
tests that compare against past versions, and those are only meaningful if the
generated schema is under version control. `*.g.dart` is excluded from analysis
instead.

---

---

## M1 — `zen_domain` model and rules

**D-M1-1 — "Unicode case folding" (§2) is approximated by `String.toLowerCase`. Superseded in part: NFC is now applied.**

> **Amended 2026-09-23 for `ZEN_SPEC.md` v1.2.** §2 now specifies a Unicode NFC pass as the *first* step of normalization, before trimming, whitespace collapsing and case folding. `normalizeName` does that, over `unorm_dart`. The half of this entry that said "no Unicode normal form is applied" no longer holds; the case-folding half below still does.
>
> The spec gives the reason and it is a real defect this avoids: the two target devices have different input stacks, so without NFC the same name typed on Windows and on Android would fail to match during a merge and appear twice after syncing. §11.5.2 adds that the rule has to be settled *before* the `name_normalized` column exists, because changing it later needs a migration that recomputes every row and can fail where two rows that were distinct become equal and collide with the unique index. That is why this landed before M3 rather than with it.

*Original entry, case folding still accurate:*

§2 asks for case folding, which is strictly more than lowercasing: full folding maps `ß` to `ss`, and Dart carries no such table. `toLowerCase` is the simplest behaviour consistent with the document. Two consequences, both accepted: names differing only by a fold-but-not-lowercase pair compare as different, and a composed `é` and a decomposed `é` are different names, which can matter between a Windows and an Android keyboard. `normalizeName` is the single definition of the rule, so the domain, the merge (§9.2) and the `name_normalized` index (§11.5.2) cannot drift apart whatever is decided later.

**D-M1-2 — DST is resolved through a `TimeZoneRules` port, not `package:timezone`.**
§11.4.4 gives `archiveBoundaryAfter` a `String zoneId`, but `dart:core` cannot resolve an IANA zone. `package:timezone` 0.11.1 declares `package:http` as a runtime dependency, which reaches `dart:io`, so depending on it would breach §11.1 — the constraint the specification calls load-bearing. `zen_domain` therefore declares a one-method port, `Duration offsetAt(DateTime utc, String zoneId)`, and keeps the hard part — gap and ambiguity handling — in `end_of_day.dart`, tested against a fixture with real Toronto transition rules. `zen_data` supplies the adapter over `package:timezone` in M3.

> **Confirmed by `ZEN_SPEC.md` v1.2.** §11.2 previously named no timezone package at all. It now carries a `timezone` row reading "**`zen_data` only** … It MUST NOT be a `zen_domain` dependency — it reaches `dart:io`, which §11.1 forbids there. The domain declares the one-method port; the data layer implements it." No code change needed.

**D-M1-3 — Copy for the violations the specification does not give copy for.**
§11.4.1 requires every `RuleViolation` to carry a message, but §3–§5 supply copy for only some of them. The owner supplied the rest on 2026-09-22. They fall in three groups.

*Silent — the specification says these produce no message, so `message` is empty and `hasMessage` is false:*

| Violation | Rule |
|---|---|
| `TaskBlocked` | §4.2 row 4, AC-7: "No change", at most a nudge animation |
| `SubtaskBlocked` | SUB-4: "A `Blocked` subtask does not toggle" |
| `TagEmpty` | see D-M1-4 |

*Unreachable through the MVP UI — the copy exists so that no code path can persist a violation:*

| Violation | Copy | Rule |
|---|---|---|
| `ArchivedTaskImmutable` | "Unarchive this task before changing its status." | STATUS-4 |
| `DeletedTaskImmutable` | "Restore this task before changing its status." | DEL-1, SEARCH-3 |
| `SubtaskAddForbiddenWhileDone` | "Set the task back to Todo to add a subtask." | SUB-8 |

*Reachable by the user:*

| Violation | Copy | Rule |
|---|---|---|
| `TagContainsWhitespace` | "Tags cannot contain spaces." | TAG-2 |
| `TagTooLong` | "Tags must be 32 characters or fewer." | TAG-3 |
| `ContextTooLong` | "Context must be 10,000 characters or fewer." | §3.2 |
| `DescriptionTooLong` | "Description must be 10,000 characters or fewer." | §3.3 |
| `SubtaskNameEmpty` | "Subtask name cannot be empty." | §3.4 |
| `SubtaskNameTooLong` | "Subtask name must be 1000 characters or fewer." | §3.4 |
| `NameContainsLineBreak` | "Name cannot contain line breaks." | NAME-4 |
| `SubtaskNameContainsLineBreak` | "Subtask name cannot contain line breaks." | §3.4 |

The last two were not in the batch first put to the owner and **need review**. NAME-4 says a name "MUST NOT contain line breaks" and gives no message, because the Add and Edit screens make Enter submit the form — the state is reachable only by pasting. Rejecting rather than silently stripping follows principle 1.2.5 and matches how every other §3.1 validation behaves. Both strings are in the same voice as the approved batch.

**D-M1-4 — An empty tag is refused silently.**
TAG-3 sets a minimum of 1 character but gives no copy, and the gesture that produces it — committing an empty chip — is not an error the user needs told about. `TagEmpty` carries no message and the chip input simply adds nothing.

**D-M1-5 — An ambiguous End-of-Day boundary resolves to the earlier occurrence.**
EOD-5 handles the spring-forward gap ("use the first valid instant after it") but says nothing about the fall-back hour, when the configured wall-clock time occurs twice. The earlier is the simplest reading of EOD-2, which asks for the *first* boundary strictly after a completion. Both cases are tested at exact instants in `test/time/end_of_day_test.dart`.

**D-M1-6 — Two §11.4.1 signatures gained a parameter.**
`addSubtask(Task, String name, DateTime now)` has no way to mint the UUIDv7 that §3.4 requires, so it takes an `IdGenerator` — the same treatment §11.11 already gives the clock — and a validated `SubtaskName` rather than a raw `String` (§11.4.2). `reopenTask(Task)` takes a `DateTime now`, because §3.3 requires `updatedAt` to move on every user edit and INV-5 would otherwise be unenforceable.

**D-M1-7 — Reordering subtasks moves the parent's `updatedAt` only.**
§3.3 requires the Task's `updatedAt` to move on any subtask change. Nothing about an individual subtask changes when the list is reordered, so their own timestamps are left alone. Renaming moves both.

**D-M1-8 — Test doubles ship in `lib/testing.dart`, not `test/`.**
`FakeClock`, `SequentialIdGenerator`, `FixedOffsetTimeZoneRules` and `TorontoTimeZoneRules` are needed by `zen_data`, `zen_sync` and `zen_app` tests, and a package's `test/` directory is not importable from a sibling package. They are pure Dart, so §11.1 still holds, and they sit behind a separate barrel so nothing in `zen_domain.dart` exposes them.

**D-M1-9 — A rule asked to do what has already been done returns `Ok` unchanged.**
`completeTask` on a `Done` Task, `reopenTask` on a `Todo` one, `setTaskStatus` to the current status, `softDeleteTask` on a deleted Task, `restoreTask` on a live one, `unarchiveTask` on an unarchived one, and `reorderSubtasks` from an index to itself are all no-ops rather than refusals. The simplest behaviour, and it keeps callers free of pre-checks.

**D-M1-10 — Archived and soft-deleted Tasks refuse every edit, and NAME-9 is checked only when the result would actually be active.**
STATUS-4 blocks status changes on an archived Task; SEARCH-3 opens a deleted one read-only with only a `"Restore"` action, so the same treatment is the simplest consistent choice, and it is applied to subtask edits too. Conversely a Task that is both archived and deleted reserves no name (§2, NAME-7), so restoring or unarchiving one of those passes the NAME-9 check — it lands back in the archive, not the To Do list.

**D-M1-11 — Three name-collision classes rather than one.**
§11.4.1 sketches a single `NameCollision` covering "NAME-8 / NAME-9 messages". Split into `IdeaNameCollision`, `TaskNameCollision` and `ActiveTaskHoldsName`, because the three carry different copy and a test that asserts on a type is clearer than one that asserts on a string.

**D-M1-12 — The nullable lifecycle timestamps are not settable through `copyWith`.**
INV-1 makes `completedAt` a function of `status`, and INV-4 makes `archivedAt` and `deletedAt` functions of their flags. Rather than a sentinel to distinguish "not supplied" from "set to null", `Task` exposes `withStatus`, `archived`, `unarchived`, `softDeleted` and `restored`, each of which maintains its pairing by construction. `copyWith` covers the remaining fields. This is why no caller can break INV-1 or INV-4 by accident.

**D-M1-13 — `archiveTask` asserts rather than returning a `Result`.**
INV-3 allows only a `Done` Task to archive, and the sweeper selects on exactly that (EOD-2, §11.5.4), so anything else is programmer error — which §11.4.1 reserves exceptions for. The same applies to an unknown subtask id and an out-of-range reorder index.

**D-M1-15 — Tag comparison applies NFC too, although §2 only requires it for Item names.**
§2 defines normalization for names and is silent about tags. The reason it gives applies identically: the same two input stacks produce tags, so without NFC `@café` typed on Windows and on Android would not de-duplicate (TAG-4) and would appear twice in the autocomplete list (TAG-6). `normalizeTag` therefore runs NFC then lowercases. Tags contain no whitespace (TAG-2), so there is nothing to trim or collapse. The simplest behaviour consistent with the document, per §0.1.

**D-M1-16 — The entity assertions are a development aid, not the shipped guarantee.**
`ZEN_SPEC.md` v1.2 adds to §11.5.2: "`zen_domain` guards its invariants with `assert`, which Dart strips from release builds. In the app you actually run, the `CHECK` constraints and the unique indexes are therefore the *only* enforcement that executes."

That is correct and it qualifies D-M1-12 and D-M1-13. What those entries claim structurally still holds in release, because it is a matter of reachability rather than checking: `completedAt` is not settable through `copyWith` at all, so no caller can desynchronise it from `status` whether assertions run or not. What does *not* survive a release build is the constructor assert that would catch a violation arriving from somewhere else — a hand-built entity, a bad decode, a merge bug. M3 must therefore treat the §11.5.2 `CHECK` constraints and partial unique indexes as the real enforcement, and `datasetInvariantFailures` stays the thing tests and the merge assert against explicitly rather than relying on `assert`.

**D-M1-14 — `Settings` and the repository interfaces were written in M1.**
§11.13's M1 row lists entities, value objects, `Clock`, the §4 rules and the EoD calculator, but §11.1 places the repository interfaces in `zen_domain`, and `SettingsRepository` cannot be declared without the §3.6 settings record. Both are declarations with no behaviour to test; M3 implements them. §11.8's sync settings are deliberately not added yet — they arrive in M6, with the transports that read them.

## M2 — `zen_domain` merge: `NameUnionMergeStrategy`

Ten ambiguities in §9.3 were found before any code was written and put to the
owner; all ten were accepted and folded into **`ZEN_SPEC.md` v1.4**, so they are
specification, not decisions, and are not repeated here. What follows is what
v1.4 still leaves to the implementer.

**D-M2-1 — Record order is implemented as a comparator that is total *up to
field-for-field equality*, not a total order.**
§9.3 defines the comparison sequence but not what happens when two records tie.
`compareIdeaRecords` covers every §3.2 field, so for Ideas a tie *is* equality
and `record_order_test.dart` checks the equivalence directly over generated
records. For Tasks §9.3 names four subtask fields for the element-wise
comparison — `id`, `name`, `status`, `updatedAt` — so two Tasks can tie while
differing in a subtask's `createdAt` or `completedAt`. That is implemented as
written rather than widened, because it cannot change the output: step 5(d)
resolves both of those by earliest across the whole group, and the group holds
both records whichever one is called the primary. A test demonstrates it rather
than leaving it as an argument.

**D-M2-2 — The subtask primary's "then in record order" means the record it came
from, not a subtask-level comparator.**
§9.3 step 5(d) breaks a tie on `updatedAt` with "then in record order", a term
§9.3 defines over *records*. A group holds at most one subtask per record
(step 5(c)), so the record each member came from settles it, and
`subtask_merge.dart` carries a `recordIndex` alongside each subtask for exactly
this. The alternative reading — a subtask-level comparator — gives the same
answer in every case, because two members of one group that came from records
tying in record order came from records with identical subtask lists.

**D-M2-3 — `merge` does not validate its inputs.**
§9.3's invariant-preservation property is a claim about *valid* inputs, and the
merge is a pure function with nowhere to report a violation to. The entity
constructors' asserts catch a malformed record in development, and
`datasetInvariantFailures` is what the tests assert with — including a test that
the **generators** produce valid datasets, so a generator bug reports itself as
a generator bug rather than as a merge failure. Per D-M1-16 the shipped
enforcement is M3's `CHECK` constraints and unique indexes.

**D-M2-4 — The merge reports the `merged` events rather than appending them.**
HIST-2 and §9.3 step 7 ask for a `merged` event per merged component. MERGE-1
requires the strategy to be pure and side-effect-free and §11.4.5 gives it no
clock, so it cannot append to an event log. `MergeReport` carries what an event
needs — kind, pass, input ids, output id, repairs — and M6's orchestrator, which
holds the `EventLog`, writes them.

**D-M2-5 — `MergedComponent` carries the pass that resolved it.**
§9.3 step 7 asks for input ids, the output id and any repairs. The step-6 name
re-pass merges Items that earlier passes already resolved, so its "input ids"
are those passes' output ids, and a report without the pass number reads as a
contradiction. It also makes `(kind, pass, outputId)` a strict total order over
a report's components — within one pass the output ids are distinct, because
each pass partitions its records and each part takes the smallest id among its
own members — which is what lets AC-19 compare whole `MergeResult`s including
their reports.

**D-M2-6 — `MergeResult.asSnapshot(replicaId)` exists for the idempotence
property.**
§11.12 asks for `merge([merge([a, b])]) == merge([a, b])`, but `merge` takes
`ReplicaSnapshot`s and returns a `MergeResult`, so the property cannot be
written without a conversion. `replicaId` is arbitrary, which the merge's
refusal to read it makes safe — and a test asserts that refusal directly.

**D-M2-7 — A second, targeted generator exists for §9.3 step 6's name
re-pass.**
The random generator reaches that branch essentially never: it needs an archived
record to win the primary slot, carry its name out, be un-archived by the INV-2
repair, *and* land on a name another active Task holds. Measured over 300 seeds
the four never coincided, so the properties were covering the riskiest path in
the merge not at all. `archivedNameCollisionReplicas()` builds the shape and
randomizes everything else, reaching the re-pass in about 70% of seeds, and the
property group over it includes a **coverage assertion** so it cannot quietly
become vacuous later.

**D-M2-8 — Step-4 field resolution lives in its own file.**
§11.11 asks that files stay under roughly 400 lines. `name_union_merge_strategy`
reached 489 with the field rules inline, so `field_resolution.dart` holds how a
single field resolves, `record_order.dart` holds only ordering, and the strategy
reads as §9.3's numbered steps. No behaviour changed.

**D-M2-9 — The convergence simulation is deliberately absent.**
§11.12 item 3 needs two in-memory replicas and a script of user operations
interleaved with sync points, which means the orchestrator. It belongs to M6 and
is noted there, not skipped.

## M3 — `zen_data`

Eleven ambiguities in §11.5 and §3.7 were found before any code was written and
put to the owner; all eleven were accepted and folded into **`ZEN_SPEC.md`
v1.5**, so they are specification, not decisions, and are not repeated here.
What follows is what v1.5 still leaves to the implementer.

**D-M3-1 — The schema is declared in SQL (`.drift` files), not in Dart's table DSL.**
§11.5.2 presents its constraints as SQL, and this schema is unusually
constraint-heavy: thirty-odd named `CHECK`s, two partial unique indexes and
seven triggers. Dart's `customConstraints` turned out to be the worse option on
both counts that matter. `drift_dev` reports *"Drift can only verify custom
constraints set as constant string literals"*, so a constraint built from a
helper is passed through unvalidated — and even a literal one is only checked,
never read back. In a `.drift` file every statement is parsed and validated at
build time, the `CREATE TABLE` reads as §11.5.2 writes it, and the triggers and
indexes sit beside the table they defend. The cost is that table classes are
named after their tables, which collides with `zen_domain`'s `Settings`;
`AS IdeaRow`, `AS TaskRow` and so on keep the row classes clear of the entities,
and the one remaining clash is hidden at its two import sites.

**D-M3-2 — Tables are `STRICT`.**
Not required by the specification. SQLite's default typing would accept an
integer in `name` or a blob in `status`, and this is the layer §11.5.2 calls the
only enforcement that executes in a release build, so the extra rigour is worth
the two lines it costs. Verified by a test: `cannot store TEXT value in INTEGER
column tasks.is_archived`.

**D-M3-3 — Timestamps are `TEXT` columns encoded by the mapper, and
`store_date_time_values_as_text` is set anyway.**
These pull in opposite directions and both are deliberate. `STRICT` permits only
`INT`, `INTEGER`, `REAL`, `TEXT`, `BLOB` and `ANY`, so a `DATETIME` column —
which is how drift's own `DateTime` mapping is declared — is not available. The
mapper therefore encodes and decodes instants itself, in `mapping/instants.dart`,
which is where §3's truncation at the storage boundary belongs in any case. The
build option stays set because it costs nothing and because a `DATETIME` column
added later, by someone who has not read this entry, would otherwise silently
store Unix seconds — the defect that prompted v1.5.

**D-M3-4 — Enums are stored by name, never by index.**
`TaskStatus` is declared in *merge-precedence* order (§9.3 step 4) and
`Timeframe` in urgency order, so both indices are chosen for the algorithm
rather than for storage, and storing an index would let a later reordering
rewrite every row's meaning in silence. The names are also what §11.5.2's SQL
compares against (`status = 'done'`), and a `CHECK … IN (…)` on each column
keeps the vocabulary closed.

**D-M3-5 — The repositories do not pre-check NAME-6; the UI still does.**
§11.5.2 settles this ("Violations are detected by attempting the write"), and
M3's definition of done makes it testable: AC-8, AC-9 and AC-10 must exercise
the partial index rather than an application check. So the repositories attempt
the write and translate the failure, and `findActiveByNormalizedName` and
`activeNormalizedNames` exist for the UI's live feedback (NAME-8) and its
`"Open it"` link. The index cannot tell NAME-8 from NAME-9 — both are the same
collision on the same index — so the caller names which violation it is:
`TaskNameCollision` when saving, `ActiveTaskHoldsName` when restoring or
unarchiving. The mapping keys on SQLite's numeric extended result codes (2067,
1555, 275, 1811, 787), never on message text, which varies between builds.

**D-M3-6 — The repositories append to the event log inside their own transactions.**
§11.4.6 declares `EventLog` beside the other repositories and never says who
writes to it. HIST-2's log is only trustworthy if an entry commits with the
change it records: written afterwards, it loses exactly the entries that would
explain a crash. STORE-3 already requires these operations to be atomic, so the
entry joins a transaction that is there anyway. `EventRecorder` derives what to
write by comparing the record before and after, so a save that changed a name
and a tag produces `renamed` and `tagsChanged` rather than one vague entry, and
a save that changed nothing produces none.

**D-M3-7 — `TaskRepository.update` deletes the Task's rows and re-inserts them.**
The INV-2 triggers make an in-place update order-dependent with no correct
answer. Writing the task row first fails when a Task becomes `Done` while its
old subtask rows are still open; writing the subtasks first fails when a `Done`
Task is reopened, because the new open subtasks land under a parent that is
still `Done`. Removing the old rows first leaves neither trigger anything to
object to. It is the same argument §11.6.5 makes for applying a merge, and it is
safe here because `update` rewrites every one of that Task's rows regardless;
the subtask and tag rows follow through `ON DELETE CASCADE`.

**D-M3-8 — A rule's refusal rolls the transaction back rather than committing it.**
Returning an `Err` from inside `transaction` would commit it. Nothing has been
written at that point, but rolling back is the honest outcome and it keeps the
refusal and the constraint translation on one path, so `_RuleRefused` carries
the violation out and it is converted back at the boundary.

**D-M3-9 — `tools/verify.ps1` and `ci.yaml` regenerate the Drift output and fail
if it is stale.**
D-M0-12 commits `*.g.dart` on purpose, which makes "committed but not
regenerated" a real failure mode that otherwise surfaces late and confusingly.
Both now run `dart run build_runner build` in `zen_data` and then require
`git status --porcelain` to be empty over the four generated paths —
`git status` rather than `git diff`, so output that was never added at all is
caught too, and scoped to those paths so work in progress elsewhere is not
mistaken for it. The build runs before `dart format`, because the analyzer
excludes generated output and the formatter cannot.

**D-M3-10 — Drift's `schema generate` output is excluded from analysis.**
`test/generated_migrations/` is generated exactly like `*.g.dart` and committed
for the same reason (§11.5.3, D-M0-12), but is not named like it, so the root
`analysis_options.yaml` excludes `**/generated_migrations/**`. Without it,
strict-raw-types reports nine warnings in a file nobody writes.

**D-M3-11 — Opening the database returns a value, and a corrupt file is
quarantined rather than replaced.**
§11.5.5 forbids both crashing to a blank screen and silently creating an empty
database over the top. `openDatabase` therefore returns `DatabaseOpened` or
`DatabaseUnreadable` rather than throwing, runs `PRAGMA integrity_check` before
handing the database back, and renames an unreadable file to
`<path>.unreadable-<instant>` so nothing is destroyed. The instant is a
parameter, not a clock reading (§11.11). The recovery screen itself is M4's.

**D-M3-12 — Settings are a key-value table, and a malformed value falls back to
its factory default.**
§11.5.1 asks for key-value; the encoding is one string per key, with the
expanded-group set as comma-separated `Timeframe` names — the empty string being
the legitimate "all collapsed". §11.5.5 says a failure must not present as data
loss and §3.6 gives every key a default, so an unparseable value reads as that
default rather than crashing the app. An unrecognised group name is dropped from
the set instead of failing the whole set: losing one group's expansion state is
a smaller harm than resetting all four.

**D-M3-13 — INV-6's length limits are a sound superset, and one thing is not
enforceable at all.**
NAME-2 and NAME-3 count Unicode extended grapheme clusters; SQLite's `length()`
counts UTF-16 code units, so §11.5.2's "generous ceiling" is 16,000 code units
for a name — sixteen per cluster, far beyond anything real, so the bound can
never reject a name `ItemName.parse` accepts. What SQL *can* state exactly is
enforced: non-empty, trimmed (NAME-1), free of line breaks (NAME-4), and for
tags free of whitespace and of a leading `@` (TAG-1, TAG-2). Separately, nothing
in SQL can assert `name_normalized = normalizeName(name)`; the mitigation
§11.5.2 names is implemented as one mapper plus a test that drives every write
path — create, update, convert, soft delete, restore, unarchive and the archive
sweep — and re-derives the normalization for every row. That test includes a
hand-written stale row, so it fails if it is ever weakened into a tautology.

**D-M3-14 — `ArchiveSweeper` does the arithmetic; scheduling the timer is M4's.**
§11.5.4 wants the sweep at app start, on foreground, and on a timer at the next
boundary. The first two are `sweep()` and the third needs `nextBoundaryAfter`,
both of which are here; the timer itself needs the app lifecycle and belongs
with the composition root.

**D-M3-15 — `ReplicaRepository` seeds its row on first read, with an injected
device name.**
§11.5.1 says the replica id is "generated on first launch", and the device name
comes from the platform, which only `zen_app` can ask (`device_info_plus`, M4).
So the row is created on first read from an injected `IdGenerator` and a default
name, and `setDeviceName` exists for the pairing screen (§11.6.4).

**D-M3-16 — §11.5.1's first line still lists the old tag tables.**
Reported rather than fixed silently. Line 812 of `ZEN_SPEC.md` v1.5 still reads
"`ideas`, `tasks`, `subtasks`, `tags`, `item_tags`, …", which the bullet three
lines below it replaces with `idea_tags` and `task_tags`. The bullet is the one
v1.5 rewrote and is what the schema implements; the list is an editorial
leftover. `schema_test.dart` asserts that neither `tags` nor `item_tags` exists,
so a future reader who follows the stale line will be told.

## M4 — `zen_app` capture path

**D-M4-1 — The platform folders are generated with `flutter create`, and its
boilerplate is discarded.**
D-M0-6 deferred `android/` and `windows/` to this milestone. They were created
with `flutter create --platforms=windows,android --org dev.zen --overwrite .`,
which also overwrote `pubspec.yaml` and `analysis_options.yaml` and wrote a
`lib/main.dart`, a `test/widget_test.dart` and a `README.md`. The two config
files were restored from git and the three boilerplate files deleted. The
generated per-package `.gitignore` was deleted as well, and the handful of
entries it added that the root one lacked were moved there, because two ignore
files disagreeing is worse than one long one. `.metadata` is committed, as
Flutter intends: `flutter create` and `flutter migrate` read it.

One thing `flutter pub get` insists on: with platform folders present it rewrites
`packages/zen_app/analysis_options.yaml` to exclude `android/**` and `windows/**`.
Neither holds Dart, so the exclusion changes nothing, but it is re-added on every
resolve — so it is committed rather than fought with.

**D-M4-2 — The three Android API levels are written out, not inherited.**
§11.2 fixes `compileSdk` 36, `targetSdk` 36 and `minSdk` 26. Flutter 3.47.5's own
defaults are **36 / 36 / 24**, so a `minSdk` taken from `flutter.minSdkVersion`
would silently be 24 — two API levels below the specification. All three are
therefore literals in `android/app/build.gradle.kts` with a comment saying why,
and a Flutter SDK upgrade cannot move them. The `release` build type still signs
with the debug keystore, which M8 replaces (§11.9); the comment there says so, so
that an APK built today is not mistaken for a release artifact.

**D-M4-3 — `flutter_timezone` supplies the device's IANA zone.**
EOD-5 computes boundaries "in the device's current local time zone", and
§11.4.3's `TimeZoneRules` port takes an IANA zone id. Nothing in §11.2's table
produces one: `DateTime.timeZoneName` gives a Windows display name or an
abbreviation, neither of which `package:timezone` can look up. `flutter_timezone`
5.1.0 supports Android and Windows and does exactly this one thing, so it is
added under a role §11.2 did not anticipate. It is read once in `main.dart` and
handed to `SystemClock`; if the platform call throws, the app starts in `UTC`
rather than refusing to start, which is the posture §11.5.5 takes everywhere
else. A wrong zone moves the End-of-Day boundary, so this is a last resort and
not a default.

**D-M4-4 — The database is opened before `runApp`, and `main.dart` is the
composition root.**
NAV-3 forbids a loading screen beyond platform minimums, so the alternative — a
`FutureProvider` that every screen unwraps — would put a spinner in front of Home
on every cold start and an `AsyncValue` in front of every widget. Instead
`main.dart` opens the database, reads the settings once and resolves the zone,
then overrides `databaseProvider`, `initialSettingsProvider`,
`localZoneIdProvider` and `deviceNameProvider` on a `ProviderContainer`. Those
four throw `UnimplementedError` if read un-overridden, which is Riverpod's idiom
for "supplied by the composition root". `main.dart` is consequently the only file
that touches `dart:io`, the only one that reads a clock, and the only one that
asks the platform anything.

`currentSettingsProvider` is what every screen reads: the live stream once it has
emitted, and `main.dart`'s one-shot read until then, so the first frame already
has the right theme.

**D-M4-5 — `updateTask` joins `zen_domain`'s task rules.**
M1 built the individual §4.2 and §4.3 rules, which is everything the To Do list
needs, but the Edit Task screen saves name, status, tags, description and the
whole subtask list at once. Chaining the individual rules cannot do that: an
intermediate `Task` carrying the new status with the old subtasks violates INV-2,
and `Task`'s constructor asserts. `updateTask` is therefore one call that checks
NAME-8 against the Task's own name, checks TASKFORM-6's INV-2 condition against
the *form's* subtask list, and constructs the result in one step. It is the exact
shape `updateIdea` already had, and for the same stated reason: so the checks
cannot be forgotten. §11.7 is what puts it in `zen_domain` rather than in the
screen — "if a decision needs a test, it belongs in `zen_domain`".

**D-M4-6 — A subtask row left blank is dropped on save, not refused.**
TASKFORM-2 appends a row and focuses it; nothing in §5.4 says what happens if the
user then saves without typing. Refusing the save would block on a row the user
never meant to add. SUB-7 hard-deletes a subtask with no recovery, so discarding
an empty row is the same outcome as the delete button that row already carries.
The simplest behaviour consistent with §5.4 is therefore to drop it silently.

**D-M4-7 — The completion circle is drawn as paths, not glyphs.**
TODO-3 specifies a checkmark and a ✕, which an icon font would supply. §11.12
requires golden tests for exactly these three states, and a golden containing a
glyph depends on font rasterization, which differs between machines. Drawing both
with `CustomPainter` removes that dependency — the goldens then rest on the
rasterizer alone. The colours come from the active `DecorPack`, never from a
literal, so DECOR-3's "a new const plus a registry line" holds for them too.

**D-M4-8 — Golden tests run on Windows only.**
§11.12 asks for goldens for TODO-3's three circle states and their disabled
variants. Goldens are platform-sensitive, and `ci.yaml` runs on `ubuntu-latest`
while the images can only be generated here. Rather than commit images that fail
on the machine that checks every push, the golden test is skipped off Windows
with the reason in the skip message. CI reports them as skipped;
`tools/verify.ps1`, which is run before every commit, executes them. Once the
workflow has run at least once, a second set can be generated on Linux with
`--update-goldens` and selected by platform. Recorded as an open verification
item below.

**D-M4-9 — Two screens show controls for features that do not exist yet.**
§11.5.5's recovery screen must offer `"Restore from backup…"` (§11.6.6) and
`"Import snapshot…"` (§11.8), and SET-4 requires a `"Sync"` section holding
§11.8's settings and actions. Every one of those belongs to `zen_sync`, which M6
and M7 build. Both are rendered with their controls present and disabled, under
one line saying sync is not built yet. Omitting them would read as a feature that
was forgotten rather than one that is coming, and on the recovery screen in
particular an absent button reads as "there is no way back", which is the
opposite of what §11.5.5 wants that screen to say.

**D-M4-10 — `TaskRepository.watchAll` and `IdeaRepository.activeNormalizedNames`
were added to the interfaces.**
SEARCH-2 filters Tasks on `Todo / Blocked / Done / Archived / Deleted`, and a
soft-deleted Task appears in neither `watchActive` nor `watchArchived`. Without
`watchAll` the Search screen would have to reach past the repository, which
STORE-2 forbids. `activeNormalizedNames` already existed on
`DriftIdeaRepository` but had never been declared on `IdeaRepository`, unlike its
`TaskRepository` twin; NAME-8's live feedback on the Idea form needs it, so the
asymmetry is closed rather than worked around.

**D-M4-11 — Search matching and ARCH-1's day grouping live in `zen_domain`.**
Both are decisions that need a test, which §11.7 puts in `zen_domain` rather than
in a provider. `SearchQuery` (`search/search_query.dart`) holds SEARCH-1's
matching and SEARCH-2's three filters; `logicalDayOf` sits beside
`archiveBoundaryAfter` in `time/end_of_day.dart`. SEARCH-1 says "case-insensitive
substrings", and the normalization it uses is §2's — the same one NAME-5 uses —
so a search for `buy  MILK` finds `Buy milk`, and accent composition does not
change the result.

`logicalDayOf` is derived rather than chosen: AC-6 fixes that a Task completed
Tue 23:10 with EoD 02:00 appears "under Tuesday", and so does one completed Wed
01:30, because both cross the same Wed 02:00 boundary. The logical day of an
instant is therefore the date of the boundary it will cross, less one day.

**D-M4-12 — A name field that opens with text in it shows its message at once.**
IDEAFORM-2 delays validation messages until "the user has typed and then paused
or blurred the field", so that a message does not accuse the user mid-word. A
name the screen arrived with — Edit mode's stored name, or CONVERT-1's pre-fill —
has already settled, and CONVERT-3's colliding pre-fill would otherwise disable
the confirm button with no explanation on screen, which NAME-8's "an inline
message is shown" does not allow. The delay therefore applies only to a field
that started empty.

**D-M4-13 — `ArchiveScheduler` reschedules after every sweep.**
EOD-3's three triggers are app start, foreground, and each boundary while the app
runs. The third is a `Timer` set from `ArchiveSweeper.nextBoundaryAfter`, re-armed
after every sweep rather than set once on a fixed period. That is what makes
EOD-4 work without extra machinery: changing `settings.endOfDay` moves the next
boundary, and the timer is derived from the setting each time it is set. The
delay is floored at one second, because `nextBoundaryAfter` is only guaranteed to
be *strictly* after the instant it is given, and a one-millisecond timer could
re-fire before the sweep that set it had committed.

**D-M4-14 — Widget tests read Drift streams through `runAsync`.**
`testWidgets` runs its body against a fake clock. A Drift stream's first emission
is scheduled on a timer the fake clock never fires while the test body is merely
awaiting, so `await repository.watchAll().first` hangs until the test times out —
a failure mode worth naming, because it presents as the screen being broken. The
harness's `readStream` wraps that one await in `tester.runAsync`. Plain futures
(`findById` and friends) need none of it.

**D-M4-15 — The widget tests run against a real in-memory database.**
§11.13.1 puts M4 and M5's widget tests in the headless column, and
`NativeDatabase.memory()` needs no device. Faking the repositories would prove
only that a screen agrees with the fake: the rules the screens call are
`zen_domain`'s and are already tested there, and the constraints that actually
guarantee them are `zen_data`'s. So the tests drive the real screens over the
real schema and assert against what was persisted.

**D-M4-16 — `ndkVersion` is pinned too, and the NDK is installed by hand.**
The Android build needs an NDK: `sqlite3` 3.6.0 ships a native-assets
`hook/build.dart` with `native_toolchain_c`, and `sqlite3_flutter_libs`, pulled
in transitively by `drift_flutter`, compiles SQLite from C through CMake. So
`ndkVersion` cannot simply be dropped. It is pinned to **28.2.13676358** — the
version M4 was verified against — for D-M4-2's reason and one sharper: Gradle
responds to a version it does not have by shelling out to `sdkmanager`, and on
this toolchain that is broken. `cmdline-tools` 23.0 deprecated `sdkmanager` in
favour of a new `android` CLI, and its shim crashes with `0xC0000409`
(STATUS_STACK_BUFFER_OVERRUN) instead of failing cleanly, so the build reports
`Package ndk not found` and points at an unrelated line of
`android/build.gradle.kts`. The NDK is therefore installed deliberately rather
than on demand:

```
android sdk install ndk/28.2.13676358
```

(`android.exe` lives in `cmdline-tools/latest/bin`; the old
`sdkmanager "ndk;28.2.13676358"` coordinate form is what no longer works.)

---

**D-M4-17 — NFR-2 is met, and the startup cost is almost entirely the engine.**
Measured on 2026-09-24 with `flutter run --profile --trace-startup`, profile
rather than release because release disables the VM service and
`--trace-startup` then has nothing to read. Profile is AOT-compiled exactly as
release is, so the figures are representative.

| | Android (Galaxy S20 FE, first launch after install) | Windows (existing database) |
|---|---|---|
| `timeToFrameworkInit` | 360 ms | 946 ms |
| `timeAfterFrameworkInit` | 834 ms | **42 ms** |
| `timeToFirstFrame` | 1.19 s | 988 ms |

The two `timeAfterFrameworkInit` figures are the same code — `main()`'s four
platform round trips, `openDatabase` with its `PRAGMA integrity_check`, the
settings read and the first archive sweep. The difference is that the Android
run was the **first launch after install**, where `openDatabase` creates the
whole schema, every index and all seven triggers rather than opening an
existing file. Steady state is the Windows number: **42 ms**, which is nothing.

Cold start from the home screen on the phone, release build, measures about
**500 ms** by stopwatch, which is what 360 ms of engine plus ~40 ms of our code
plus Android process start should come to. NFR-2 asks for "under 1.5 s on a
mid-range Android device" from cold start to a focused name field. **Met, with
room.**

Two conclusions follow, and they point away from work rather than towards it.
Deferring `_deviceName()` and moving `ArchiveScheduler.start()` after `runApp`
were both considered — neither is worth doing, because together they are a
fraction of 42 ms and both would trade a measurable guarantee (EOD-3 running
before anything is on screen) for an unmeasurable saving. And the earlier
reading of ~1.5 s on both platforms was a **debug** build: Dart under JIT from a
kernel blob, assertions live — including the `invariantFailures` check every
`Task`, `Idea` and `Subtask` constructor runs, which release strips entirely —
and the VM service attached. Debug startup is not evidence about NFR-2.

Both traces were first-launch-after-build with cold file caches, so both engine
figures are pessimistic; Windows' 946 ms especially, against a freshly linked
executable.

---

## M5 — the remaining screens

**D-M5-1 — Archived and deleted Tasks open through the ordinary Edit Task
route, which reads their state.**
ARCH-3 opens an archived Task "in **read-only** mode … plus an `"Unarchive"`
action", and SEARCH-3 does the same for a deleted one with `"Restore"`. Neither
is a separate screen: `TaskFormScreen.edit` asks the Task whether it is active
and renders accordingly, so a Task opened from the archive, from search or from
a stale link behaves the same way wherever the link came from. The alternative —
a `readOnly` flag on the route — would let a caller open an archived Task
editable, which STATUS-4 forbids and which the domain would then have to refuse
at save time with a violation the user never sees.

**D-M5-2 — IDEAS-2's group toggles are local state, seeded from the setting.**
"On entering the tab, a group is expanded if and only if it is in
`settings.expandedIdeaGroups`. Tapping a header toggles that group. The toggle
lasts until the user leaves the Review screen; it does not change the setting."
So the tab copies the set into its own state on first build and mutates the copy;
nothing is written back. Leaving Review disposes the state, which is exactly the
lifetime the rule asks for.

**D-M5-3 — The Search screen filters in memory over two streams.**
SEARCH-1 matches "name, tags, context/description and subtask names", which
spans four tables, and SEARCH-2's Deleted filter reaches rows no other screen
shows. A SQL search would need `LIKE` over a join plus its own normalization,
duplicating §2's — and the normalization is the thing §11.5.2 warns must exist in
exactly one place. Filtering `ideasProvider` and `allTasksProvider` with
`SearchQuery` keeps one definition of a match, keeps it testable in `zen_domain`,
and costs nothing at this product's scale: this is one person's task list, not a
corpus.

**D-M5-4 — Settings write on change, with no local copy.**
SET-2 says "Changes apply immediately and persist", so each control writes
straight through `SettingsRepository` and the screen renders
`currentSettingsProvider`. There is no draft state and therefore no way for the
screen to disagree with what is stored — which also means the theme and the decor
react the moment the control moves, without a save step DECOR-1 would have to
work around.

**D-M5-5 — The test viewport is 800 × 2400.**
`ListView`'s child delegate is lazy, so a control below the fold is not in the
widget tree at all and a finder for it matches nothing — a failure that reads as
"the screen has no Save button" rather than "the screen is taller than the
viewport". Both form screens are longer than the default 800 × 600 test view, so
`ZenHarness.pumpApp` sets a tall one. NFR-7's responsiveness is tested
separately and deliberately, at 400 px wide, in `shell_test.dart`, where an
overflow is asserted not to happen rather than merely not to be noticed.

**D-M5-6 — ROW-5's geometry is asserted, not eyeballed.**
Its numbers — 16 px from the text block, a 48 × 48 touch target, 24 px between
consecutive rows' buttons — exist so that a mis-aimed tap cannot consume the
wrong Idea, which is a data-loss-shaped mistake rather than a cosmetic one. They
are checked with `tester.getRect` in `shell_test.dart` rather than left to a
golden, because a golden would tell you the picture changed without telling you
which rule broke.

## M6 — `zen_sync`

Sixteen ambiguities in §11.6 and §11.8 were found before any code was written
and put to the owner; all sixteen were accepted and folded into
**`ZEN_SPEC.md` v1.11**, so they are specification, not decisions, and are not
repeated here. Two of them were defects that would have shipped: §11.6.5 step 3
ended the pass when no peers were found, which meant two fresh devices could
never discover each other and the file transport would never have worked at all;
and §11.6.2's transport signature could not supply the `generatedAt` that step 3's
de-duplication compares.

What follows is what the specification left open and this milestone chose.

**D-M6-1 — `FileSnapshotTransport` writes through a `SnapshotDirectory` port.**
§11.6.3 gives one transport with two platform mappings: an ordinary path on
Windows and a SAF tree URI on Android. SAF needs a Flutter platform channel,
which a pure Dart package cannot have, so the transport is written against a port
and `zen_app` supplies `SafSnapshotDirectory` — the same shape §11.2 uses for
`TimeZoneRules`, where "the domain declares the one-method port; the data layer
implements it". The payoff is that everything §11.6.3 actually specifies — the
filename, the read filter, the body-over-filename rule, the temp sweep, the
unchanged-content check — is tested headlessly against `IoSnapshotDirectory` and a
real temporary directory, and what is left unverifiable is only the platform
mapping (§11.13.1).

Note that `zen_sync` uses `dart:io` directly and unapologetically. §11.1 bans IO
in `zen_domain` only; this is the package where it belongs.

**D-M6-2 — The codec's internal control flow is an exception; its boundary is a
`Result`.**
§11.4.1 reserves exceptions for programmer error, and a malformed peer file is
not that. But threading a `Result` through thirty nested field reads buries the
shape of the format under plumbing, so `SnapshotCodec` throws a private
`_Malformed` internally and converts it at every public entry point. The rule
holds where it matters — no caller of `decode` or `fromJson` sees an exception —
and the parsing code still reads like §11.6.1's document.

**D-M6-3 — An entity's invariants are checked twice, because only one check runs
in any given build.**
The entity constructors `assert` their §3.7 invariants, and §11.5.2 already
records that Dart strips asserts from release builds. So decoding a Task with
`status: done` and no `completedAt` throws in a test and succeeds silently in the
app the owner runs. `SnapshotCodec._guard` therefore catches `AssertionError`
*and* re-checks `invariantFailures` afterwards, and both paths end in the same
refusal. Without the second check, §11.6.1's all-or-nothing rule would hold in CI
and not in production — which is the worse half to lose, because production is
where the malformed file comes from.

**D-M6-4 — The codec also checks INV-6 and INV-7, which span the dataset.**
§11.6.1 says "a field that would break §3.7" and §3.7 includes both. A replica's
own database enforces them — the partial unique indexes and the `inv7_*`
triggers — so a snapshot that breaks either did not come from a healthy replica.
This is deliberately *not* the case the merge exists to handle: that one is two
replicas each internally consistent but disagreeing with **each other**, which is
across snapshots, not within one. Catching it here also stops a bad file reaching
`replaceAll`, where the same violation would surface as an aborted transaction
with a SQL error attached.

**D-M6-5 — A snapshot timestamp with no time zone is refused, not guessed.**
§3 makes every instant UTC. A bare local-time string has no defined instant, and
resolving it against *this* device's zone would make the same file decode
differently on two replicas — which breaks MERGE-2 quietly rather than loudly.
Finer-than-millisecond precision, by contrast, is truncated rather than refused:
§3 puts a truncation at "the snapshot-parsing boundary" precisely so a peer
cannot smuggle precision in, and a peer writing microseconds is not a reason to
drop its data.

**D-M6-6 — Which transports are enabled is injected as a function.**
§11.6.5 runs "each **enabled** transport", and §11.8 decides enabled with
`syncFolderEnabled` and `syncLanEnabled`. Reading those inside the orchestrator
would make it know both the settings keys and which transport each belongs to,
and §11.6.5 is explicit that nothing there may special-case a transport. So the
orchestrator takes an `EnabledTransports` callback and `zen_app` closes over the
settings. It is re-read on every pass, so turning a transport off takes effect at
once (SET-2), and M7 adds a second entry to one list in one provider.

**D-M6-7 — A failed pre-merge backup logs and the pass continues.**
§11.6.5 step 4 says to write one and does not say what to do when it cannot be
written. Refusing to sync would mean a full disk stops the app syncing
altogether; merging without insurance loses the recovery path for that one pass.
The pass continues, because §11.6.5's posture everywhere else is that nothing
aborts it and NFR-1 forbids a sync failure from getting in the user's way. The
failure is logged and recorded. This is the one place in M6 where the safer
choice was not obvious, and it is recorded rather than buried.

**D-M6-8 — `merged` events are appended outside `replaceAll`'s transaction.**
§11.6.5 step 6 asks for both in one breath, but STORE-4 deliberately keeps
`events` out of the wholesale replace, and `DatasetRepository.replaceAll` takes a
snapshot, which carries no events. A crash between the two loses some entries
from a log the MVP never reads back (HIST-2). That is a better trade than
coupling the audit trail to the dataset's lifetime, which is the very thing
STORE-4's "`events` is deliberately outside this" exists to prevent.

**D-M6-9 — `syncWith` waits for an in-flight pass rather than joining it.**
§11.6.5 step 1's single-flight rule says a second request "returns the running
one's future". That is right for the three triggers, which are interchangeable.
It is wrong for `"Import snapshot…"`, which carries a file the user chose:
joining would return the other pass's outcome and discard the import silently. So
`sync()` joins and `syncWith()` queues. Both take the same lock, so two passes
still never overlap.

**D-M6-10 — `Settings.withoutSyncFolder()` exists because `copyWith` cannot clear
a field.**
The `?? this.x` idiom cannot set a nullable field back to null, and
`syncFolderLocation` is the one setting the user can genuinely clear — they picked
a folder and want it forgotten. A dedicated method rather than a sentinel value or
a `clearX` flag: one caller, one name, nothing to misread. `lastSyncAt` needs no
twin, because it only ever moves forward.

**D-M6-11 — Export on Android goes through SAF, not `file_selector`.**
`file_selector_android` implements `openFile`, `openFiles` and `getDirectoryPath`,
and **no save dialog at all**, so `getSaveLocation` would throw
`UnimplementedError` at the moment the user tapped `"Export snapshot…"`. Import is
fine through `file_selector` on both platforms; export asks for a destination
folder with `saf_util` and writes with `saf_stream`. The grant it takes is
deliberately **not** persistable — an export is one file, once, and holding a
lasting permission on a folder picked for a single save is a permission the user
did not agree to keep.

**D-M6-12 — The recovery screen's two buttons now work, and say when they
cannot.**
D-M4-9 rendered §11.5.5's `"Restore from backup…"` and `"Import snapshot…"`
disabled because both belonged to M6. They rest on the quarantine D-M3-11 already
performs: once the unreadable file has been **moved aside**, opening the same path
again creates a fresh database and the recovered data can be written into it. When
it could not be moved aside there is nowhere to put one, so the buttons stay
disabled and the screen says why. Import there is a replace rather than §11.8's
merge — there is nothing to merge with — and the confirmation says so, rather than
letting the word "import" imply the gentler operation it means on the Settings
screen.

**D-M6-13 — The convergence simulation shares one clock between the replicas.**
Two independently drifting fake clocks put a Task's `createdAt` on one replica
ahead of its `updatedAt` on the other and broke INV-5 before any merge ran. That
is clock skew, not a merge bug, and nothing in §9 claims to survive it: §9.3
step 4 resolves by comparing `updatedAt` **across** replicas, which only means
anything if the two clocks agree. Real devices agree to within seconds. The
simulation advances one shared clock, and skips the advance about one step in six
so that identical `updatedAt` values — the case step 4's tie-breaks exist for —
actually occur.

The clock also jumps six to thirty-six hours about one step in eight. Without
that, forty one-to-five-minute steps never cross an End-of-Day boundary and the
archive sweep never fires: the simulation silently never archived anything. The
coverage assertion beside it is what caught that, and is why it is there.

**D-M6-14 — The convergence simulation lives in `zen_app/test/integration/`.**
§11.12 item 3 now places it, so this records only what it cost: nothing. `zen_app`
already depends on both `zen_data` and `zen_sync`, so no dependency arrow moved.
It runs 60 seeds of 40 operations each in about twenty seconds under
`flutter test`.

**D-M6-15 — Sync widget tests pump a bounded number of frames instead of
settling.**
While a pass runs the Sync section shows a `CircularProgressIndicator`, which
animates forever, so `pumpAndSettle` never settles and the ten-minute default
timeout is what ends the test. Anything that reaches the orchestrator pumps a
fixed number of short frames instead, which advances the fake clock enough for the
repositories' futures to complete and then stops. The indicator itself is right
for the UI and stays.

**D-M6-19 — Two files were split for §11.11, the same way D-M2-8 split the merge.**
`snapshot_codec.dart` reached 546 lines and `orchestrator.dart` 449, against
"files stay under roughly 400". `snapshot_json.dart` now holds the typed field
reads and the internal `MalformedSnapshot`, so what is left of the codec reads as
§11.6.1's document; `peer_collection.dart` holds step 3, which is the one step
of the pass with logic of its own — availability, per-transport failure
isolation, and cross-transport de-duplication — and therefore the natural seam.
The codec is 446 lines and stays that way: encoding and decoding one format are
the two halves that must mirror each other, and separating them would make the
pair easier to let drift apart than to keep in step. No behaviour changed.

**D-M6-18 — `SyncScheduler` takes a callback, not the orchestrator.**
All it needs is "run a pass", the orchestrator's own single-flight lock is what
keeps the three triggers from overlapping, and `SyncOrchestrator` is a `final`
class with seven repository dependencies. Narrowing it to
`Future<void> Function()` is what lets the *timing* — the only thing this class
decides — be tested without a database. That matters more than it sounds: a
15-minute timer that silently never fires looks exactly like a folder nobody has
touched, and nothing else in the suite would have noticed.

**D-M6-17 — `BackupStore.list` reads the directory synchronously.**
`Directory.list()` returns a stream whose events are never delivered under
`flutter_test`'s fake clock, which made §11.6.6's restore dialog — the one place
this is reached from the UI — impossible to test through the widgets at all.
`listSync` costs nothing here: the directory holds at most twenty small files, it
is application-private local storage rather than a folder a cloud client might be
streaming over a network, and it is read twice per sync at most. The sync folder
itself keeps the asynchronous listing, because that one genuinely can be remote.

**D-M6-16 — A malformed `lastSyncAt` row no longer throws out of
`SettingsRepository.read`.**
Found by a test written for §11.5.5, not by inspection. `decodeInstant` calls
`DateTime.parse`, which throws, and this table's standing rule is that "every read
falls back to the factory default when the stored value is malformed" — a settings
row the user cannot even see is not worth taking the app down over. It now uses
`tryParse` and falls back to "never synced".

---

---

## Verification status (§11.13.1)

§11.13.1 requires that no milestone be reported done on the strength of code
that has never run.

| Milestone | Verified | How |
|---|---|---|
| M6 | **Not yet — the headless half only** | Everything §11.13.1 puts in the left-hand column is done and green: 89 tests in `zen_sync` (the snapshot codec, the file transport against real directories, the pre-merge backup store and the orchestrator), 207 in `zen_data` (25 new, for `DatasetRepository.replaceAll` under STORE-4 and for §11.8’s settings), and 209 in `zen_app`. **The convergence simulation of §11.12 item 3 passes over 60 seeds**, against two real Drift databases exchanging snapshots through a real shared directory, asserting the replicas are field-for-field identical and that every §3.7 invariant holds; a coverage assertion beside it requires all sixteen user operations to occur across the seeds, and it is what caught the archive sweep never firing (D-M6-13). `dart analyze --fatal-infos --fatal-warnings` clean across all four packages, `dart format` clean. **`LanSyncTransport` is deliberately absent** — it is M7 — and the orchestrator is already n-ary and multi-transport, with a two-transport test to prove it. **What is not established:** the Android SAF path. §11.13.1 is explicit that "scoped storage, `ACTION_OPEN_DOCUMENT_TREE`, persisted grants, and grant revocation behave only on a real device", and none of it has run on one. `SafSnapshotDirectory`, `AndroidSyncFolderPicker` and `AndroidSnapshotFileExchange` are **written but never executed**: every method is a platform channel call. The logic above them is tested against `IoSnapshotDirectory`, which is the most that can be said. Steps S-8 to S-15 of `MANUAL_VERIFICATION.md` are what would settle it, and until the owner confirms them this row does not read "Yes". Windows sync (S-1 to S-7) and the export/import/restore flows (S-16 to S-24) are likewise unconfirmed by hand. |
| M5 | **Yes** | §5 is fully implemented and 87 tests are green under `flutter test` in `zen_app`. **AC-4** and **AC-5** pass on the Edit Task screen, **AC-10** passes through the Archived Tasks UI *and* through Search's Restore, and **AC-11** passes via the Edit Idea entry point as well as `"Make Task"`. §11.12 item 6's golden tests exist for all three TODO-3 circle states and all three disabled variants — **on Windows only** (D-M4-8); CI skips them. HOME-5's five shortcuts, NFR-7 at 400 px, ROW-5's three distances and §11.5.5's recovery screen each have a test. Confirmed by hand on **2026-09-24** alongside M4, over the whole of `MANUAL_VERIFICATION.md`. |
| M4 | **Yes** | The headless half: 349 tests in `zen_domain` (36 new, for `updateTask`, `logicalDayOf` and `SearchQuery`), 182 in `zen_data`, 87 in `zen_app`. **AC-1, AC-2, AC-3, AC-7** pass again as widget tests against a real in-memory database, and **AC-8, AC-9, AC-11, AC-12** pass through the screens. `dart analyze --fatal-infos --fatal-warnings` clean across all four packages, `dart format` clean. **"The app runs on both platforms" is now established by hand,** on **2026-09-24**, against `MANUAL_VERIFICATION.md`: W-1 through W-12 on Windows 10 22H2 built with Visual Studio Build Tools 2022 17.14.41, and A-1 through A-9 plus Z-1 and Z-2 on an `android-36.1` `x86_64` emulator (`Medium-Phone-API-36.1`). All accepted by the owner. Getting there needed three toolchain changes, none of them code: the VS 2022 C++ workload with CMake tools and the Windows 10 SDK, Android `cmdline-tools` plus accepted licences, and NDK 28.2.13676358 installed by hand (D-M4-16). Windows builds are run from an elevated terminal in place of Developer Mode, which is the owner's standing choice. **NFR-2 is measured and met:** about **500 ms** cold from the home screen on the phone, against a target of "under 1.5 s on a mid-range Android device". D-M4-17 has the `--trace-startup` split. |
| M3 | **Yes** | 182 tests green under `flutter test` in `zen_data`, plus 313 in `zen_domain` (16 new there, for EOD-2A, INV-8 and INV-9). Sixty-seven of the 182 are constraint tests written in raw SQL with the repositories bypassed: every `CHECK`, both partial unique indexes, all seven triggers, the foreign keys and the cascades are attacked and required to fail, and each assertion names the constraint that fired, so a test cannot pass because some other constraint objected first. AC-6, AC-8, AC-9 and AC-10 pass against a real in-memory database, with AC-8/9/10 reaching the partial index rather than an application check. The §11.5.3 harness is in place: `drift_schemas/drift_schema_v1.json` is committed and a test verifies the live schema against it. `dart analyze --fatal-infos --fatal-warnings` clean, `dart format` clean. §11.13.1 puts all of M3 in the left-hand column and that held — Drift ran headlessly throughout and nothing here needs real hardware. |
| M2 | **Yes** | 297 tests green under `dart test` (223 before M2, so 74 new), covering AC-13 through AC-19, every step and every field rule of §9.3, and the four property tests of §11.12 item 2 — order-independence, idempotence, invariant preservation against `datasetInvariantFailures`, and no resurrection — each over 300 seeds with the seed in every failure message. `dart analyze --fatal-infos --fatal-warnings` clean, `dart format` clean, and `zen_domain` still declares no dependency that touches IO. Pure Dart, so §11.13.1 puts this entirely in the left-hand column: there is nothing here that needs real hardware. |
| M1 | **Yes** | 223 tests green under `dart test`, covering every rule in §4, every invariant in §3.7, the validation in §3.1 and §3.5, the EoD calculator at exact boundary instants including both DST transitions, and AC-1, AC-2, AC-3 and AC-7 as pure domain tests. `dart analyze --fatal-infos --fatal-warnings` clean, `dart format` clean, and `zen_domain` still declares no dependency that touches IO (`test/architecture_test.dart`). |
| M0 | **Yes** | Flutter 3.47.5 / Dart 3.13.4 installed to `C:\src\flutter` on 2026-09-22 (archive SHA-256 checked against the release manifest). Every step of §11.10 run locally and green: `pub get` in all four packages, `dart analyze --fatal-infos --fatal-warnings` × 4 with no issues, `dart format --set-exit-if-changed`, `tools/check_no_datetime_now.sh`, `dart test` × 2, `flutter test` × 2. **Not yet observed on the GitHub Actions runner** — the workflow has never executed, since the repository has no remote. See the open item below. |

Nothing in this table may be treated as complete until its column reads "Yes".

### Open verification items

- **The Android SAF code has never executed.** `SafSnapshotDirectory`, `AndroidSyncFolderPicker` and `AndroidSnapshotFileExchange` are written against `saf_util` 3.1.0 and `saf_stream` 4.0.1 and are entirely platform channel calls, so nothing in the headless suite reaches them. Two things in particular are guesses until a device says otherwise: that SAF keeps the `.json` extension on a document created with `application/json` (if it does not, no peer will ever read the file), and that the delete-then-rename of §11.6.3 does not leave a `… (1).json` duplicate behind. Both are checked by S-9 and S-10 in `MANUAL_VERIFICATION.md`, and both fail *silently* if they are wrong — which is why they are the first things to look at.

- **The delete-then-rename window on Android is accepted, not measured.** §11.6.3 records that SAF offers no atomic replace, so there is a moment when this replica’s snapshot file does not exist. The argument that this is acceptable — absent is not torn, and a missing peer file costs one sync round — is sound, but it is an argument rather than an observation. If it ever proves to matter, the generation-numbered scheme §11.6.3 names is the upgrade, and it changes the filename convention on both platforms.

- **Nothing has run against a real folder-sync client.** The convergence simulation exchanges snapshots through a local directory, which is what Syncthing or a cloud drive presents — but not how it behaves. Partial files mid-replication, conflict copies (`… sync-conflict-….json`), and a peer’s file arriving before its contents do are all real and none is exercised. A conflict copy is at least harmless by construction: it does not match `zen-snapshot-*.json` unless the client preserves the extension, and if it does, the body’s `replicaId` still decides. S-15 is the step that would put this to the test.

- **`ci.yaml` has never run.** It is written against the same commands proven
  locally, but the repository has no GitHub remote yet, so the workflow, the
  `subosito/flutter-action@v2` pin and the Linux-vs-Windows line-ending
  handling are unproven. This resolves the first time the repository is pushed.

- **`PRAGMA integrity_check` scales with database size.** D-M3-11 put it on
  every open to satisfy §11.5.5, and it is a full scan of every page. It is not
  a startup cost worth acting on today — see D-M4-17, where the whole of
  `main()` measures 42 ms — but it grows with the file, and this app is meant
  to run for years. Worth re-measuring, not worth pre-optimising.

- **The goldens exist on Windows only** (D-M4-8). The Linux CI runner skips
  them, so they are not a check on every push, only on every local
  `tools/verify.ps1`. Once `ci.yaml` has run at least once, a second set can be
  generated there with `--update-goldens` and selected by platform.

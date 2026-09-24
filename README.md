# Zen

A personal [Zen To Done](https://zenhabits.net/zen-to-done-the-ultimate-simple-productivity-system/)
companion for Windows and Android. Zen holds two kinds of things: **Ideas**
(things you might do) and **Tasks** (things you intend to complete). It does not
hold judgements — no MITs, no Big Rocks, no weekly-review workflow. That is
deliberate; see principle 1.2.3 of the specification.

**[`ZEN_SPEC.md`](ZEN_SPEC.md) is the single source of truth.** Anything not
specified there is not invented: it is decided as the simplest behaviour
consistent with the spec and recorded in [`DECISIONS.md`](DECISIONS.md).

## Layout

Four packages, with dependencies flowing one way only (§11.1):

```
zen_app ──▶ zen_data ──▶ zen_domain
   └──────▶ zen_sync ──▶ zen_domain
```

| Package | What it holds | Tested with |
|---|---|---|
| `packages/zen_domain` | Entities, value objects, `Clock`, the rules of §4, the End-of-Day calculator, the merge of §9, repository *interfaces* | `dart test` |
| `packages/zen_data` | Drift schema, migrations, repository *implementations* | `flutter test` |
| `packages/zen_sync` | Snapshot format, both sync transports, the orchestrator | `dart test` |
| `packages/zen_app` | Flutter UI, Riverpod composition root, routing, theming | `flutter test` |

`zen_domain` is pure Dart and **must not** depend on Flutter, Drift, or anything
that touches IO. That constraint is load-bearing: the compiler is what enforces
the architecture. `packages/zen_domain/test/architecture_test.dart` fails the
build if it is ever relaxed.

Packages are wired with plain path dependencies. There is no monorepo tool, on
purpose (§11.1).

## Getting set up

The Flutter version is pinned in [`.fvmrc`](.fvmrc) and in CI so that both
machines and the build agree (§11.2).

```bash
# 1. Install FVM (https://fvm.app), then the pinned SDK:
fvm install
fvm use

# 2. Resolve dependencies in every package:
for p in zen_domain zen_data zen_sync zen_app; do (cd "packages/$p" && fvm flutter pub get); done
```

Without FVM, install Flutter **3.47.5** (Dart 3.13.4) directly and drop the
`fvm` prefix from every command below.

### Build prerequisites (§11.2)

- **Windows:** Visual Studio **2022** with the *Desktop development with C++*
  workload. Visual Studio 2026 is not supported for compiling Flutter Windows
  desktop apps; do not install it as the build toolchain.
- **Android:** `compileSdk` 36, `targetSdk` 36, `minSdk` 26.

## Everyday commands

Everything CI runs (§11.10), in CI's order, in one command:

```powershell
.\tools\verify.ps1
```

Its first step is `pub get` in all four packages, and that step is not
optional — see *Dependency resolution* below. Add `-SkipFlutter` to run only
the two pure Dart packages, which is the fast inner loop, or `-Clean` to
discard the current resolution and redo it. The script puts the SDK on PATH
itself if it is not there already; pass `-FlutterBin` if yours is somewhere
other than `C:\src\flutter\bin`.

`.github/workflows/ci.yaml` is the authority and `tools/verify.ps1` mirrors it.
Keep the two in step when either changes.

### Dependency resolution

Each package's `.dart_tool/package_config.json` maps `package:` imports to
directories in the pub cache. It holds absolute machine paths, so it is
gitignored and exists only where `pub get` has run — a fresh clone has none.

`dart analyze` does **not** create or repair it. Without it, analysis reports
every `package:` import as `Target of URI doesn't exist`, which reads like
hundreds of compile errors in working code. If that happens, the code is fine
and the resolution is missing:

```powershell
.\tools\verify.ps1 -Clean
```

The rules engine on its own runs in about a second, with no emulator:

```bash
cd packages/zen_domain && dart test
```

A single file, or a single test by name:

```bash
dart test test/time/end_of_day_test.dart
```

## Running the app

Every screen in §5 exists, and the whole layer is covered by widget tests that
run headlessly:

```bash
cd packages/zen_app && flutter test
```

Launching it is another matter, and it has never been done. §11.13.1 puts that
in the column marked "requires the owner's real hardware", and the machine this
was built on is missing both toolchains:

```bash
flutter run -d windows    # needs Visual Studio 2022 + "Desktop development with C++"
flutter run -d <device>   # needs the Android cmdline-tools and accepted licences
```

- **Windows.** §11.2 requires Visual Studio **2022** with the "Desktop
  development with C++" workload. Visual Studio 2026 is not supported for
  compiling Flutter Windows desktop apps. Windows also needs **Developer Mode**
  enabled (`start ms-settings:developers`), because building with plugins needs
  symlink support.
- **Android.** `flutter doctor --android-licenses`, and Android Studio's
  command-line tools component.

`MANUAL_VERIFICATION.md` is the checklist to work through the first time it
runs on each.

## Conventions

- Requirement IDs from the spec are named in doc comments where a rule is
  implemented (`/// §4.2, STATUS-2. …`) and in the test that verifies it
  (`test('SUB-8: adding a subtask to a Done task is rejected', …)`).
- Results, not exceptions: rules return `Result<T, RuleViolation>`. Exceptions
  are reserved for programmer error (§11.4.1).
- `DateTime.now()` is banned outside `zen_app` (§11.11). Rules take the instant
  as a parameter; services take a `Clock`.
- Immutable domain classes with hand-written `copyWith`, `==` and `hashCode`.
  No `freezed`, no code generation except Drift (§11.0).

## Progress

Milestones follow §11.13. See `DECISIONS.md` for what is verified and what is
still waiting on real hardware (§11.13.1).

| Milestone | State |
|---|---|
| M0 — repository skeleton | **done** — every §11.10 step green locally; `ci.yaml` itself unproven until first push |
| M1 — `zen_domain` model and rules | **done** |
| M2 — merge | **done** — `NameUnionMergeStrategy` per §9.3, with property tests over many seeds |
| M3 — `zen_data` | **done** — 313 domain + 182 data tests green; every constraint has a test that attempts the violation |
| M4 — capture path | **code done, tests green** — but "the app runs on both platforms" is unverified; see *Running the app* |
| M5 — remaining screens | **code done, tests green** — §5 fully implemented; goldens run on Windows only (D-M4-8) |
| M6 — `zen_sync` core | not started |
| M7 — LAN transport | not started |
| M8 — packaging | not started |

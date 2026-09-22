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

```bash
# The whole rules engine, in about a second, with no emulator:
cd packages/zen_domain && dart test

# Everything CI runs, in CI's order (§11.10):
for p in zen_domain zen_data zen_sync zen_app; do (cd "packages/$p" && dart analyze --fatal-infos --fatal-warnings); done
dart format --output=none --set-exit-if-changed .
bash tools/check_no_datetime_now.sh
(cd packages/zen_domain && dart test)
(cd packages/zen_sync   && dart test)
(cd packages/zen_data   && fvm flutter test)
(cd packages/zen_app    && fvm flutter test)
```

## Running the app

Not yet. The Flutter UI arrives in M4; `packages/zen_app` currently holds only
its pubspec and a placeholder library, and its `android/` and `windows/`
folders are generated at that point (see `DECISIONS.md`, D-M0-6).

What does exist is the whole rules engine, and it runs in about a second:

```bash
cd packages/zen_domain && dart test
```

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
| M1 — `zen_domain` model and rules | **done** — 212 tests green |
| M2 — merge | not started |
| M3 — `zen_data` | not started |
| M4 — capture path | not started |
| M5 — remaining screens | not started |
| M6 — `zen_sync` core | not started |
| M7 — LAN transport | not started |
| M8 — packaging | not started |

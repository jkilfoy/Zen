# Releasing Zen

How to cut a release. Roughly twenty minutes, most of it waiting for builds.

The one-time setup — creating the signing keystore, removing the old debug
build from the phone — was done for 1.0.0 and is not repeated. If you are on a
new machine, jump to [First time on a new machine](#first-time-on-a-new-machine).

---

## Before you start

- An **elevated PowerShell**. `flutter build windows` needs symlink support, and
  Developer Mode is deliberately off on this machine.
- **Close Zen** on the desktop. A running app locks `zen_app.exe` and the build
  fails. The script checks and tells you, but it saves a round trip.
- `packages\zen_app\android\key.properties` present, pointing at the keystore.

---

## 1. Decide the version

Edit one line — `version:` in `packages/zen_app/pubspec.yaml`:

```yaml
version: 1.0.1+2
```

`1.0.1` is what people see. **`+2` is the Android versionCode, and it must be
higher than the last release** — Android refuses to install a lower one, and the
only way past that refusal is an uninstall, which deletes the database. When in
doubt, check what the phone currently has:

```bash
adb shell dumpsys package dev.zen.zen_app | findstr versionCode
```

If the specification changed too, bump `Document version` in `ZEN_SPEC.md`. The
About row's spec version is checked against it by a test, so a mismatch fails
the build rather than shipping.

## 2. Check it's green

```powershell
.\tools\verify.ps1
```

Everything CI runs, in CI's order. Don't release on a red suite.

## 3. Build

```powershell
.\tools\package.ps1
```

Builds Windows, packages it with Inno Setup, then builds and signs the APK.
Check two things in the output: the version banner says what you expect, and the
signature section does **not** say `CN=Android Debug`. Both artifacts land in
`dist\`.

`-WindowsOnly` and `-AndroidOnly` do one half if you need them.

## 4. Install and check

**Windows** — run `dist\Zen-<version>-setup.exe`.

- SmartScreen warns. Expected: the binary is unsigned on purpose. "More info" →
  "Run anyway".
- No UAC prompt. The install is per-user.
- **Your Ideas and Tasks are still there.** If the lists are empty, stop — see
  below.
- Apps & features shows **exactly one** Zen.

**Android** — `adb install -r dist\Zen-<version>.apk`.

- It installs over the existing app. You never uninstall first.
- Open Settings ▸ About and confirm the version and spec version read right.

Then sync the two once, to confirm the release builds talk to each other.

## 5. Tag it

Only once the above passes:

```bash
git push origin master v1.0.1
```

Tag the commit the artifacts were built from. Nothing automated runs on the tag
— it's a bookmark so a future reader can rebuild exactly this.

---

## The rule

**Every release installs over the last. Zen is never uninstalled.**

If an install ever demands an uninstall first, **stop and work out why.** It
means the signing identity changed, and uninstalling to get past it destroys the
database. It is not an inconvenience to click through.

## Three things that must never change

| | Why |
|---|---|
| The signing keystore and its passwords | Without them no future release can upgrade an install. Unrecoverable. Keep a backup off this machine |
| The `AppId` GUID in `packaging/windows/zen.iss` | Inno Setup keys upgrade-in-place on it. A new one installs a *second* Zen beside the first |
| `CompanyName` / `ProductName` in `windows/runner/Runner.rc` | They decide where the database lives. Changing either doesn't move it — the app just starts empty |

## When something goes wrong

**`LNK1104: cannot open file ... zen_app.exe`** — Zen is running. Close it.

**The Windows app opens with empty lists** — the data path moved. Your database
is still at `%APPDATA%\dev.zen\Zen`. Don't add anything; check whether
`Runner.rc` was edited.

**Android refuses the install** — either the versionCode went backwards, or the
APK was signed with a different key. Check `key.properties` and compare the
fingerprint:

```bash
keytool -list -v -keystore <your>.jks -alias zen
```

**The build says the keystore is missing** — it is, and that's the script
refusing to fall back to debug keys. A debug-signed APK installs fine here and
can then never be upgraded.

---

## First time on a new machine

1. Flutter 3.47.5, Visual Studio 2022 with *Desktop development with C++*, and
   the Android SDK — see the README.
2. Inno Setup: `winget install -e --id JRSoftware.InnoSetup`
3. Restore the keystore from backup, and write `key.properties` from
   `packages/zen_app/android/key.properties.example`.

Creating a *new* keystore is not an option — it would orphan every existing
install. `MANUAL_VERIFICATION.md` section M8 has the full detail, and
`DECISIONS.md` D-M8-1 to D-M8-10 has the reasoning behind everything here.

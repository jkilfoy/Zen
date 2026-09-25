# Manual verification

`ZEN_SPEC.md` §11.13.1 divides the work into what can be proved headlessly and
what needs real hardware, and instructs the implementer to **stop and hand the
owner a written checklist** for the second column rather than claim a milestone
done on code that has never run.

This is that checklist. Each step names what to do, what you should see, and
what to report back.

> **M4 and M5: completed and accepted, 2026-09-24.** W-1 … W-12 on Windows 10
> 22H2 (Visual Studio Build Tools 2022 17.14.41), A-1 … A-9 and Z-1, Z-2 on an
> `android-36.1` `x86_64` emulator. Every step accepted by the owner.
>
> **A-2 was then re-measured properly.** The first reading of ~1.5 s was a
> debug build and told us nothing about NFR-2. On a release build, cold from
> the home screen on a Galaxy S20 FE, it is about **500 ms**; a
> `--profile --trace-startup` run puts our own `main()` at **42 ms** and the
> rest at the engine floor. NFR-2 is met with room. D-M4-17 has the figures.
>
> The sections below stand as the record of what was checked, and as the script
> to re-run after a change that could plausibly affect any of it.

---

## Why this file existed for M4 and M5

Everything else in these two milestones is in §11.13.1's left-hand column and is
proved: 349 tests in `zen_domain`, 182 in `zen_data`, 87 in `zen_app`, all
headless. What is not proved is the one thing widget tests cannot touch —
**launching the application**. §11.13.1 says so in as many words: *"M4's 'runs on
both platforms' is not established by widget tests, and this is the first
milestone where that applies."*

The machine this was built on could not attempt either build until three
toolchain gaps were closed. Recorded here because a fresh clone on a fresh
machine will hit all three:

| Platform | What was missing | What fixed it |
|---|---|---|
| Windows | Visual Studio **2019** Community, without the "Desktop development with C++" workload. §11.2 requires Visual Studio **2022** with it. (§11.2 also notes VS **2026** is *not* supported for Flutter Windows desktop.) | Visual Studio **Build Tools 2022** with that workload — and check the *Installation details* pane really includes **MSVC v143**, **C++ CMake tools for Windows** and the **Windows 10 SDK**. Flutter's error text names the VS 2019 component `MSVC v142`; that is a hardcoded message, not a requirement. |
| Windows | Developer Mode off, so the plugin symlinks a Flutter Windows build creates cannot be made. | Builds are run from an **elevated terminal**, which carries the symlink privilege. Developer Mode would do the same; the owner prefers not to enable it. Expect `build/` to end up owned by the elevated process — if `flutter test` later fails on a delete, remove `packages/zen_app/build` from that same terminal. |
| Android | `cmdline-tools` absent and the licences unaccepted. | Android Studio ▸ SDK Tools ▸ *Android SDK Command-line Tools*, then `flutter doctor --android-licenses`. |
| Android | **No NDK.** `sqlite3` builds from C on Android (D-M4-16), and Gradle's attempt to fetch the NDK itself fails: `cmdline-tools` 23.0 deprecated `sdkmanager` and its shim crashes with `0xC0000409`, which surfaces as `Package ndk not found` against an unrelated line of `android/build.gradle.kts`. | `android sdk install ndk/28.2.13676358`, using the new `android` CLI in `cmdline-tools/latest/bin`. `ndkVersion` is now pinned to that version so Gradle never tries to fetch another. |

---

## Before you start

```bash
# Windows toolchain, once:
#   Visual Studio 2022 Installer ▸ "Desktop development with C++"
#   start ms-settings:developers   ▸ Developer Mode: On
# Android toolchain, once:
#   Android Studio ▸ SDK Manager ▸ SDK Tools ▸ "Android SDK Command-line Tools"
flutter doctor -v
```

Report anything `flutter doctor` still flags before going further.

---

## M4 / M5 — Windows

| # | Step | Expected | Report |
|---|---|---|---|
| W-1 | `cd packages/zen_app && flutter run -d windows` | The app builds and a window titled **Zen** opens. | Any build error verbatim. |
| W-2 | Look at the first screen (HOME-1, NAV-3) | Two large regions, `Add` on top and `Review` below, a gear top-right. **No splash screen** beyond the platform's own. | How long from launch to the Home screen. |
| W-3 | Tap `Add` (HOME-2) | The top half becomes two equal buttons, `Idea` and `Task`, **without navigating**. Clicking elsewhere, or Back, restores the `Add` label. | Anything that navigates instead. |
| W-4 | `Idea` ▸ type a name ▸ `Add Idea` (HOME-3, IDEAFORM-4) | The name field is focused on arrival. After saving you land on Review's **Ideas** tab with the new Idea visible and briefly highlighted. | Whether the field was really focused. |
| W-5 | Quit the app and relaunch | The Idea is still there. This is the first time a **real database file** is involved rather than an in-memory one (§11.5.5). | Whether anything was lost. |
| W-6 | Find the file: `%APPDATA%\..\Local\dev.zen\zen_app\zen.sqlite` (or whatever `getApplicationSupportDirectory` resolves to on your machine) | One file, growing as you add items (STORE-1). | The actual path, so it can be recorded. |
| W-7 | `Ctrl+I`, `Ctrl+T`, `Ctrl+R`, `Ctrl+F`, `Esc` (HOME-5) | Add Idea, Add Task, Review, Search, and back, respectively. | Any that do nothing. |
| W-8 | Resize the window down to about 400 px wide (NFR-7) | Nothing overflows; the To Do rows and the `Make Task` buttons still lay out. | A screenshot if anything is clipped. |
| W-9 | Settings ▸ Appearance ▸ Theme: Light / Dark / System (DECOR-1) | The whole app changes immediately and the choice survives a restart. | Anything that does not repaint. |
| W-10 | Settings ▸ About (SET-3) | Shows the app version and `specification v1.8`. | The version string shown. |
| W-11 | Complete a task, then set **Settings ▸ End of day** to a couple of minutes from now and leave the app open (EOD-3) | At that moment the Task leaves To Do and appears under **Archived tasks**, grouped under today's date. | Whether the timer fired without touching the app. |
| W-12 | Minimise the app across an End-of-Day boundary, then restore it (EOD-3) | The sweep runs on foreground: anything due is archived. | Whether it archived without a restart. |

## M4 / M5 — Android

| # | Step | Expected | Report |
|---|---|---|---|
| A-1 | `cd packages/zen_app && flutter run -d <device>` | The app builds and installs. `minSdk` is 26, so the device must be Android 8.0 or newer (§11.2). | The device model and Android version. |
| A-2 | **Cold start to a focused name field on Add Idea** (NFR-2) | Two taps, and *under 1.5 s* on a mid-range phone. §11.13.1 names this as something only real hardware can settle. | The rough time. This is the one number that matters here. |
| A-3 | The system **Back** button on every screen (NAV-1) | Returns to the previous screen. On a dirty Add/Edit screen it asks `"Discard changes?"` first. | Any screen where Back exits the app instead. |
| A-4 | The on-screen keyboard on Add Idea (HOME-3) | It is raised on arrival, and `Enter` in the **name** field submits rather than inserting a newline (NAME-4). | Whether Enter inserted a newline. |
| A-5 | Tap a completion circle, and a subtask's (TODO-3, TODO-5) | Both are comfortable to hit with a thumb; the change persists immediately. | Any mis-taps. |
| A-6 | Two adjacent Ideas' `Make Task` buttons (ROW-5) | A mis-aimed tap cannot hit the neighbouring Item's button. | Whether it ever did. |
| A-7 | Rotate to landscape and back (NFR-7) | Nothing overflows or is lost. | A screenshot if it does. |
| A-8 | Leave the app backgrounded overnight, past 02:00, then reopen (EOD-3) | Completed Tasks have archived, under the previous day's date. | Whether the archive is right. |
| A-9 | Force-stop the app immediately after saving something (NFR-3) | The save survives. No acknowledged write may be lost. | Anything lost. |

## M6 — sync (both platforms)

§11.13.1 puts most of M6 in the headless column and it is covered there: the
codec, the orchestrator, the backup store and the file transport against
ordinary directories are 89 tests in `zen_sync`, and the convergence simulation
runs 60 seeds against two real databases through a real shared folder. **One
thing is not**: "The Android SAF folder path in M6 — scoped storage,
`ACTION_OPEN_DOCUMENT_TREE`, persisted grants, and grant revocation behave only
on a real device."

Everything below S-8 is therefore the part that cannot be established without
your hardware. S-1 to S-7 are Windows, where the code path is `dart:io` and
already exercised by tests, but where the *folder picker* and a real
Syncthing-style folder are not.

### M6 — before you build

M6 adds four native plugins — `file_selector` (both platforms), `saf_util` and
`saf_stream` (Android), and `file_selector_android` underneath the first — so
the first build after this commit is not an incremental one on either platform.

```bash
# All four packages: the dependency set changed.
for p in zen_domain zen_data zen_sync zen_app; do (cd "packages/$p" && flutter pub get); done
```

**Android builds clean and was checked on 2026-09-24:** `flutter build apk
--debug` succeeded in 138 s against `minSdk` 26. Nothing was needed beyond `pub
get` — no manifest change, and no new permission, because
`ACTION_OPEN_DOCUMENT_TREE` grants access by user choice rather than by
manifest. The `flutter_timezone` Kotlin-Gradle-Plugin deprecation warning is
**pre-existing and not fatal**; it predates M6 and is not a symptom of it.

**Windows must be built from an elevated terminal**, which is the standing
choice in place of Developer Mode (D-M4-16). Without one, `flutter build
windows` stops at "Building with plugins requires symlink support" before it
compiles anything — this is what happened when the agent tried, so **the Windows
build of M6 is unverified**. The plugin list changed, so CMake reconfigures on
the first run; if that misbehaves, `flutter clean` in `packages/zen_app` and
build again.

```bash
# From an elevated terminal, in packages/zen_app:
flutter build windows --release
flutter run -d windows            # or this, for the checks below
flutter run -d <your-device-id>   # Android
```

**Where the files are**, for S-22 to S-24 and for looking at backups by hand:

| | Database | Backups |
|---|---|---|
| Windows | `%APPDATA%\dev.zen\Zen\zen.sqlite` | `%APPDATA%\dev.zen\Zen\backups\` |
| Android | app-private; reach it with `adb shell run-as dev.zen.zen_app ls files` | the `backups/` directory beside it |

**S-15 needs a folder-sync client** — Syncthing, or a cloud drive folder — set up
independently on both devices and already replicating before Zen is pointed at
it. Everything else needs only the two builds.

### M6 — Windows

| # | Step | Expected | Report |
|---|---|---|---|
| S-1 | Settings ▸ Sync ▸ `Choose folder…`, pick an empty folder | The folder's path appears under the toggle and `Sync through a shared folder` switches on by itself. | Whether the native dialog opened and what path it returned. |
| S-2 | Tap `Sync now` | The status line reads `Last synced …` and something like `Nothing to sync.` A file named `zen-snapshot-<replicaId>.json` appears in the folder. | The exact status line and the filename. |
| S-3 | Open that file in a text editor | It is readable JSON holding your ideas and tasks — and **no settings**: no `endOfDay`, no `theme`, no `syncFolderLocation` (MERGE-3). | Anything settings-shaped in it. |
| S-4 | Tap `Sync now` again without changing anything | The file's **modified time does not change** (§11.6.5 step 7 skips an unchanged write). | The before and after timestamps. |
| S-5 | Add an idea, then `Sync now` | The file's modified time moves and the new idea is in it. | Whether it did. |
| S-6 | Point a second Windows install — or a copy of the app with a different database — at the same folder, and sync both | Each device ends up with both devices' ideas and tasks. Nothing is lost. | Anything missing on either side. |
| S-7 | Remove the folder from disk while sync is on, then `Sync now` | The status line reads `Sync folder not available`. **The app stays fully usable** and capture is never blocked (NFR-1, §11.6.3). | Any dialog, freeze, or blocked capture. |

### M6 — Android (SAF): the part only a device can establish

| # | Step | Expected | Report |
|---|---|---|---|
| S-8 | Settings ▸ Sync ▸ `Choose folder…` | The system folder picker opens (`ACTION_OPEN_DOCUMENT_TREE`, not a file picker). Choosing a folder stores a `content://…/tree/…` URI, which is what the subtitle shows. | The URI it stored. |
| S-9 | `Sync now`, then look in that folder with a file manager | `zen-snapshot-<replicaId>.json` is there, with the `.json` extension intact. | The **exact filename**. SAF derives an extension from the MIME type, and a name like `…json.txt` would mean no peer ever reads it. |
| S-10 | `Sync now` twice more | No file named `zen-tmp-…` is left behind, and no file named `zen-snapshot-… (1).json` appears. | Any file matching either. A `(1)` name means the delete-then-rename in §11.6.3 did not take, and sync is silently writing somewhere no one reads. |
| S-11 | **Force-close the app** and reopen it. `Sync now` | It still works without re-picking the folder — the grant was persisted (`takePersistableUriPermission`). | Whether it asked you to pick again. It must not. |
| S-12 | **Reboot the phone.** Reopen and `Sync now` | Same as S-11: the grant survives a reboot. | Whether it did. |
| S-13 | Android Settings ▸ Apps ▸ Zen ▸ clear the app's access to that folder (or delete the folder), then `Sync now` in Zen | The status line reads `Sync folder not available`. **Capture still works.** Nothing crashes and no dialog blocks you. | Exactly what the app did. §11.6.3: "A revoked or missing grant is a normal state … **Never block capture on it.**" |
| S-14 | `Choose folder…` again and re-pick | Sync resumes normally. | Whether it did. |
| S-15 | Put the *same* folder on both the phone and the PC — through Syncthing, or a cloud drive folder that syncs both ways — and use both devices for a day | Both devices converge. An idea captured on the phone appears on the PC and vice versa, within one sync interval of the folder replicating. | Anything that did not arrive, and anything that arrived **twice** or with the wrong name. |

### M6 — export, import and restore

| # | Step | Expected | Report |
|---|---|---|---|
| S-16 | Windows: Settings ▸ Sync ▸ `Export snapshot…` | A save dialog opens, suggesting `zen-snapshot-<replicaId>.json`. The saved file is readable JSON. | Whether the dialog opened. |
| S-17 | **Android:** `Export snapshot…` | A **folder** picker opens, not a save dialog — Android has no save dialog through this plugin (D-M6-11) — and the file lands in the folder you choose. | Where the file went and what it is called. |
| S-18 | Export from one device, then `Import snapshot…` on the other | The other device gains what the file held **and keeps everything it already had**. An import is a merge, never a replace (§11.8). | Anything that disappeared. This is the one to look at hardest. |
| S-19 | `Import snapshot…` and choose a file that is not a snapshot | A short message says it is not readable. Nothing changes and nothing crashes. | What the message said. |
| S-20 | After at least one real sync, Settings ▸ Sync ▸ `Restore from backup…` | A list of timestamps appears. Choosing one asks `Restore this backup?` and says it cannot be undone. | Whether the confirmation appeared **before** anything changed. |
| S-21 | Confirm the restore | Your ideas and tasks become exactly what that backup held. | Whether they did. |

### M6 — the sync triggers (§11.6.5), after the D-M6-20 fix

S-1 to S-21 passed on 2026-09-24, and the owner reported that sync ran "seems
like all the time" regardless of `syncIntervalMinutes`. Two defects, both fixed
and both now covered by regression tests (D-M6-20). These steps are what
confirms the fix on real hardware, since neither defect was visible to the suite
before it was pointed at them.

| # | Step | Expected | Report |
|---|---|---|---|
| S-25 | **Windows.** Settings ▸ Sync, interval `15 minutes`, `Sync when Zen opens` on. Note the "Last synced" time, then click away to another window and back, several times | "Last synced" **does not move**. A focus change is not a foreground. | Whether it moved at all. |
| S-26 | **Windows.** Minimise Zen, then restore it | "Last synced" **does** move: that is a real foreground. | Whether it did. |
| S-27 | **Windows.** Leave Zen open and untouched, and check "Last synced" after 15 and 30 minutes | It moves once per interval, not more. | The two times, so the spacing can be checked. |
| S-28 | **Windows.** Set the interval to `5 minutes` and wait | The next pass comes about 5 minutes later, not 15 — SET-2 applies at once. | Whether the change took effect without a restart. |
| S-29 | **Windows.** Set the interval to `Never`, then wait 20 minutes without touching the window | "Last synced" **never moves**. §11.8: "`0` disables." | Any movement at all. |
| S-30 | **Android.** Switch to another app and back | "Last synced" moves once per return, not more. | Whether one return produced exactly one sync. |
| S-31 | **Android.** With the interval at `Never` and `Sync when Zen opens` **off**, use the app for a while | Nothing syncs unless you press `Sync now`. | Any unrequested sync. |
| S-32 | **Windows.** Settings ▸ Sync, look at the `Sync now` button | There is a clear gap between it and the grey rule above; its filled surface does not touch the rule. | Whether it still touches. |

### M6 — the recovery screen (§11.5.5)

D-M4-9 left these buttons disabled; M6 wired them. Reaching this screen means
corrupting the database on purpose, so this is optional — but it is the only way
to know the recovery path works before you need it.

| # | Step | Expected | Report |
|---|---|---|---|
| S-22 | Close Zen. Open `zen.sqlite` in the app-support directory with a text editor and write a few junk characters into the middle of it. Reopen Zen | The recovery screen appears, names the problem, and says your data has not been deleted. `Restore from backup…` and `Import snapshot…` are **enabled**. | Whether they were enabled. |
| S-23 | Tap `Restore from backup…` and pick one | It reports how much it restored and tells you to close and reopen Zen. | The message. |
| S-24 | Close Zen and reopen it | The app starts normally with the restored data. The corrupted file is still on disk under its `…unreadable-<timestamp>` name. | Whether both are true. |

## Both — the time zone (EOD-5)

| # | Step | Expected | Report |
|---|---|---|---|
| Z-1 | Settings ▸ End of day, with the device in your real zone | Boundaries land at that **wall-clock** time, not at a UTC offset. | Your IANA zone, so the `flutter_timezone` lookup (D-M4-3) can be confirmed to resolve it. |
| Z-2 | If convenient, set the device's zone to something distant and reopen | The next boundary moves with the zone. | Whether it did. |

---

## Not in scope here

- **M7's LAN end-to-end** has its own §11.13.1 entry and is not built yet. The
  `"Sync over the local network"` toggle is deliberately present and disabled.
- **Goldens** run on Windows only (D-M4-8). On the Linux CI runner they are
  skipped, which is expected.
- **`ci.yaml` has still never run**, because the repository has no remote. That
  resolves on the first push.

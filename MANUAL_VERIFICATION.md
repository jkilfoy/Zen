# Manual verification

`ZEN_SPEC.md` §11.13.1 divides the work into what can be proved headlessly and
what needs real hardware, and instructs the implementer to **stop and hand the
owner a written checklist** for the second column rather than claim a milestone
done on code that has never run.

This is that checklist. Each step names what to do, what you should see, and
what to report back. Until every M4/M5 step below is confirmed, M4's definition
of done — *"The app runs on both platforms"* — is **not** met, whatever the test
count says.

---

## Why this file exists for M4 and M5

Everything else in these two milestones is in §11.13.1's left-hand column and is
proved: 349 tests in `zen_domain`, 182 in `zen_data`, 87 in `zen_app`, all
headless. What is not proved is the one thing widget tests cannot touch —
**launching the application**. §11.13.1 says so in as many words: *"M4's 'runs on
both platforms' is not established by widget tests, and this is the first
milestone where that applies."*

The machine this was built on cannot attempt either build:

| Platform | What is missing |
|---|---|
| Windows | Visual Studio **2019** Community is installed, without the "Desktop development with C++" workload. §11.2 requires Visual Studio **2022** with that workload. (§11.2 also notes VS **2026** is *not* supported for Flutter Windows desktop; do not install it as the toolchain.) Windows Developer Mode is also off, and building with plugins needs it for symlink support. |
| Android | The Android SDK is present (36.1.0) but `cmdline-tools` is missing and the licences are unaccepted, so no APK can be assembled. |

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

## Both — the time zone (EOD-5)

| # | Step | Expected | Report |
|---|---|---|---|
| Z-1 | Settings ▸ End of day, with the device in your real zone | Boundaries land at that **wall-clock** time, not at a UTC offset. | Your IANA zone, so the `flutter_timezone` lookup (D-M4-3) can be confirmed to resolve it. |
| Z-2 | If convenient, set the device's zone to something distant and reopen | The next boundary moves with the zone. | Whether it did. |

---

## Not in scope here

- **M6's Android SAF folder path** and **M7's LAN end-to-end** have their own
  §11.13.1 entries and are not built yet.
- The `"Sync"` section in Settings and the two buttons on the recovery screen
  are deliberately present and disabled (D-M4-9). They are not defects.
- **Goldens** run on Windows only (D-M4-8). On the Linux CI runner they are
  skipped, which is expected.
- **`ci.yaml` has still never run**, because the repository has no remote. That
  resolves on the first push.

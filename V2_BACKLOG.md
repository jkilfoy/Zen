# Zen — V2 backlog

Things deliberately not in V1. Each entry says where it came from, so a future
reader can tell what was decided against, what was deferred for time, and what
the build surfaced along the way.

**This file is also the pressure valve.** When something worth doing appears
mid-milestone and is not in scope, it goes here rather than into the work. An
entry costs a line; an unplanned feature costs a release.

Nothing here is committed to. Ordering within a section is rough priority.

---

## Deferred from V1

| # | Item | Origin |
|---|---|---|
| V2-1 | **CI release job** — a Windows runner building the Inno Setup installer, and a signed APK, on a tag. The local build path stays the way releases are cut in V1. | Owner, 2026-09-25. Originally M8 scope (`ci.yaml`, D-M0-8). |

## Declined for V1, worth revisiting

| # | Item | Origin |
|---|---|---|
| V2-2 | **Demotion: Task → Idea.** Conversion is one-way today, so the only way to walk back a commitment is Delete. ZTD's Simplify habit is largely about pruning commitments. Needs its own tombstone and merge story. | §12, Q31 |
| V2-3 | **Bulk actions on the Ideas list** — multi-select for delete or timeframe change, for periodically culling a long `Distant` group. | §12, Q32 |

## Stated future goals

| # | Item | Origin |
|---|---|---|
| V2-4 | **Home-screen capture widgets**, Android and a Windows tray equivalent. The intended design is already recorded: the widget writes to a small capture inbox rather than the database, and the app applies all validation when it drains it — so the widget needs no schema or invariant knowledge. | §1.3; architecture doc §2.4 |
| V2-5 | **Manual drag-reordering of the To Do list.** The schema was left room for a sort-key column. | §1.3, TODO-2 |
| V2-6 | **Decor packs beyond `Basic`** — Floral, Beach, Autumn, Christmas. The registry is data-driven precisely so this is additive. | §1.3, DECOR-3 |
| V2-7 | **Notifications, reminders, due dates.** | §1.3 |
| V2-8 | **A remote server, and with it multiple users.** The `SyncTransport` interface exists so this is an added implementation rather than a rewrite. | §1.3, §11.6.2 |

## Surfaced during the build

| # | Item | Origin |
|---|---|---|
| V2-9 | **A better merge strategy.** `Done`, `isDeleted` and `isArchived` are all sticky, so un-completing, restoring and un-archiving are each reverted by a replica that has not seen the change. The user's remedy is sync → undo → sync. This is the largest behavioural wart in the MVP merge, and `MergeStrategy` is an interface so it can be replaced wholesale. The per-replica event log is already retained partly to make a better strategy possible. | §9.4, §9.1, HIST-2 |
| V2-10 | **Generation-numbered snapshot files.** Android SAF has no atomic replace, so V1 does delete-then-rename and accepts a window in which a replica's snapshot is absent. Absent is not torn and costs one sync round, but the numbered scheme removes the window entirely. Changes the filename convention on **both** platforms, since they share one folder. | §11.6.3 |
| V2-11 | **Separate client and server keys for the LAN channel.** One HKDF-derived key serves both directions in V1, which is safe only because the nonces are random. Two keys would be stronger; it means revising the fixed `info` string. | §11.6.4 |
| V2-12 | **`qr_flutter` is stale** — last published 2023-05. It resolves and QR generation is a stable job, so it is not urgent, but it is unmaintained. | M7 package review |
| V2-13 | **Platform secure storage for the LAN pairing keys.** Declined for V1 with reasoning: anything that can read `zen.sqlite` can already read every idea and task, DPAPI unlocks for any process running as the same user, and the Android keystore mainly adds a way to lose the key. Worth revisiting only if the database itself is ever encrypted. | §11.8; M7 review, L13 |
| V2-14 | **Full Unicode case folding** in name normalization. V1 lowercases, so pairs that fold rather than lowercase — `ß` and `ss` — compare as different names. Changing this rewrites `name_normalized` for every row, and the migration can fail where two rows become equal and collide with the unique index. | §2, D-M1-1 |

# Zen — Application Specification

| Field | Value |
|---|---|
| Document version | 1.8 |
| Changes in 1.8 | §11.13.1's table listed M4–M5's widget and golden tests as headless-verifiable but never named *launching the app*, so a literal reader could take all of M4–M5 to be container-verifiable. Added to the hardware column. |
| Changes in 1.7 | §11.13: **M4 and M5 now run as one session with a commit at each.** The old boundary cut through shared files rather than between them — §5.3 and §5.4 make Add and Edit the same screens in different modes, and three of M4's own affordances (ROW-3, TODO-6, REVIEW-1) point at M5's screens. The work is now sequenced by shared component rather than by user journey. |
| Changes in 1.6 | §11.5.1's table list still named the `tags` / `item_tags` pair that v1.5 replaced three lines below it (D-M3-16). Corrected to `idea_tags` and `task_tags`. |
| Changes in 1.5 | Eleven findings from the M3 agent's pre-implementation review, all accepted. **§3: millisecond precision is exact, not a floor** — Drift's default stores whole seconds, which would have manufactured `updatedAt` ties and reverted renames through §9.3 step 4, and mixed-width ISO text sorts non-chronologically. **§3.7 gains INV-8** (the `sourceIdea` pair) **and INV-9** (timestamp precision). **§11.5.1 replaces the shared `tags` / polymorphic `item_tags` pair with per-kind `idea_tags` and `task_tags`**, which can express TAG-4 and can carry a real cascading foreign key. **§11.5.2** adds `CHECK`s for INV-5, INV-8 and INV-9, gives INV-2 and INV-7 triggers instead of a repository-only check, pins ISO-8601 text storage, and specifies attempt-and-translate over pre-checking. **EOD-2A**: archiving no longer moves `updatedAt`. **§11.5.4**: the sweep takes its time inputs explicitly. **§11.4.6**: `EventLog` gains `prune`. **§11.6.5**: a merge is applied by wholesale replacement, never row by row. |
| Changes in 1.4 | Ten findings from the M2 agent's pre-implementation review of §9.3, all accepted. **§9.1 gains MERGE-3A**, distinguishing the set-valued collections (`ideas`, `tasks`, `tombstones`, emitted sorted by `id`) from the genuinely ordered ones (`subtasks`, `tags`). **§9.3 is rewritten**: record order is defined instead of the unusable "sorted by `id`"; tombstones are deduplicated per Idea; **subtask matching is by `id` first and by name-position only as a fall-back**, which fixes a silent data-loss bug where a renamed subtask collapsed two distinct subtasks into one; `archivedAt` and `deletedAt` are conditional on their flags (INV-4); the `sourceIdea` fields resolve as a pair; subtask `completedAt` and list order are specified; and step 6's termination argument is corrected. §9.4 now records that `Done`, `isDeleted` and `isArchived` are all sticky, not just `Done`. |
| Changes in 1.3 | Pre-M2 review of §9.3, which was ambiguous in two places that decide real behaviour. **Step 4 now defines the primary record**: a component normally holds several records sharing the chosen `id`, and the choice between them decides whether a rename survives a merge or is silently reverted. **Step 5(d)** applies the same rule to subtasks. **Step 6** now groups all colliding Items by name and resolves each group in one pass, because the pairwise wording was order-dependent once three Items collide, breaking MERGE-2. |
| Changes in 1.2 | Post-M1 review. **§9.1: `ReplicaSnapshot` and `MergeResult` are `zen_domain` types** — §11.3 previously placed the snapshot in `zen_sync`, which would have inverted the dependency direction and blocked M2. **§2: name normalization now includes a Unicode NFC pass**, and §11.5.2 notes why the rule must be settled before the schema exists. §11.2 gained the `unorm_dart`, `characters` and `timezone` rows, the last with the constraint that it belongs to `zen_data` only. §11.5.2 notes that `assert` is stripped in release builds, so the database constraints are the only enforcement that ships. |
| Changes in 1.1 | Milestone definitions of done now cite the correct acceptance scenarios (M2 previously cited conversion scenarios as merge ones). Added §11.13.1 on which milestones can be verified without real hardware, §11.5.5 on database failure handling, and an event-log cap in §11.5.1. |
| Changes from 0.4 | §11 written in full: Flutter + Drift + Riverpod, four-package layout, schema and constraints, snapshot format, both sync transports, pre-merge backup, packaging, CI, testing requirements and the agent's implementation order. §3.6, §5.11 and §9.2 point at it. §12 became the declined-additions record; §13 gained the architecture decisions. |
| Status | **COMPLETE — ready to hand to an implementing agent.** Every question raised in drafting is resolved (§13). §12 records additions that were considered and deliberately left out. |
| Product name | Zen (working title) |
| Target platforms | Windows (desktop), Android (mobile) |
| Audience | An AI coding agent that will implement the application end to end, and the human owner who reviews it. |

---

## 0. How to read this document

0.1. This document is the **single source of truth** for the application. If something is not specified here, the implementer MUST NOT invent product behaviour. It MUST instead choose the simplest behaviour consistent with this document and record the choice in `DECISIONS.md` at the repository root.

0.2. The key words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT** and **MAY** are used as defined in RFC 2119.

0.3. Every requirement has a stable ID (e.g. `IDEA-3`, `TODO-7`). Code comments and tests SHOULD reference these IDs where they implement or verify a requirement.

0.4. Every question raised during drafting has been resolved by the owner; §13 records the resolutions and §12 lists the three optional additions that were deliberately declined. Nothing in §1–§11 is provisional.

0.5. UI text shown in `"double quotes"` is exact user-facing copy and MUST be reproduced verbatim.

---

## 1. Purpose and scope

### 1.1 Purpose
Zen is a personal companion application for the **Zen To Done (ZTD)** productivity system by Leo Babauta. It helps one user capture, process, organise and complete two kinds of items:

- **Ideas**: things the user *might* choose to do, but might never do.
- **Tasks**: things the user *intends* to complete.

Zen supports these ZTD habits:

| ZTD habit | How Zen supports it |
|---|---|
| 1. Collect | Very fast capture of Ideas and Tasks from the Home screen. |
| 2. Process | Reviewing lists; converting Ideas into Tasks; deleting; editing. |
| 3. Plan | Idea timeframes (Now / Soon / Later / Distant) only. |
| 4. Do | To Do list with completion toggling and subtasks. |
| 6. Organize | Tags, timeframes, context/descriptions, archive. |
| 7. Review | Ideas list and To Do list review; archived-task history. |

### 1.2 Design principles
1. **Capture speed first.** Opening the app MUST land on a screen from which adding an item takes the fewest possible interactions.
2. **Simplicity over features.** ZTD warns against fiddling with tools. The UI MUST stay minimal.
3. **The app holds items, not judgements.** Zen deliberately does **not** implement MITs, Big Rocks, Single Goals, weekly-review checklists or any other planning or reflection workflow. The owner performs those outside the app, on purpose: encoding them in software would make the practice less adaptive. Ideas and Tasks are the whole product. Do not add such features.
4. **Nothing is silently lost.** Tasks are never hard-deleted. The history of each item is retained.
5. **No silent state changes.** The app never changes a Task's status on the user's behalf. Where an action would break an invariant, the app blocks the action and explains what the user must do instead.
6. **Offline-first.** Every feature MUST work with no network connection.
7. **Swappable internals.** Storage and sync-merge logic MUST sit behind abstract interfaces so later versions can replace them (§8, §9).

### 1.3 MVP scope
In scope: everything in §3–§10.

Out of scope for the MVP. The architecture SHOULD NOT preclude these:
- Multiple users, accounts, authentication.
- Remote/cloud server storage.
- Home-screen widgets (desktop or mobile).
- Notifications and reminders.
- Due dates and scheduling.
- Manual drag-reordering of the To Do list (§5.7, TODO-2).
- Decor packs beyond `Basic` (§3.6.1).
- Attachments and images.

Permanently out of scope, per principle 1.2.3: MITs, Big Rocks, Single Goal tracking, weekly/monthly review workflows, goal hierarchies, analytics and productivity statistics.

---

## 2. Glossary

| Term | Definition |
|---|---|
| **Item** | Either an Idea or a Task. |
| **Idea** | An entity representing something the user might do (§3.2). |
| **Task** | An entity representing something the user intends to complete (§3.3). |
| **Subtask** | A checklist entry belonging to exactly one Task (§3.4). |
| **Tag** | A short categorising label attached to an Item (§3.5). Displayed with a leading `@`. |
| **Timeframe** | An Idea's urgency class: `Now`, `Soon`, `Later`, `Distant`. |
| **Status** | A Task's or Subtask's state: `Todo`, `Blocked`, `Done`. |
| **Completion circle** | The circular toggle control shown left of each Task and Subtask in the To Do list. |
| **End of Day (EoD)** | A user-configurable local clock time (default 02:00) that separates one *logical day* from the next (§4.5). |
| **Archive / Archived** | A Done Task hidden from the To Do list after EoD passes, but kept and viewable (§4.5). |
| **Soft delete** | Setting a Task's `isDeleted` flag. The Task is hidden but retained. |
| **Hard delete** | Removing an Idea from the user-visible dataset, leaving only a tombstone (§4.6). |
| **Tombstone** | A small record `{id, deletedAt, reason}` proving an Idea once existed and was removed, used to stop merges from resurrecting it (§9.3). |
| **Active Item** | An Idea that exists and is not tombstoned (all live Ideas are active), or a Task with `isDeleted == false` **and** `isArchived == false`. Name uniqueness (§3.1) and name-based merge matching (§9.2) apply only to active Items. |
| **Source / Replica** | One installation of the app with its own local database (e.g. the Windows install, the Android install). |
| **Merge** | Combining the datasets of two or more replicas into one (§9). |
| **Normalized name** | An Item name after (1) **Unicode NFC normalization**, (2) trimming, (3) collapsing internal whitespace runs to a single space, and (4) case folding, in that order. Used for all equality comparisons between names (§3.1), for the `name_normalized` column and its uniqueness indexes (§11.5.2), and for name matching during a merge (§9.2). One function is the sole definition of this, so the three cannot drift apart. **NFC matters because the two devices have different input stacks:** without it, a composed `é` and a decomposed `é` are different names, so the same idea typed on Windows and on Android would fail to match during a merge and appear twice after syncing. Case folding is approximated by lowercasing, which is a documented and accepted limitation (`ß` and `ss` remain distinct). |

---

## 3. Data model

All timestamps are **UTC instants** (ISO-8601 with `Z`), displayed in the device's local time zone.

**Millisecond precision is exact, not a floor.** Every instant MUST be truncated to whole milliseconds, and the truncation happens where instants enter the system — in `Clock`, so nothing downstream has to remember, and again at the storage and snapshot-parsing boundaries, so an instant arriving from a peer or an older database cannot smuggle in finer precision. Every stored timestamp is therefore exactly `YYYY-MM-DDTHH:MM:SS.mmmZ`, 24 characters.

Two reasons this is a rule rather than a detail:

1. **Ordering.** Timestamps are stored as text, and text compares lexicographically. That is chronological *only* at uniform width: `"…00.100Z"` sorts **after** `"…00.100500Z"`, because `Z` (0x5A) outranks any digit — so the earlier instant would compare as the later one. Mixed precision silently corrupts every `ORDER BY`, every range predicate, and the `INV-5` check.
2. **The merge.** §9.3 step 4 picks the primary record by latest `updatedAt` and falls back to *content-based* tie-breaks. Coarser storage manufactures ties between edits that were genuinely ordered, and a tie can revert a rename — the precise failure that step 4's "Why this matters" paragraph exists to prevent.

All IDs are **UUIDv7** strings, assigned by the system at creation and never changed by the user. UUIDv7 is time-ordered and collision-safe across replicas without coordination. IDs are visible only in the Advanced details panel (§5.3, §5.4).

### 3.1 Names: validation and uniqueness

- **NAME-1.** A name MUST be trimmed of leading and trailing whitespace before validation and storage.
- **NAME-2.** A name MUST contain at least **3 characters** after trimming. "Characters" means user-perceived characters (Unicode extended grapheme clusters).
- **NAME-3.** A name MUST contain at most **1000 characters**. Typical names are ≤ 50 characters. Input beyond the cap is rejected with `"Name must be 1000 characters or fewer."`
- **NAME-4.** A name MUST NOT contain line breaks. On the Add/Edit screens, pressing Enter in the name field submits the form instead of inserting a newline.
- **NAME-5.** Two names are *equal* if and only if their normalized names are equal (§2).
- **NAME-6 (uniqueness).** Among **active Items of the same kind** (§2), names MUST be unique.
  - Two active Ideas MUST NOT share a name.
  - Two active Tasks MUST NOT share a name.
  - An Idea and a Task MAY share a name. The two kinds are independent namespaces.
- **NAME-7 (scope of uniqueness).** Archived Tasks, soft-deleted Tasks and tombstoned Ideas do **not** reserve their names. A name becomes free for reuse as soon as its Item leaves the active set. This is what makes recurring work possible: "Water the plants" can be created again the day after the previous one archived.
- **NAME-8 (enforcement on save).** Saving an Item whose name collides with an active Item of the same kind MUST be blocked. The save button is disabled and an inline message is shown: `"An idea with this name already exists."` / `"A task with this name already exists."` The message SHOULD offer a `"Open it"` link that navigates to the colliding Item's Edit screen. Renaming an Item to its own current name is not a collision.
- **NAME-9 (enforcement on reactivation).** Restoring a deleted Task or unarchiving an archived Task is **prohibited** when an active Task already holds that name. The action is blocked with:

  `"There is already an active task with this name in your To Do list. Complete and archive the active task in order to restore this one to your To Do list."`

  The user is not offered a rename as a way around this. They must deal with the active Task first.
- **NAME-10.** Uniqueness is also enforced at the persistence layer, and re-established after every merge (§9.3).
- **NAME-11.** Subtask names are **not** subject to uniqueness. A Task may contain two subtasks with the same name.

### 3.2 Idea

| Field | Type | Required | Default | Constraints / notes |
|---|---|---|---|---|
| `id` | UUIDv7 | yes | generated | Immutable. |
| `name` | string | yes | — | §3.1. |
| `tags` | ordered list of Tag | no | `[]` | §3.5. Unique within the Idea (case-insensitive). Preserves insertion order. |
| `context` | string | no | `""` | Free text, multi-line, plain text. Max 10,000 characters. |
| `timeframe` | enum `Now`\|`Soon`\|`Later`\|`Distant` | yes | `settings.defaultIdeaTimeframe` (factory default `Now`) | Urgency order: `Now` > `Soon` > `Later` > `Distant`. |
| `createdAt` | timestamp | yes | now | Immutable. |
| `updatedAt` | timestamp | yes | now | Updated on every user edit. |

### 3.3 Task

| Field | Type | Required | Default | Constraints / notes |
|---|---|---|---|---|
| `id` | UUIDv7 | yes | generated | Immutable. |
| `name` | string | yes | — | §3.1. |
| `tags` | ordered list of Tag | no | `[]` | §3.5. |
| `description` | string | no | `""` | Free text, multi-line, plain text. Max 10,000 characters. |
| `status` | enum `Todo`\|`Blocked`\|`Done` | yes | `Todo` | §4.2. |
| `subtasks` | ordered list of Subtask | no | `[]` | §3.4. Order is user-visible and user-controlled. |
| `createdAt` | timestamp | yes | now | Immutable. For a Task converted from an Idea, this is the conversion time. |
| `updatedAt` | timestamp | yes | now | Updated on every user edit, including subtask changes. |
| `completedAt` | timestamp \| null | — | null | Set when status becomes `Done`. Cleared when status leaves `Done`. |
| `isArchived` | bool | yes | false | §4.5. |
| `archivedAt` | timestamp \| null | — | null | Set iff `isArchived`. |
| `isDeleted` | bool | yes | false | §4.6. |
| `deletedAt` | timestamp \| null | — | null | Set iff `isDeleted`. |
| `sourceIdeaId` | UUIDv7 \| null | — | null | ID of the Idea this Task was converted from. |
| `sourceIdeaCreatedAt` | timestamp \| null | — | null | `createdAt` of that Idea. Preserves how long the item has existed. |

### 3.4 Subtask

A Subtask has no tags, context, timeframe, archive flag or delete flag. Subtasks exist only inside their parent Task and are created, renamed, deleted and reordered **only** on the Create/Edit Task screen (§5.4). There is no separate subtask screen, and no way to add a subtask from the To Do list.

| Field | Type | Required | Default | Constraints / notes |
|---|---|---|---|---|
| `id` | UUIDv7 | yes | generated | Immutable. |
| `name` | string | yes | — | Trimmed. 1–1000 characters. No line breaks. Need not be unique within the parent (NAME-11). |
| `status` | enum `Todo`\|`Blocked`\|`Done` | yes | `Todo` | |
| `createdAt` | timestamp | yes | now | |
| `updatedAt` | timestamp | yes | now | |
| `completedAt` | timestamp \| null | — | null | Same rule as Task. |

### 3.5 Tag

- **TAG-1.** A tag is stored **without** a leading `@`. If the user types a leading `@`, it is stripped.
- **TAG-2.** A tag is trimmed and MUST NOT contain any whitespace. Any other character is allowed.
- **TAG-3.** A tag's length is 1–32 characters. 20 or fewer is typical.
- **TAG-4.** Tags keep the case the user typed, but compare case-insensitively. Adding a tag that equals an existing tag on the same Item is a no-op.
- **TAG-5.** Tags are displayed as `@tag`.
- **TAG-6.** Tag input SHOULD offer autocomplete from all tags that exist on any active Item.

### 3.6 Settings

Settings are stored **per replica** and are never merged (§9). §11.8 adds the sync settings to this table.

| Key | Type | Factory default | Meaning |
|---|---|---|---|
| `defaultIdeaTimeframe` | Timeframe | `Now` | Timeframe preselected on the Add Idea screen. |
| `expandedIdeaGroups` | set of Timeframe | `{Now, Soon, Later}` | Which timeframe groups are expanded when the Ideas tab opens (§5.8). This is the same setting as "which groups are shown by default". |
| `strikethroughDone` | bool | `true` | Whether Done Tasks/Subtasks show their name struck through. |
| `endOfDay` | local time `HH:MM` | `02:00` | Logical day boundary (§4.5). |
| `theme` | `System`\|`Light`\|`Dark` | `System` | Light/dark axis. |
| `decor` | Decor pack id | `Basic` | Visual skin axis (§3.6.1). |
| `confirmDestructive` | bool | `true` | Whether deleting asks for confirmation. |

#### 3.6.1 Decor (theming architecture)
- **DECOR-1.** `theme` and `decor` are **independent axes**. Choosing a decor MUST NOT override the user's light/dark choice.
- **DECOR-2.** A **decor pack** is a named, data-driven bundle supplying colour accents, and optionally background imagery, icon variants and header ornaments. Every pack MUST define a complete **light variant and dark variant**, so that any decor works under any theme.
- **DECOR-3.** The MVP ships exactly one pack, with id `Basic` and display name `"Basic"`: the plain default. The implementation MUST structure packs as declarative data (not hard-coded widgets) so packs such as Floral, Beach, Autumn or Christmas can be added later by adding data, without touching screen code.
- **DECOR-4.** The Settings screen shows the decor picker even with one option.

### 3.7 Invariants
The persistence layer MUST enforce these, and tests MUST cover them.

- **INV-1.** `task.completedAt != null` ⇔ `task.status == Done`. The same holds for subtasks.
- **INV-2.** `task.status == Done` ⇒ every subtask has `status == Done`.
- **INV-3.** `task.isArchived` ⇒ `task.status == Done`.
- **INV-4.** `archivedAt != null` ⇔ `isArchived`. `deletedAt != null` ⇔ `isDeleted`.
- **INV-5.** `createdAt ≤ updatedAt`.
- **INV-6.** Names satisfy §3.1 including uniqueness (NAME-6). Tags satisfy §3.5.
- **INV-7.** Every tombstoned Idea id is absent from the Ideas table.
- **INV-8.** `sourceIdeaId` and `sourceIdeaCreatedAt` are either both null or both non-null. They are one fact about one Idea (§3.3), and §9.3 step 4 resolves them as a pair; this makes that a property of the data rather than of one merge step.
- **INV-9.** Every timestamp has exactly millisecond precision (§3).

---

## 4. Business rules

### 4.1 Creating items
- **CREATE-1.** An Idea is created from a valid `name` alone. `tags`, `context` and `timeframe` are optional and take the defaults in §3.2.
- **CREATE-2.** A Task is created from a valid `name` alone. `tags`, `description` and `subtasks` are optional. `status` defaults to `Todo`.
- **CREATE-3.** Creation is blocked if the name collides with an active Item of the same kind (NAME-8).
- **CREATE-4.** Items MUST be durably persisted before the UI reports success.

### 4.2 Task status transitions

| Trigger | From | To | Guard | Effect |
|---|---|---|---|---|
| Tap completion circle (To Do list) | `Todo` | `Done` | All subtasks `Done` (or no subtasks) | Set `completedAt = now`. |
| Tap completion circle (To Do list) | `Todo` | — | Some subtask not `Done` | No change. Show popup `"This task has incomplete subtasks. Complete the subtasks before finishing this task."` |
| Tap completion circle (To Do list) | `Done` | `Todo` | none | Clear `completedAt`. Unlocks subtask statuses (§4.3). |
| Tap completion circle (To Do list) | `Blocked` | — | — | No change. MAY play a subtle "nudge" animation (not required for MVP). |
| Status control (Edit Task screen) | any | any | Target `Done` requires all subtasks `Done`. If not, show the same popup and leave the status unchanged. | Maintain INV-1. |

- **STATUS-1.** The completion circle toggles only between `Todo` and `Done`. `Blocked` MUST NOT be reachable from the completion circle. In the MVP the Edit Task screen is the only place that sets or clears `Blocked`, but that is an artefact of the current UI, not a design constraint: a future version MAY add other affordances (a long-press, a context menu, a swipe) as long as the completion circle itself never produces `Blocked`.
- **STATUS-2.** Completing the last open subtask does **not** auto-complete the parent Task. The user completes the parent explicitly.
- **STATUS-3.** A Task's status never changes as a side effect of another action (principle 1.2.5). The only exception is the merge repair in §9.3 step 6, which is recorded in the merge report.
- **STATUS-4.** An archived Task cannot change status. To reopen it, the user first un-archives it (§5.9).

### 4.3 Subtask rules

- **SUB-1 (status lock).** While a Task's status is `Done`, its subtasks' **statuses** are locked: they cannot be changed, anywhere. Other subtask edits — add, rename, delete, reorder, all of which happen on the Edit Task screen — remain available. *Rationale: an accidental tap must not silently reopen a completed task.*
- **SUB-2.** Tapping a locked subtask's completion circle does nothing. Neither the subtask nor the Task changes. The app MAY play the same subtle nudge as a Blocked task, and SHOULD show a one-line hint: `"Set the task back to Todo to change its subtasks' status."`
- **SUB-3.** When the Task leaves `Done`, its subtask statuses unlock immediately, keeping the values they had. On the Edit Task screen this happens as soon as the status control changes, before saving.
- **SUB-4.** When a Task is **not** `Done`, tapping a subtask's completion circle in the To Do list toggles `Todo` ⇄ `Done`. A `Blocked` subtask does not toggle.
- **SUB-5.** On the Edit Task screen, an unlocked subtask's status can be set to any of the three values.
- **SUB-6.** Subtasks of a `Blocked` Task can be toggled. Only `Done` locks statuses.
- **SUB-7.** Deleting a subtask is a hard delete; subtasks have no soft-delete flag and are not recoverable.
- **SUB-8 (adding to a Done Task).** Adding a subtask to a `Done` Task is **forbidden**. The `"Add subtask"` affordance is available only when the Task's status is `Todo` or `Blocked`. On the Edit Task screen it is hidden while the status control reads `Done`, and it reappears as soon as the user changes that control to `Todo` or `Blocked`, before saving. Renaming, deleting and reordering existing subtasks stay available in all states.
- **SUB-9.** Subtasks are created, renamed, deleted and reordered only on the Create/Edit Task screen (§5.4). The To Do list has **no** add-subtask affordance.

SUB-1 and SUB-8 together mean INV-2 can never be broken by a subtask edit: statuses cannot change while the parent is `Done`, and no new subtask can appear. The only way to make a `Done` Task incomplete is to change the Task's own status first.

### 4.4 Converting an Idea to a Task
- **CONVERT-0 (entry points).** Conversion starts either from the `"Make Task"` button on an Idea's row in the Ideas list (IDEAS-6), or from the `"Create Task"` action on the Edit Idea screen (IDEAFORM-5). Both lead to the same screen and the same behaviour.
- **CONVERT-1.** Conversion opens the **Create Task** screen, pre-filled as follows:

  | Task field | Value |
  |---|---|
  | `name` | Idea `name` |
  | `tags` | Idea `tags` |
  | `description` | Idea `context` |
  | `subtasks` | `[]` |
  | `status` | `Todo` |
  | `sourceIdeaId`, `sourceIdeaCreatedAt` | Idea `id`, `createdAt` |

  The Idea's `timeframe` is discarded.
- **CONVERT-2.** The user MAY edit every pre-filled field before confirming.
- **CONVERT-3.** If the name collides with an active Task (NAME-8), confirmation is blocked until the user edits the name. The Idea is not touched.
- **CONVERT-4.** On confirm ("Create Task"), in **one atomic transaction** the app creates the Task, removes the source Idea and writes a tombstone for it with `reason = converted`. Nothing is written before that press. Then it shows the To Do list.
- **CONVERT-5.** On cancel, or on Back, nothing changes: the Idea remains untouched with its timeframe, and no Task is created. The app returns to the **Ideas tab**, from either entry point. Any edits the user made on the Create Task screen are discarded, subject to the usual `"Discard changes?"` prompt (NAV-1).

### 4.5 End of Day and archiving
- **EOD-1.** `settings.endOfDay` (local time, default 02:00) defines the boundary between logical days.
- **EOD-2.** A Task with `status == Done` and `isArchived == false` becomes archived when the current time is at or after the **first EoD boundary strictly after its `completedAt`**. Archiving sets `isArchived = true` and `archivedAt = <that boundary instant>`.
  - *Example:* EoD = 02:00. A task completed Tue 23:10 archives at Wed 02:00. A task completed Wed 01:30 also archives at Wed 02:00. A task completed Wed 02:30 archives at Thu 02:00.
- **EOD-2A.** Archiving is a **system action, not a user edit**, so it MUST NOT move the Task's `updatedAt` (§3.3, which scopes `updatedAt` to user edits). `archivedAt` is the audit trail. Moving it would let a sweep firing after a late edit push `updatedAt` *backwards* to the boundary instant, and §9.3 step 4 resolves by latest `updatedAt` — so a peer holding pre-edit content could then win and the edit would be lost. Un-archiving (ARCH-3) *is* a user action and does move it.
- **EOD-3.** The archive sweep MUST run at app start, when the app returns to the foreground, and at each EoD boundary while the app is running. A replica that was closed across one or more boundaries MUST archive correctly on its next start.
- **EOD-4.** Changing `endOfDay` applies to future sweeps only. Already-archived tasks are not un-archived.
- **EOD-5.** Boundaries are computed in the device's current local time zone. Across a DST change, use the wall-clock time `endOfDay` on each date. If that time does not exist on a date, use the first valid instant after it.
- **EOD-6.** Archiving frees the Task's name for reuse (NAME-7).

### 4.6 Deleting
- **DEL-1 (Tasks).** Deleting a Task is a **soft delete**. It sets `isDeleted = true` and `deletedAt = now`. Deleted Tasks do not appear in the To Do list or the Archived Tasks view. They appear only through Search with the "Deleted" filter (§5.10).
- **DEL-2 (Tasks).** A deleted Task can be restored from Search. Restoring clears `isDeleted` and `deletedAt` and leaves the status as it was. If the status was `Done`, the next archive sweep will archive it. If an active Task already holds the name, restoring is prohibited per NAME-9.
- **DEL-3 (Ideas).** Deleting an Idea removes it from the user-visible dataset permanently. It cannot be restored in the UI. The replica writes a **tombstone** `{id, deletedAt, reason: deleted|converted}`. Tombstones store **no name**: matching during merge is by `id` only (§9.3), so a name that was deleted may be created again as a new Idea with a new id, and the tombstone will not affect it.
- **DEL-4.** If `settings.confirmDestructive` is true, both kinds of delete ask for confirmation first. The dialog shows `"Delete this idea? This cannot be undone."` or `"Delete this task?"`

---

## 5. Screens and navigation

### 5.1 Navigation map

```
Home ──(Add ▸ Idea)──▶ Add Idea ──(save)──▶ Review [Ideas tab]
  │   └(Add ▸ Task)──▶ Add Task ──(save)──▶ Review [To Do tab]
  ├──(Review)────────────────────────────▶ Review [To Do tab]
  └──(⚙)─────────────────────────────────▶ Settings

Review [To Do tab]  ── tap task text ──▶ Edit Task
                    ── "Archived" link ─▶ Archived Tasks ── tap ──▶ Edit Task (read-only, §5.9)
Review [Ideas tab]  ── tap idea text ──▶ Edit Idea ──("Create Task")──▶ Create Task (from Idea)
                    ── "Make Task" ─────────────────────────────────▶ Create Task (from Idea)
                       (Create Task: confirm ▸ To Do tab; cancel ▸ Ideas tab)
Review (either tab) ── search icon ────▶ Search
Review / Settings / Add / Edit ── Back ─▶ previous screen
```

- **NAV-1.** Android's system Back and an on-screen back arrow (both platforms) return to the previous screen. Leaving an Add or Edit screen with unsaved changes asks `"Discard changes?"`
- **NAV-2.** The settings gear icon appears in the top bar of the Home and Review screens.
- **NAV-3.** Cold start MUST open the Home screen directly, with no splash or loading screen beyond platform minimums.

### 5.2 Home screen (`SCR-HOME`)
- **HOME-1.** The screen has two large regions that together fill the screen: the top half labelled `"Add"` and the bottom half labelled `"Review"`. A gear icon sits in the top-right corner.
- **HOME-2.** Tapping `"Add"` replaces the Add region, in place and without navigating, with two equal buttons: `"Idea"` and `"Task"`. Tapping outside them or pressing Back restores the `"Add"` label.
- **HOME-3.** `"Idea"` opens Add Idea (§5.3). `"Task"` opens Add Task (§5.4). On both, the name field is focused and the on-screen keyboard is raised.
- **HOME-4.** Tapping `"Review"` opens the Review screen on the To Do tab.
- **HOME-5 (desktop).** Keyboard shortcuts MUST exist: `Ctrl+I` opens Add Idea, `Ctrl+T` opens Add Task, `Ctrl+R` opens Review, `Ctrl+F` opens Search, `Esc` goes back.

### 5.3 Add Idea / Edit Idea (`SCR-IDEA-FORM`)
The screen has two modes, Add and Edit, with the same layout.

- **IDEAFORM-1.** Fields, top to bottom: Name (single line, wraps visually), Timeframe (segmented control: Now / Soon / Later / Distant), Tags (chip input, §3.5), Context (multi-line text area).
- **IDEAFORM-2.** The primary button is `"Add Idea"` (Add mode) or `"Save"` (Edit mode). It is disabled while the name is invalid. Validation messages: `"Name must be at least 3 characters."`, `"Name must be 1000 characters or fewer."`, `"An idea with this name already exists."` (NAME-8). Messages appear once the user has typed and then paused or blurred the field.
- **IDEAFORM-3.** Saving is explicit. Edits are not auto-saved.
- **IDEAFORM-4.** After adding, the app navigates to Review on the Ideas tab, with the group containing the new Idea expanded and the new Idea scrolled into view. It SHOULD be briefly highlighted.
- **IDEAFORM-5 (Edit mode only).** Two extra actions: `"Create Task"` (starts conversion, §4.4) and `"Delete"` (§4.6). After Save or Delete, return to the Ideas tab.
- **IDEAFORM-6 (Advanced details).** A collapsible section labelled `"Advanced details"`, collapsed by default, shown in Edit mode only. It is **read-only** and displays: `id`, `createdAt`, `updatedAt`. Timestamps are shown in local time with the time zone abbreviation. The id row offers a copy action.

### 5.4 Add Task / Edit Task / Create Task from Idea (`SCR-TASK-FORM`)
The screen has three modes with the same layout: Add, Edit, and Convert (pre-filled per §4.4). It is the **only** place subtasks are created or edited.

- **TASKFORM-1.** Fields, top to bottom: Name, Status (Edit mode only: segmented control Todo / Blocked / Done), Tags, Description, Subtasks.
- **TASKFORM-2 (Subtasks editor).** A section headed `"Subtasks"` containing the ordered subtask list, with an `"Add subtask"` row at the **end** of the list. Pressing it appends a new subtask row and focuses its name field. Each row has: a status control (Edit mode: Todo / Blocked / Done; Add and Convert modes: new subtasks are always `Todo` and the control is hidden), an editable name field, a delete button, and a drag handle for reordering. Pressing Enter in a subtask name commits it and appends another new row. In Add and Convert modes the Task is always `Todo`, so the `"Add subtask"` row is always present.
- **TASKFORM-3.** The primary button is `"Add Task"` (Add), `"Save"` (Edit) or `"Create Task"` (Convert). It is disabled while the name is invalid, including on a uniqueness collision (NAME-8, CONVERT-3).
- **TASKFORM-4.** Setting Status to Done while any subtask is not Done shows the incomplete-subtasks popup (§4.2) and leaves the status unchanged.
- **TASKFORM-5 (Done Task: what is locked).** When the status control reads `Done`:
  - every subtask's status control is disabled (SUB-1), with the hint `"Set the task back to Todo to change its subtasks' status."`;
  - the `"Add subtask"` row is hidden (SUB-8);
  - subtask name fields, delete buttons and drag handles stay enabled.

  Changing the status control to `Todo` or `Blocked` unlocks the status controls and restores the `"Add subtask"` row immediately, before saving. Changing it back to `Done` re-applies the lock; if the user added a subtask in between and it is not `Done`, TASKFORM-4 blocks that status change.
- **TASKFORM-6 (save validation).** As a defensive check, Save is blocked with the incomplete-subtasks popup whenever the form's status is `Done` and any subtask's status is not `Done`. Under TASKFORM-4 and TASKFORM-5 this state should be unreachable through the UI; the check exists so that no path can persist a violation of INV-2.
- **TASKFORM-7 (Edit mode only).** A `"Delete"` action (§4.6).
- **TASKFORM-8.** After Add, Save, Convert or Delete, navigate to Review on the To Do tab. After Add or Convert, scroll the new Task into view.
- **TASKFORM-9 (Advanced details).** As IDEAFORM-6, in Edit mode only, read-only, collapsed by default. Displays: `id`, `createdAt`, `updatedAt`, `completedAt`, `archivedAt`, `deletedAt`, and — when `sourceIdeaId` is set — a row `"Converted from idea"` showing `sourceIdeaId` and `sourceIdeaCreatedAt`. Null fields are shown as `"—"`.

### 5.5 Review screen (`SCR-REVIEW`)
- **REVIEW-1.** The top bar has a back arrow, two tabs `"To Do"` and `"Ideas"`, a search icon and the settings gear.
- **REVIEW-2.** The default tab when entering from Home is `"To Do"`.
- **REVIEW-3.** An empty To Do tab shows `"Nothing to do. Add a task from the home screen."` An empty Ideas tab shows `"No ideas yet."`
- **REVIEW-4.** The Review screen is for reviewing, completing and processing what already exists. It offers no way to author a new Item from blank: no add-task button, no add-idea button, no add-subtask button. Capture happens on the Home screen. The one creation-adjacent affordance is `"Make Task"` (IDEAS-6), which processes an existing Idea rather than authoring a new Item, and which still opens the full Create Task screen for confirmation.

### 5.6 List item rendering (shared by both tabs)
- **ROW-1.** The item name shows in full up to **4 lines**. Longer names are cut off with an ellipsis at the end of line 4.
- **ROW-2.** Below the name is one line of tags, each shown as `@tag` and separated by spaces. Tags that don't fit are cut off with an ellipsis. If the item has no tags, the line is omitted.
- **ROW-3.** Tapping or clicking anywhere on the name or tag text opens the item's Edit screen.
- **ROW-4.** Items are separated by vertical spacing and a thin divider line.
- **ROW-5 (trailing actions).** Where a row carries a trailing action button (currently only `"Make Task"`, IDEAS-6), it is right-aligned, vertically aligned with the **first line of the name**, and separated from the text block by at least **16 dp/px** of horizontal space. Its touch target is at least **48 × 48 dp** and MUST NOT overlap the row-opens-Edit tap region (ROW-3). Consecutive rows' trailing buttons MUST be at least **24 dp/px** apart vertically, so a mis-aimed tap cannot hit the neighbouring Item's button. The name text block shrinks to make room; it never flows under the button.

### 5.7 To Do tab (`SCR-TODO`)
- **TODO-1.** **Visible tasks:** all Tasks with `isDeleted == false` and `isArchived == false`. This includes `Todo`, `Blocked`, and `Done` tasks not yet archived.
- **TODO-2.** **Order:** by `createdAt` ascending (oldest first). Status changes do **not** move or regroup a task. Done and Blocked tasks stay where they are. (Manual drag ordering is a possible later iteration; the schema SHOULD leave room for a sort-key column.)
- **TODO-3.** Each Task row has a completion circle to the left of the name:
  - `Todo`: empty circle outline.
  - `Done`: circle with a green checkmark. The name is struck through if `settings.strikethroughDone`.
  - `Blocked`: circle filled with a grey ✕.
- **TODO-4.** Subtasks are listed below the Task's tag line, indented one step, each with its own completion circle using the same visuals. A subtask name shows up to 2 lines with an ellipsis. All subtasks are shown, including Done ones. When the parent is `Done`, the subtask circles are rendered in a visibly disabled state (SUB-1, SUB-2).
- **TODO-5.** Completion-circle taps follow §4.2 and §4.3. The change is persisted immediately.
- **TODO-6.** Below the last Task is a link `"Archived tasks"` that opens §5.9.

### 5.8 Ideas tab (`SCR-IDEAS`)
- **IDEAS-1.** **Groups:** four collapsible groups in fixed order `Now`, `Soon`, `Later`, `Distant`. Each has a header showing the timeframe name and the item count, e.g. `"Soon (4)"`. `Distant` is an ordinary group like the other three; it is simply collapsed by default.
- **IDEAS-2.** On entering the tab, a group is expanded if and only if it is in `settings.expandedIdeaGroups`. Tapping a header toggles that group. The toggle lasts until the user leaves the Review screen; it does not change the setting.
- **IDEAS-3.** Headers of empty groups are still shown, with count `(0)`, and cannot be expanded.
- **IDEAS-4.** Within a group, Ideas are ordered by `createdAt` ascending (oldest first).
- **IDEAS-5.** Ideas have **no** completion circle.
- **IDEAS-6 (Make Task).** Every Idea row carries a trailing button labelled `"Make Task"`, laid out per ROW-5. Pressing it opens the Create Task screen pre-filled from that Idea (§4.4). Nothing is written at this point: the Idea is consumed and the Task created only when the user presses `"Create Task"` on that screen (CONVERT-4). Cancelling returns to the Ideas tab with the Idea intact (CONVERT-5). The button's accessibility label is `"Make task from idea: <idea name>"`.
- **IDEAS-7.** The same conversion is also reachable from the Edit Idea screen (IDEAFORM-5), for when the user wants to inspect or adjust an Idea before converting it.

### 5.9 Archived Tasks (`SCR-ARCHIVE`)
- **ARCH-1.** Lists all Tasks with `isArchived == true` and `isDeleted == false`, grouped by the logical day they were completed, newest first. Group headers show dates such as `"Mon, Sep 21 2026"`.
- **ARCH-2.** Rows use §5.6 rendering with a checkmark circle that cannot be tapped.
- **ARCH-3.** Tapping a Task opens Edit Task in **read-only** mode, including the Advanced details panel, plus an `"Unarchive"` action. Unarchiving sets `isArchived = false`, clears `archivedAt`, sets status to `Todo` and clears `completedAt`. The Task then reappears in the To Do list with its subtask statuses unlocked.
- **ARCH-4.** If an active Task already holds the name, `"Unarchive"` is disabled and the NAME-9 message is shown. The read-only screen offers no rename as a workaround.

### 5.10 Search (`SCR-SEARCH`)
- **SEARCH-1.** A text field matches case-insensitive substrings of name, tags, context/description and subtask names.
- **SEARCH-2.** Filters:
  - Kind: Ideas / Tasks / Both.
  - Idea timeframe: multi-select, all four selected by default.
  - Task state: multi-select of Todo / Blocked / Done / Archived / Deleted. The default is all except Deleted.
- **SEARCH-3.** Results use §5.6 rendering with a small kind badge (`Idea` / `Task`). Tapping a result opens the corresponding Edit screen. A deleted Task opens read-only with a `"Restore"` action, subject to NAME-9 exactly as ARCH-4.

### 5.11 Settings (`SCR-SETTINGS`)
- **SET-1.** Lists every setting in §3.6 with an appropriate control:
  - Timeframe picker (`defaultIdeaTimeframe`).
  - Checklist of the four timeframes (`expandedIdeaGroups`).
  - Toggles (`strikethroughDone`, `confirmDestructive`).
  - Time picker (`endOfDay`).
  - Theme picker (`theme`) and Decor picker (`decor`), presented as two separate controls under an `"Appearance"` heading.
- **SET-2.** Changes apply immediately and persist.
- **SET-3.** A read-only `"About"` row shows the app version and this spec's version number.
- **SET-4.** A `"Sync"` section holds the sync settings and actions. It is specified in §11.8.

---

## 6. Item history
- **HIST-1.** The fields in §3 record the lifecycle timestamps: created, updated, completed, archived, deleted, and converted-from. They are surfaced in the Advanced details panel (IDEAFORM-6, TASKFORM-9).
- **HIST-2.** Each replica also keeps an append-only **event log**. Each entry records `{eventId, itemId, itemKind, type, timestamp, payload}`. Types are: `created`, `renamed`, `tagsChanged`, `contextChanged`, `timeframeChanged`, `statusChanged`, `subtaskAdded`, `subtaskChanged`, `subtaskRemoved`, `subtasksReordered`, `archived`, `unarchived`, `deleted`, `restored`, `convertedToTask`, `merged`.

  The MVP does not show this log in the UI. It exists for audit and for future, better merge strategies (§9.1).

---

## 7. Non-functional requirements
- **NFR-1 (Offline).** All functionality in §3–§6 works with no network.
- **NFR-2 (Capture latency).** From cold start to a focused name field on Add Idea: 2 taps. Target under 1.5 s on a mid-range Android device.
- **NFR-3 (Durability).** No acknowledged write may be lost on crash or forced close.
- **NFR-4 (Code clarity).** The owner, an experienced programmer, must be able to read the codebase without prior context. That means:
  - Conventional project layout.
  - Domain logic separated from UI and persistence.
  - Doc comments on public types.
  - Requirement IDs referenced in comments where a rule is implemented.
  - No clever metaprogramming.
- **NFR-5 (Testing).** Automated unit tests MUST cover every rule in §3.7, §4 and §9.3, including the acceptance scenarios in §10. UI tests SHOULD cover the main flows in §5.1.
- **NFR-6 (Accessibility).** All interactive controls have accessibility labels. Completion circles expose their state and whether they are locked (e.g. "Todo, button"; "Done, locked").
- **NFR-7 (Responsiveness).** The UI adapts to phone portrait and to desktop windows from 400 px wide upward.

---

## 8. Storage (abstract)
- **STORE-1.** Each replica owns one local database.
- **STORE-2.** All reads and writes go through repository interfaces (`IdeaRepository`, `TaskRepository`, `SettingsRepository`, `EventLog`, `TombstoneStore`). UI code MUST NOT access the database directly. A later version must be able to add a remote-backed implementation without changing UI or domain code.
- **STORE-3.** Multi-record operations are atomic: conversion (§4.4), merge application (§9) and archive sweeps (§4.5).
- *Concrete engine, schema, constraints and migrations: §11.5.*

---

## 9. Sync and merge

### 9.1 Abstraction
- **MERGE-1.** Merging is performed by a pure, side-effect-free component:

  ```
  interface MergeStrategy {
      merge(inputs: List<ReplicaSnapshot>) -> MergeResult
  }
  ReplicaSnapshot = { replicaId, ideas[], tasks[], tombstones[] }
  MergeResult     = { ideas[], tasks[], tombstones[], mergeReport }
  ```

  **`ReplicaSnapshot` and `MergeResult` are `zen_domain` types**, declared in `merge/replica_snapshot.dart`. They hold domain entities and nothing else — no wire metadata, no JSON. `MergeStrategy` lives in `zen_domain` (§11.1), so placing the snapshot type anywhere else would make `zen_domain` depend on `zen_sync` and invert the dependency direction the architecture rests on.

  `zen_sync` owns only the **envelope and the codec** (§11.6.1): `formatVersion`, `deviceName`, `generatedAt`, `appVersion`, and the JSON encoding of the whole thing. It wraps a `ReplicaSnapshot`; it is not one. A merge never sees the envelope, which is why the merge can be tested with no serialization at all.

  The strategy is chosen through dependency injection. The MVP ships `NameUnionMergeStrategy` (§9.3).
- **MERGE-2.** The merge MUST be **deterministic**: the same inputs in any order produce the same output, so two replicas running it independently reach identical results.
- **MERGE-3.** Settings (§3.6) are per replica and are never merged.
- **MERGE-3A (which collections are ordered).** Two kinds of collection appear in a snapshot, and they must not be treated alike.
  - `ideas`, `tasks` and `tombstones` are **sets**. Their list form carries no meaning: the To Do list orders by `createdAt` (TODO-2) and the Ideas list groups by timeframe (IDEAS-1, IDEAS-4), so nothing downstream reads the order they arrived in. Two results holding the same members are the same result.
  - A Task's `subtasks` and an Item's `tags` are **sequences**. Subtask order is user-controlled and visible (§3.3, TASKFORM-2, TODO-4); tag order is visible in the row's tag line (ROW-2). A merge that reorders them has changed the user's data.

  Because the first three are sets, their list form needs a **canonical order** rather than a meaningful one, so that two merges of the same content are literally equal (MERGE-2, AC-19). Every output collection of the first kind is emitted **sorted ascending by `id`** — a strict total order, since output ids are distinct. Ids are UUIDv7 and therefore time-ordered, so this is also approximately creation order. The sequences keep the order step 4 and step 5 give them.
- **MERGE-4.** The merge itself assumes only that "all reachable replica snapshots are available at merge time". How snapshots travel between replicas, and when a merge runs, is specified in §11.6.

### 9.2 Identity and conflict
- **MERGE-5.** Two Ideas, or two Tasks, are **conflicting** if they have the same `id`, **or** if both are **active** (§2) and their normalized names are equal. Conflict is transitive: take the connected components of this relation. Ideas never conflict with Tasks.
- **MERGE-6.** Restricting name matching to active Items is what allows recurring names (NAME-7). An archived Task "Water the plants" from last week and today's active Task of the same name are different Items and MUST NOT be merged. Archived and deleted Tasks conflict by `id` only.

### 9.3 MVP rule: `NameUnionMergeStrategy`

**Record order.** Several rules below need a deterministic order over records, including records that share an `id`. *Record order* is a comparator over records of one kind that compares, in sequence: `id`; `updatedAt`; normalized name; raw name; `createdAt`; then the remaining scalar fields in their §3.2 / §3.3 declaration order; then, for Tasks, the subtask list by length and then element-wise by `id`, `name`, `status`, `updatedAt`.

It is not a total order: records equal in every field compare equal. That is harmless, because such records are interchangeable — any choice between them yields the same output. It is therefore a total order *up to field-for-field equality*, which is all determinism requires.

**Wherever a rule says "in record order", this comparator is meant.** An earlier draft said "sorted by `id`" in several places; that was wrong, because `id` is not a key here — a component normally holds one record per replica, all carrying the same `id`.

1. **Tombstones first.** Collect the tombstones from all inputs and **reduce them to one per Idea `id`**: take the earliest `deletedAt`, and on a tie prefer `reason = converted` over `deleted`, since a conversion leaves behind a Task pointing at that id. A plain set union keeps two tombstones for one Idea when one replica deleted it and another converted it — a meaningless output, and a landmine for M3's tombstone table, which keys on `id`. `reason` is informational; nothing in this algorithm reads it.

   Then drop every Idea whose `id` appears in the reduced set. Tombstones carry no name, so an Idea created after a deletion, with a fresh id, survives even if its name matches the deleted one.

2. **Union.** Take all remaining Ideas and Tasks from all inputs.

3. **Group** into conflict components (MERGE-5). A component of size 1 passes through unchanged.

4. **Resolve** each component of size > 1 into one record.

   **Choosing the primary record.** A component normally contains *several records that share the chosen `id`* — the same Item as it stands on each replica. "The record whose `id` was chosen" is therefore not yet a single record, and the choice decides whether a rename propagates or is silently reverted. The **primary record** is, among the records carrying the chosen `id`:

   1. the one with the **latest `updatedAt`** — so the most recent edit wins, which is what makes a rename on one device survive the merge;
   2. on a tie, the one whose **normalized name sorts first**;
   3. on a further tie, the first **in record order**.

   All three steps are content-based, so the result never depends on which replica a record arrived from, or on the order of `inputs` (MERGE-2).

   *Why this matters:* rename "groceries list" to "Groceries" on the phone while the desktop still holds the old name. Both records carry the same `id`, so the component is `{phone, desktop}`. Without rule 1, the merge may pick the desktop's name and undo the rename — and being deterministic, it would undo it again after every future sync.

   | Field | Rule |
   |---|---|
   | `id` | The lexicographically smallest `id` in the component. Deterministic, and always one of the real conflicting ids. |
   | `name` | The primary record's name, as chosen above. |
   | `context` / `description` | The longest, measured in **grapheme clusters** (the unit NAME-2 counts). Ties, in order: among the tied-longest, the latest `updatedAt`; then the primary record **if its text is among the tied-longest**; then record order. |
   | `tags` | Union, de-duplicated case-insensitively. Order: the primary record's tags in their own order, then tags contributed by the remaining records taken **in record order**, each record's in its own order, skipping duplicates. |
   | `timeframe` (Ideas) | The most urgent: `Now` > `Soon` > `Later` > `Distant`. |
   | `status` (Tasks) | Precedence `Done` > `Blocked` > `Todo`. |
   | `isDeleted` / `deletedAt` (Tasks) | `isDeleted` is `true` if any record is deleted. `deletedAt` is the earliest non-null **when `isDeleted` is true, and null otherwise** (INV-4). |
   | `isArchived` / `archivedAt` (Tasks) | `isArchived` is `true` if any record is archived **and** the resolved status is `Done`. `archivedAt` is the earliest non-null **when `isArchived` is true, and null otherwise** (INV-4). The condition on the flag is what keeps `archivedAt` from surviving a status that is no longer `Done`. |
   | `completedAt` | If the resolved status is `Done`: the earliest non-null among records with status `Done`. Otherwise null (INV-1). |
   | `createdAt` | Earliest. |
   | `updatedAt` | Latest. |
   | `sourceIdeaId` / `sourceIdeaCreatedAt` | Resolved **as a pair**, never independently: take both fields from the first record whose `sourceIdeaId` is non-null — the primary record if it qualifies, otherwise the records in record order. §3.3 makes them one fact about one Idea, so a Task must never carry one Idea's id beside another Idea's creation time. |
   | `subtasks` | See step 5. |

5. **Subtask resolution — union.** Matching is by `id` first, and by position-within-a-name only as a **fall-back for what `id` did not match**.

   The two relations must not be combined into one "shares an `id` **or** shares a key" relation, because they chain: a single renamed subtask then drags two distinct subtasks into one component and destroys one of them. Rename subtask `1` from "Set" to "Warmup" on one replica, while the other still has `[Set 1, Set 2]`, and `A1 ~ B1` by id, `A2 ~ B2` by id, but `A1 ~ B2` by the key `(set, 0)` — one component, and the user's two "Set" subtasks silently become one. That breaches principle 1.2.4.

   - (a) **Match by `id`.** Group subtasks across records that share an `id`. Ids are unique within a record, so each group holds at most one subtask per record.
   - (b) **Key the remainder.** Among the subtasks *not* matched in (a), compute a key within each record: the *k*-th subtask bearing a given normalized name has key `(normalizedName, k)`, counting from that record's own list order over its unmatched subtasks only. Group those that share a key.
   - (c) The output is the **union** of the groups from (a) and (b). No subtask is dropped. Because each subtask joins exactly one group, and each group holds at most one subtask per record, no group can contain two subtasks of the same record.
   - (d) Each group resolves to one subtask: `id` = smallest id in the group; `name` from the **primary subtask** — the member with the latest `updatedAt`, then in record order — so a renamed subtask is not reverted; `status` = highest precedence in the group (`Done` > `Blocked` > `Todo`); `createdAt` = earliest; `updatedAt` = latest; `completedAt` = when the resolved status is `Done`, the earliest non-null among members whose status is `Done`, and null otherwise (INV-1).
   - (e) **Order:** first the groups containing a subtask of the primary record, in that record's order; then the remaining groups, ordered by the first record **in record order** that contributed to the group, and within a record by that subtask's position.

   Where matching fails, this produces a **duplicated** subtask rather than a deleted one — visible and fixable by hand, rather than silent loss.

6. **Re-establish invariants** (§3.7).
   - If the resolved Task status is `Done` but some unioned subtask is not `Done`, set the Task's status to `Todo` and clear `completedAt`, `isArchived` **and `archivedAt`** (INV-1 through INV-4). Record this in the merge report. This happens when one replica completed a task while another added a new subtask to it.
   - If output Items of the same kind are both active and share a normalized name, NAME-6 is broken and they must be combined. **Group every active output Item of that kind by normalized name, and resolve each group of size > 1 through steps 4–6 as a single component** — not by merging pairs. Pairwise merging is order-dependent once three Items collide, because the primary record of a pair need not be the primary of the whole group, which would break MERGE-2. Repeat until a pass changes nothing.

     This is reachable even though step 3 already matches on names, because MERGE-5 restricts name matching to *active* records. An archived record can enter a component by `id`, become the primary, and carry its name into an output Item that the resolved status makes active again — landing on a name another component already resolved to.

     **Termination.** The first pass can *increase* the number of active Items, because the repair above un-archives, so "each pass strictly reduces the active count" is false for that pass. Every later pass operates only on already-active Items, where nothing can be un-archived again, and merging strictly reduces their number — so the iteration terminates.

     **For Ideas this branch provably never fires.** Every Idea is active (§2), so two components resolving to the same name would have shared an edge in step 3 and been one component. Assert this in a test rather than leave it as folklore.

7. **Report.** `mergeReport` lists each component that was merged: its input ids, the output id, and any invariant repairs. A `merged` event is appended to the event log for each merged component.

8. **Canonical output order.** Emit `ideas`, `tasks` and `tombstones` **sorted ascending by `id`**, per MERGE-3A. They are sets; sorting gives `MergeResult` a canonical form, which is what lets AC-19 compare two merges field for field and makes a snapshot file byte-identical for identical content. `tags` and `subtasks` keep the order steps 4 and 5 give them.

### 9.4 Known limitations of the MVP merge (accepted)
- **Undo does not survive a peer that has not seen it.** Three flags are sticky, because step 4 resolves each by "true if any record has it": `status = Done`, `isDeleted`, and `isArchived`. So un-completing, restoring a deleted Task, and un-archiving a Task are each reverted by a replica that still holds the earlier state. The user's remedy is the same in all three cases: sync first, then undo, then sync again. This is the largest behavioural wart in the MVP merge and the most likely thing to warrant a better strategy later (§9.1).
- Two genuinely different active Items that happen to share a name are merged into one.
- An edit made on one replica can be lost if a longer text exists on another.
- Subtasks that `id` cannot match fall back to position within a name, so reordering same-named subtasks on one replica while renaming one on another can pair the wrong two. The fall-back is deliberately ordered after `id` matching (step 5) so that the failure is a duplicated subtask rather than a destroyed one.
- The step-6 repair is the one place where a Task's status changes without the user asking. It only ever moves a Task from `Done` to `Todo`, never the reverse, and it is always reported.

---

## 10. Acceptance scenarios

**AC-1 (complete blocked by subtasks).** Given Task "Write report" with subtasks [Draft: Done, Proofread: Todo]. When the user taps the task's circle, then status stays `Todo` and the popup `"This task has incomplete subtasks. Complete the subtasks before finishing this task."` is shown.

**AC-2 (complete).** Given the same task with both subtasks Done. When the user taps the circle, then status becomes `Done`, `completedAt` is set, a green check shows and the name is struck through (default settings).

**AC-3 (subtask statuses lock when Done).** Given a Done task with all subtasks Done. When the user taps a subtask's completion circle in the To Do list, then nothing changes: the subtask stays `Done`, the task stays `Done`, and the hint `"Set the task back to Todo to change its subtasks' status."` is shown. When the user then taps the task's circle (task → Todo) and taps the subtask's circle again, then the subtask becomes `Todo`.

**AC-4 (Done task, partially editable subtask list).** Given a Done task opened in Edit Task. Then subtask status controls are disabled and the `"Add subtask"` row is absent, but renaming, deleting and reordering all work. When the user sets Status to Todo, then the status controls become editable and `"Add subtask"` appears, without saving first.

**AC-5 (adding a subtask requires reopening).** Given a Done task opened in Edit Task. Then there is no way to add a subtask. When the user sets Status to Todo, adds a subtask and presses Save, then the Task is saved as `Todo` with the new subtask and `completedAt` cleared.

**AC-6 (archive across days).** Given EoD = 02:00 and a task completed Tue 23:10. The app is closed until Thu 09:00. When the app starts, then the task is archived with `archivedAt` = Wed 02:00 local. It is absent from To Do and present in Archived Tasks under Tuesday.

**AC-7 (blocked not toggleable).** Given a Blocked task. When its circle is tapped, then nothing changes. Its subtasks remain toggleable.

**AC-8 (uniqueness).** Given an active Task "Buy milk". When the user tries to add another Task "buy  MILK", then the save button is disabled and `"A task with this name already exists."` is shown. Adding an **Idea** named "Buy milk" succeeds.

**AC-9 (name reuse after archive).** Given Task "Water the plants" that has been archived. When the user adds a new Task "Water the plants", then it is created successfully and both exist: one archived, one active.

**AC-10 (reactivation blocked).** Continuing AC-9, when the user opens the archived "Water the plants" and presses `"Unarchive"`, then the action is blocked with `"There is already an active task with this name in your To Do list. Complete and archive the active task in order to restore this one to your To Do list."` No rename option is offered. The same applies to restoring a deleted Task.

**AC-11 (convert).** Given Idea "Learn Rust" with tags [code], context "Book + exercises", timeframe Soon. When the user presses `"Make Task"` on its row in the Ideas list and confirms without edits, then a Task "Learn Rust" exists with tags [code], description "Book + exercises", status Todo, no subtasks, and `sourceIdeaId` set. The Idea is gone, a tombstone with `reason = converted` exists, and the To Do list is shown. Both changes happen in one transaction. Reaching the same screen via Edit Idea → "Create Task" gives an identical result.

**AC-12 (convert cancelled).** When the user presses `"Make Task"`, edits the pre-filled name, then cancels, then the Idea is unchanged — including its timeframe and original name — no Task exists, and the app is on the Ideas tab.

**AC-13 (merge ideas).** Replica A has Idea {id `0190…a`, "Read SICP", tags [cs], Later, context "short"}. Replica B has {id `0190…b`, "read  sicp ", tags [books, CS], Soon, context "a longer context"}. The merge yields one Idea: id `0190…a`, name "Read SICP", tags [cs, books], timeframe Soon, context "a longer context".

**AC-14 (merge tasks, subtask union).** Replica A has Task "Move" (Todo) with subtasks [Pack: Done, Clean: Todo]. Replica B has "Move" (Todo) with [Pack: Todo, Clean: Blocked, Keys: Todo]. The merged Task has three subtasks: Pack: Done, Clean: Blocked, Keys: Todo. Status stays Todo.

**AC-15 (merge, duplicate subtask names).** Replica A has Task "Gym" with subtasks [Set: Done, Set: Todo]. Replica B has "Gym" with [Set: Todo, Set: Done, Set: Todo]. Positional matching within the name gives three output subtasks: Set: Done, Set: Done, Set: Todo.

**AC-16 (merge repairs INV-2).** Replica A has Task "Ship" `Done` with subtasks [Test: Done]. Replica B has "Ship" `Todo` with [Test: Done, Docs: Todo]. Resolved status would be `Done`, but the unioned subtasks include Docs: Todo, so the output is `Todo` with `completedAt` cleared, and the merge report records the repair.

**AC-17 (no resurrection).** An Idea deleted on A (tombstone) and unchanged on B does not appear after the merge.

**AC-18 (name reuse survives merge).** Idea `x` named "Call bank" is deleted on A (tombstone for `x`), then a new Idea `y` named "Call bank" is created on A. Replica B still has `x`. After the merge, exactly one Idea named "Call bank" exists, with id `y`.

**AC-19 (determinism).** `merge([A, B]) == merge([B, A])`, field for field, including subtask order.

---

## 11. Implementation

### 11.0 Decisions

| Area | Decision |
|---|---|
| Language / framework | **Flutter** (Dart), stable channel |
| Local database | **SQLite via Drift** |
| State management | **Riverpod 3.x**, without code generation |
| Navigation | **go_router** |
| Code generation | **Drift only.** No `freezed`, no `riverpod_generator`. Domain classes are hand-written. |
| Sync transports (MVP) | **Both**: `FileSnapshotTransport` and `LanSyncTransport` |
| Pre-merge backup | **Yes**, every merge writes a restorable snapshot first |
| Version control | **Git from the first commit**, with GitHub Actions CI |

### 11.1 Architecture overview

Four packages in one repository, with dependencies flowing in one direction only:

```
zen_app ──▶ zen_data ──▶ zen_domain
   └──────▶ zen_sync ──▶ zen_domain
```

- **`zen_domain`** is a **pure Dart package**. Its `pubspec.yaml` MUST NOT depend on `flutter`, `drift`, `sqlite3`, `shelf`, or anything that touches IO. It holds entities, value objects, the rules of §4, the merge of §9, the End-of-Day calculator of §4.5, the `Clock` abstraction, and the repository *interfaces*. Everything in it is deterministic and testable with `dart test`.
- **`zen_data`** holds the Drift schema, migrations and the repository *implementations*.
- **`zen_sync`** holds the snapshot format, the `SyncTransport` interface, both transports, and the sync orchestrator.
- **`zen_app`** holds the Flutter UI, Riverpod providers, routing, theming and platform glue.

This split is deliberate and load-bearing: because `zen_domain` cannot import Flutter, the compiler enforces the boundary that NFR-4 and STORE-2 ask for, and the entire rules engine tests in about a second with no emulator.

Packages are wired with plain path dependencies. **Do not add melos**; four packages do not need a monorepo tool, and it would cost clarity (NFR-4).

Dependency injection is constructor injection throughout the domain, data and sync layers. Riverpod is used *only* in `zen_app`, as the composition root that constructs the concrete implementations and hands them down. No `zen_domain` or `zen_data` type may reference a Riverpod provider.

### 11.2 Technology stack

Target the Flutter **stable** channel, pinned to an exact version in `.fvmrc` and in CI so that both machines and the build agree. At the time of writing, stable is 3.47.x with Dart 3.13.

**Before adding any package below, the implementer MUST check its current version, null-safety status and maintenance state on pub.dev, and record the resolved version in `DECISIONS.md`.** Package recommendations date quickly; the list names roles and the best-known candidate for each, not immutable choices. Where a named package turns out to be discontinued, choose the closest maintained equivalent and record the substitution.

| Role | Package | Notes |
|---|---|---|
| Database | `drift`, `drift_flutter`, `drift_dev`, `build_runner` | Since drift 2.32, SQLite is bundled automatically; `sqlite3_flutter_libs` is no longer needed. |
| Unicode normalization | `unorm_dart` | **`zen_domain`.** Pure Dart, no IO, so §11.1 holds. Supplies the NFC pass in §2's normalization. |
| Grapheme clusters | `characters` | **`zen_domain`.** NAME-2 counts user-perceived characters, which `dart:core` cannot do. |
| IANA time zones | `timezone` | **`zen_data` only.** Supplies the `TimeZoneRules` adapter (§11.4.3). It MUST NOT be a `zen_domain` dependency — it reaches `dart:io`, which §11.1 forbids there. The domain declares the one-method port; the data layer implements it. |
| Paths | `path_provider`, `path` | |
| State | `flutter_riverpod` (3.x) | Plain `Notifier` / `NotifierProvider` / `StreamProvider`. No annotations, no build step. |
| Routing | `go_router` | |
| IDs | `uuid` | UUIDv7 (`uuid.v7()`). Verify v7 support in the resolved version. |
| LAN server | `shelf`, `shelf_router` | Desktop only, but the package is pure Dart and may be depended on unconditionally. |
| LAN client | `http` | |
| Crypto | `cryptography` (AES-GCM, HKDF-SHA256) | Alternative: `pointycastle`. |
| Service discovery | `nsd` | Must support **both** registration and discovery on Android and Windows. `flutter_nsd` is discovery-only and is therefore insufficient. `bonsoir` is the alternative. |
| QR display | `qr_flutter` | Desktop pairing screen. |
| QR scanning | `mobile_scanner` | Android pairing screen. |
| Android folder access | `saf_util` (with `saf_stream` if streaming is needed) | For SAF persistable tree URIs. **Note:** `shared_storage` is discontinued and MUST NOT be used. `saf` is an alternative. |
| Desktop folder picker | `file_selector` | |
| App/device metadata | `package_info_plus`, `device_info_plus` | For the About row (SET-3) and the pairing device name. |
| Formatting | `intl` | Date rendering in ARCH-1 and the Advanced details panels. |
| Lints | `flutter_lints` plus the extra rules in §11.11 | |
| Testing | `test`, `flutter_test`, `integration_test` | Property tests use hand-written generators with a seeded `Random`; no property-testing dependency. |

**Build prerequisites.**
- Windows: Visual Studio **2022** with the "Desktop development with C++" workload. Visual Studio 2026 is **not** supported for compiling Flutter Windows desktop apps; do not install it as the build toolchain.
- Android: `compileSdk` 36, `targetSdk` 36, `minSdk` 26.

### 11.3 Repository layout

```
zen/
├─ .fvmrc                     pinned Flutter version
├─ DECISIONS.md               every choice this spec left open (§0.1)
├─ ZEN_SPEC.md                this document
├─ README.md                  setup, build, run, test
├─ .github/workflows/ci.yaml
├─ packages/
│  ├─ zen_domain/
│  │  ├─ lib/src/
│  │  │  ├─ model/            Idea, Task, Subtask, Tag, ItemName, enums
│  │  │  ├─ rules/            task_rules.dart, subtask_rules.dart,
│  │  │  │                    conversion_rules.dart, name_rules.dart
│  │  │  ├─ time/             clock.dart, end_of_day.dart
│  │  │  ├─ merge/            replica_snapshot.dart, merge_strategy.dart,
│  │  │  │                    name_union_merge_strategy.dart, merge_report.dart
│  │  │  ├─ repository/       interfaces only
│  │  │  └─ result.dart       Result<T, E>, RuleViolation
│  │  └─ test/
│  ├─ zen_data/
│  │  ├─ lib/src/
│  │  │  ├─ tables/           Drift table definitions
│  │  │  ├─ database.dart     AppDatabase, migrations
│  │  │  └─ repository/       Drift-backed implementations
│  │  └─ test/                includes generated migration tests
│  ├─ zen_sync/
│  │  ├─ lib/src/
│  │  │  ├─ snapshot/         JSON codec, envelope, versioning
│  │  │  │                    (the ReplicaSnapshot *type* is in zen_domain)
│  │  │  ├─ transport/        sync_transport.dart, file_transport.dart,
│  │  │  │                    lan_transport.dart, lan_server.dart, crypto.dart
│  │  │  ├─ backup/           pre-merge backup writer and restorer
│  │  │  └─ orchestrator.dart
│  │  └─ test/
│  └─ zen_app/
│     ├─ lib/src/
│     │  ├─ screens/          one file per SCR-* screen
│     │  ├─ widgets/          ItemRow, CompletionCircle, TagChips, SubtaskEditor
│     │  ├─ providers/        Riverpod providers (thin)
│     │  ├─ theme/            decor packs, ColorScheme pairs
│     │  └─ router.dart
│     ├─ android/  windows/
│     └─ test/
└─ tools/
```

### 11.4 `zen_domain`

#### 11.4.1 Results, not exceptions
Rules return values. Exceptions are reserved for programmer error.

```dart
sealed class Result<T, E> { const Result(); }
final class Ok<T, E> extends Result<T, E> { final T value; const Ok(this.value); }
final class Err<T, E> extends Result<T, E> { final E error; const Err(this.error); }

sealed class RuleViolation {
  /// The exact message from §4.2. The UI renders `message`; it never composes its own.
  String get message;
}

final class IncompleteSubtasks extends RuleViolation {
  @override String get message =>
    'This task has incomplete subtasks. Complete the subtasks before finishing this task.';
}
final class NameCollision extends RuleViolation { /* NAME-8 / NAME-9 messages */ }
final class SubtasksLocked extends RuleViolation { /* SUB-2 hint */ }
```

Every row of the §4.2 transition table becomes a function of this shape, and therefore a two-line test:

```dart
/// §4.2, STATUS-2, SUB-1. Pure. Does not touch the clock directly.
Result<Task, RuleViolation> completeTask(Task task, DateTime now);
Result<Task, RuleViolation> reopenTask(Task task);
Result<Task, RuleViolation> setTaskStatus(Task task, TaskStatus target, DateTime now);
Result<Task, RuleViolation> setSubtaskStatus(Task task, String subtaskId, TaskStatus target, DateTime now);
Result<Task, RuleViolation> addSubtask(Task task, String name, DateTime now);   // SUB-8 rejects when Done
Result<Task, RuleViolation> reorderSubtasks(Task task, int from, int to, DateTime now);
```

#### 11.4.2 Value objects
`ItemName.parse(String)` encodes NAME-1 through NAME-4 and exposes both `value` and `normalized` (§2). `Tag.parse(String)` encodes TAG-1 through TAG-3. Constructing an entity with a raw `String` name MUST NOT be possible; the constructor takes `ItemName`.

Uniqueness (NAME-6) is *not* enforced here — it needs the store. It lives in the repository and, ultimately, in the database index (§11.5.2).

#### 11.4.3 Clock
```dart
abstract interface class Clock {
  DateTime nowUtc();
  /// The device's current IANA zone, e.g. 'America/Toronto'.
  String localZoneId();
}
```
Every rule that needs the time takes it as a parameter, and every service that needs one takes a `Clock`. **`DateTime.now()` MUST NOT appear anywhere in `zen_domain`, `zen_data` or `zen_sync`.** A lint rule enforces this (§11.11). Tests use a `FakeClock` so that EOD-2 through EOD-5 can be exercised at exact instants, including the DST cases.

#### 11.4.4 End of Day
```dart
/// EOD-2, EOD-5. Pure: given a completion instant, the configured local
/// wall-clock time, and a zone, returns the instant at which the task archives.
DateTime archiveBoundaryAfter(DateTime completedAtUtc, LocalTime endOfDay, String zoneId);
```
EOD-5 requires wall-clock semantics across DST, including the spring-forward case where the configured time does not exist on a given date. Handle this explicitly and test both transition directions.

#### 11.4.5 Merge
`NameUnionMergeStrategy` implements §9.3 exactly, as a pure function with no IO and no clock. It is the single most intricate piece of code in the project and the most heavily tested (§11.12).

#### 11.4.6 Repository interfaces
Declared here, implemented in `zen_data`:

```dart
abstract interface class IdeaRepository {
  Stream<List<Idea>> watchAll();
  Future<Idea?> findById(String id);
  Future<Idea?> findActiveByNormalizedName(String normalized);
  Future<Result<Idea, RuleViolation>> create(Idea idea);
  Future<Result<Idea, RuleViolation>> update(Idea idea);
  Future<void> delete(String id, DateTime now);          // DEL-3, writes a tombstone
}

abstract interface class TaskRepository { /* …, plus archive sweep and restore/unarchive */ }
abstract interface class SettingsRepository { /* … */ }
abstract interface class EventLog {
  Future<void> append(ItemEvent event);
  Future<List<ItemEvent>> forItem(String itemId);
  /// §11.5.1's cap. Global, not per item. Both numbers are one named constant.
  Future<int> prune(DateTime nowUtc);
}
abstract interface class TombstoneStore { /* … */ }

/// CONVERT-4: creates the Task, deletes the Idea and writes the tombstone
/// in ONE transaction. Declared as a single method so that atomicity
/// cannot be lost by a caller.
abstract interface class ConversionService {
  Future<Result<Task, RuleViolation>> convert(Idea idea, Task draft, DateTime now);
}
```

### 11.5 `zen_data`

#### 11.5.1 Tables
`ideas`, `tasks`, `subtasks`, `idea_tags`, `task_tags`, `idea_tombstones`, `events`, `settings`, `replica`.

- `subtasks` has `task_id` (FK, `ON DELETE CASCADE`) and an explicit `sort_index` integer; the list order in §3.3 is user-controlled and MUST NOT depend on insertion order or id.
- **Tags live in two per-kind tables, `idea_tags` and `task_tags`**, each with `(owner_id, value, value_normalized, sort_index)`, a real foreign key to its owner with `ON DELETE CASCADE`, `UNIQUE (owner_id, value_normalized)` — which is what actually enforces TAG-4 — and `UNIQUE (owner_id, sort_index)`. Index `value_normalized` for TAG-6's autocomplete, which is then a `UNION` of two indexed queries.

  *An earlier draft specified a shared `tags` table plus a polymorphic `item_tags`. That was wrong twice over. Keyed on `value_normalized` it forces one global casing, so an Item that stored `@CS` reads back as `@cs`, contradicting TAG-4 and breaking round-trip equality; keyed on `value` it lets `@Work` and `@work` both attach to one Item, which TAG-4 forbids. Carrying the value on the attachment fixes both, because TAG-4's rule is per Item. The polymorphic table was also unable to carry a foreign key, so hard-deleting an Idea (DEL-3) orphaned its tag rows and left them feeding autocomplete; per-kind tables get `ON DELETE CASCADE` for free. There is no separate tag entity in this product — no rename, no metadata, no tag screen — so the join it required bought nothing.*
- `settings` is a key-value table in the same database file, so there is a single file to back up. Settings are excluded from snapshots (MERGE-3).
- `replica` holds exactly one row: this device's `replica_id` (UUIDv7, generated on first launch) and `device_name`.
- `events` implements HIST-2. It is local-only and never travels in a snapshot. Because it is append-only and the app is meant to run for years, it is **capped**: on each app start, delete entries older than 365 days, keeping at least the most recent 5,000 regardless of age. The cap is a constant in one place, so it can be raised if the log ever becomes useful for a better merge strategy (§9.1).

#### 11.5.2 Constraints — NAME-6 and NAME-7 in the schema
Both `ideas` and `tasks` carry a `name_normalized` column, written on every insert and update, using the single normalization function from §2 — **including its NFC pass**. Changing the normalization rule after this column exists means recomputing every row, and such a migration can *fail* where two rows that were distinct become equal and collide with the unique index below. So the rule must be settled before M3 creates the schema, not after. Uniqueness is then a **partial unique index**, which makes a duplicate impossible rather than merely unlikely:

```sql
CREATE UNIQUE INDEX idx_ideas_active_name
  ON ideas (name_normalized);

CREATE UNIQUE INDEX idx_tasks_active_name
  ON tasks (name_normalized)
  WHERE is_deleted = 0 AND is_archived = 0;
```

The `WHERE` clause is exactly NAME-7: archived and deleted Tasks stop reserving their names. The UI check in NAME-8 and the reactivation check in NAME-9 remain, because they produce good error messages, but the index is the actual guarantee, and a constraint violation surfacing as a `NameCollision` result is a correct (if less pretty) outcome.

**Timestamp storage.** Timestamps are stored as **ISO-8601 text**, not as Unix seconds. Drift's `store_date_time_values_as_text` defaults to `false`, which silently truncates every instant to whole seconds; set it to `true` in `zen_data/build.yaml`. Text mode round-trips exactly through `toIso8601String()` / `DateTime.parse`, which is the format §3 already specifies. Settle this before the schema exists — changing it afterwards means rewriting every row, and the precision it destroys cannot be recovered.

**Single-row constraints.** Each is named after the invariant it enforces, so a test can assert *which* one fired rather than merely that something did:

```sql
CHECK ((status = 'done') = (completed_at IS NOT NULL))          -- INV-1
CHECK ((is_archived = 1) = (archived_at IS NOT NULL))           -- INV-4
CHECK ((is_deleted  = 1) = (deleted_at  IS NOT NULL))           -- INV-4
CHECK (is_archived = 0 OR status = 'done')                      -- INV-3
CHECK (created_at <= updated_at)                                -- INV-5
CHECK ((source_idea_id IS NULL) = (source_idea_created_at IS NULL))  -- INV-8
CHECK (length(created_at) = 24 AND created_at LIKE '%Z')        -- INV-9
```

INV-5's comparison is sound only because every timestamp is the same width (§3, INV-9), which is why the INV-9 checks are worth their cost: they make uniform width a property of the data rather than an assumption about the writer. Apply INV-5 and INV-9 to `ideas`, `tasks` and `subtasks`, and to every timestamp column.

**Cross-row constraints: INV-2 and INV-7 get triggers.** Both span rows, so no `CHECK` can express them — but a `BEFORE INSERT`/`BEFORE UPDATE` trigger raising `RAISE(ABORT, 'INV-2: …')` can, and unlike a repository check it cannot be bypassed and *can be attacked directly in raw SQL by a test*. A repository-level check would pass its tests identically whether present or absent, which is the failure mode these constraints exist to rule out. Keep the repository checks as well, for their better error messages; the triggers are the guarantee.

Trigger ordering has a consequence for M6, recorded here so it is not later diagnosed as a schema defect: a merge must not be applied row by row. See §11.6.5.

**These constraints are not redundant with the domain's assertions.** `zen_domain` guards its invariants with `assert`, which Dart strips from release builds. In the app you actually run, the `CHECK` constraints, the triggers and the unique indexes are therefore the *only* enforcement that executes. Treat them as the real guarantee and the assertions as a development aid, not the other way round.

**Violations are detected by attempting the write, not by pre-checking it.** A `SELECT` before an `INSERT` has a time-of-check-to-time-of-use window, and it also means the index under test never fires, so M3's definition of done would be satisfied by code that never exercises the constraint at all. Repositories therefore attempt the write and translate the failure into the matching `RuleViolation`. Map on SQLite's **numeric extended result code plus the constraint or table name** — `2067` for a unique-index violation, `275` for a failed `CHECK`, `1811` for a trigger's `RAISE(ABORT)` — never on the message text, which varies between SQLite builds.

Two limits are accepted rather than papered over:

- **INV-6 is not fully expressible in SQL.** NAME-2 and NAME-3 count Unicode extended grapheme clusters; SQLite's `length()` counts UTF-16 code units. The schema enforces a sound superset (non-empty, no line breaks, a generous ceiling) and `ItemName.parse` remains the exact rule, which is safe because it is the only constructor.
- **SQL cannot assert `name_normalized = normalizeName(name)`.** A stale normalized value would leave the unique index guarding the wrong string, silently. Registering a custom SQL function to close this was considered and rejected: a `CHECK` or index depending on one makes the database unopenable by anything that has not registered it, including recovery tooling. The mitigation is that exactly one mapper writes both columns, and a test drives every write path and re-derives `normalizeName(name)` for every row.

#### 11.5.3 Migrations
Use Drift's migrator and **generate the schema-migration tests** (`drift_dev schema generate` / `steps`). Two devices will run different versions at times, so every migration ships with a test that a v(N−1) database opens and upgrades correctly. Never edit a released migration; always add a new one.

#### 11.5.4 Archive sweep
`ArchiveSweeper` implements EOD-3. It runs on app start, on foreground, and on a timer that fires at the next boundary while the app runs. It is constructed with a `Clock`, a `TimeZoneRules` and a `SettingsRepository`, reads `endOfDay` and the zone, computes affected tasks with `archiveBoundaryAfter`, and calls the repository to apply them in one transaction.

The repository method it calls takes **every time input as an explicit parameter** — `runArchiveSweep({required DateTime nowUtc, required LocalTime endOfDay, required String zoneId})` — rather than reaching for settings or a clock of its own. That keeps the repository a pure transactional primitive, keeps §11.11's rule that time is always passed in rather than hidden, and lets AC-6 be written without a settings round-trip. Because the boundary is derived from `completedAt` rather than from "when the sweep last ran", a device closed across several boundaries archives correctly on next start with no catch-up loop.

#### 11.5.5 Failure handling

The database is the source of truth (NFR-1), so its failure modes decide whether the app is trustworthy.

- **Cannot open, or the file is corrupt.** Do not crash to a blank screen and do not silently create an empty database over the top, which would present as total data loss. Show a dedicated screen naming the problem, offering `"Restore from backup…"` (§11.6.6) and `"Import snapshot…"` (§11.8), and keep the unreadable file in place, renamed with a timestamp, so nothing is destroyed.
- **Write failures** (disk full, permissions) surface as a `RuleViolation`-style result at the repository boundary, not an exception thrown through the UI. Capture screens report the failure and keep the user's typed text on screen; they never discard input because a write failed.
- **Migration failure** leaves the old database untouched. Take a copy before migrating, restore it on failure, and report which version pair failed.
- **`PRAGMA foreign_keys = ON`** on every connection, since Drift does not enable it by default and the `subtasks` cascade in §11.5.1 depends on it.
- **`PRAGMA journal_mode = WAL`**, which suits the read-heavy list screens alongside occasional writes.

### 11.6 `zen_sync`

#### 11.6.1 Snapshot format
Versioned JSON. Excludes settings (MERGE-3) and events.

```json
{
  "formatVersion": 1,
  "replicaId": "0190f3a1-...",
  "deviceName": "desktop",
  "generatedAt": "2026-09-22T18:30:00.000Z",
  "appVersion": "1.0.0",
  "ideas":      [ { "id": "...", "name": "...", "nameNormalized": "...",
                    "tags": ["..."], "context": "...", "timeframe": "now",
                    "createdAt": "...", "updatedAt": "..." } ],
  "tasks":      [ { "id": "...", "name": "...", "nameNormalized": "...",
                    "tags": ["..."], "description": "...", "status": "todo",
                    "subtasks": [ { "id": "...", "name": "...", "status": "todo",
                                    "createdAt": "...", "updatedAt": "...",
                                    "completedAt": null } ],
                    "createdAt": "...", "updatedAt": "...", "completedAt": null,
                    "isArchived": false, "archivedAt": null,
                    "isDeleted": false, "deletedAt": null,
                    "sourceIdeaId": null, "sourceIdeaCreatedAt": null } ],
  "tombstones": [ { "id": "...", "deletedAt": "...", "reason": "converted" } ]
}
```

Subtask order is the array order. `formatVersion` is checked on read; an unknown higher version is refused with a clear message rather than parsed optimistically.

#### 11.6.2 Transport interface

```dart
abstract interface class SyncTransport {
  String get id;                                        // 'file' | 'lan'
  Future<TransportAvailability> availability();
  Future<List<ReplicaSnapshot>> fetchPeerSnapshots();
  Future<void> publish(ReplicaSnapshot snapshot);
}
```

#### 11.6.3 `FileSnapshotTransport`
Reads and writes snapshots in a directory. The same implementation serves three purposes: manual export/import, backup, and automatic sync through a folder kept in step by Syncthing or a cloud drive.

- Filename: `zen-snapshot-<replicaId>.json`.
- **Writes MUST be atomic**: write `zen-snapshot-<replicaId>.json.tmp-<uuid>`, flush, then rename over the target, so a peer never reads a half-written file.
- Reads: every `zen-snapshot-*.json` in the directory whose replicaId differs from this device's. A file that fails to parse is skipped with a logged warning, never allowed to abort the sync.
- **Windows:** an ordinary directory path chosen with `file_selector`.
- **Android:** a SAF persistable tree URI obtained with `ACTION_OPEN_DOCUMENT_TREE` and retained with `takePersistableUriPermission`. All access goes through `ContentResolver`; raw `dart:io` paths do not work under scoped storage and MUST NOT be attempted. A revoked or missing grant is a normal state: report "sync folder not available", keep the app fully usable offline, and offer to re-pick. **Never block capture on it.**

#### 11.6.4 `LanSyncTransport`
Direct device-to-device sync over the local network, with no third party involved.

**Roles.** The **Windows app is the server**; the **Android app is the client**. This asymmetry is deliberate: Android restricts long-lived background servers, while the desktop is already running. A consequence is that a sync happens only while both apps are open on the same network, and only the phone can initiate. Document this in the UI ("Open Zen on your PC to sync"), and accept it as an MVP limitation.

**Discovery.** The desktop registers `_zen-sync._tcp` on the default port **51789** (configurable) with TXT records `rid` (replicaId), `pv` (protocol version), `dn` (device name). The phone browses for it. mDNS is unreliable on some networks, so **a manual host:port entry is mandatory, not optional**, and the last successful address is remembered and tried first.

**Pairing.** A pre-shared key (PSK), 32 random bytes, established once per device pair and stored on both.

1. Desktop: Settings → "Pair a device" opens a 5-minute pairing window, generates a single-use 6-digit code, and displays both a QR code and the code with the host and port in text.
2. Phone: scans the QR (`mobile_scanner`) or types host, port and code.
3. Phone calls `POST /zen/v1/pair` with the code. The desktop verifies it, returns the PSK and its replicaId, then closes the window. The code is single-use and rate-limited to 5 attempts.
4. Both store `{replicaId, deviceName, host, port, psk}`.

**Transport security.** Requests and responses carry an AES-GCM-256 encrypted body: key = HKDF-SHA256(psk, info `"zen-sync-v1"`), a fresh 12-byte nonce per message, body = `nonce || ciphertext || tag`, `Content-Type: application/octet-stream`. The plaintext JSON includes `sentAt`; a skew greater than 5 minutes is rejected, which blocks replay. This gives confidentiality and integrity without TLS certificate plumbing on a LAN. `/hello` is the only unencrypted endpoint and reveals nothing beyond a device name and protocol version.

**Endpoints.**

| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/zen/v1/hello` | — | plaintext `{protocolVersion, replicaId, deviceName, appVersion}` |
| POST | `/zen/v1/pair` | `{code}` | `{psk, replicaId, deviceName}`; 403 outside the pairing window |
| POST | `/zen/v1/sync` | encrypted client `ReplicaSnapshot` | encrypted **server's own** `ReplicaSnapshot`, as it stood when the request arrived |

**The sync exchange is one round trip, and both ends merge independently.** The client posts its snapshot `C`. The server captures its own snapshot `S`, returns `S` unchanged, and then applies `merge([S, C])` locally in one transaction. The client, on receiving `S`, applies `merge([C, S])` locally.

Both sides therefore run the *same* merge over the *same* pair of inputs, and by MERGE-2 (order-independence) they compute identical results without either having to trust the other's computation. This is why the endpoint returns the server's own snapshot rather than a merged one:

- it keeps `LanSyncTransport` a plain implementation of `fetchPeerSnapshots` (§11.6.2), identical in shape to the file transport, so the orchestrator in §11.6.5 needs no special case;
- each device's local store is only ever written by its own merge, inside its own transaction, after its own pre-merge backup (§11.6.6);
- an interrupted exchange is safe in both directions. If the response is lost, the client did not merge and simply syncs again; the server's merge is idempotent, so the repeat is a no-op.

The server MUST capture `S` before applying its merge, so that the snapshot it returns and the one it merges are the same value.

**Protocol version mismatch** is refused with a clear message on both ends. Never attempt a best-effort merge across versions.

#### 11.6.5 Orchestration
**One orchestrator handles all enabled transports together**, in a single pass. Both transports may be enabled at once (A2), and the merge is n-ary (MERGE-1), so peers from different transports are simply more inputs to one merge rather than a reason to sync twice.

1. Take a **single-flight lock**. A second sync request while one is running returns the running one's future rather than starting a second pass.
2. Build the local `ReplicaSnapshot`.
3. For each **enabled** transport whose `availability()` reports reachable, call `fetchPeerSnapshots()`. Collect the results into one list.
   - A transport that fails — folder revoked, desktop not running, Wi-Fi elsewhere — contributes nothing and is recorded as a per-transport status. **It MUST NOT abort the pass**; the other transport's peers are still merged.
   - If two transports return snapshots for the **same** `replicaId`, keep only the one with the later `generatedAt`. The merge would reconcile duplicates correctly anyway, but discarding the stale copy keeps the merge report readable.
   - If no peers were obtained at all, finish with "nothing to sync" and the per-transport reasons.
4. **Write a pre-merge backup** (§11.6.6).
5. `merge([local, ...peers])`.
6. Apply the result in **one transaction**, by **replacing the dataset wholesale** — delete, then insert — rather than upserting row by row. SQLite evaluates unique indexes per statement and has no deferrable constraints, so a row-by-row application transiently collides whenever two Tasks swap names, and the INV-2 trigger (§11.5.2) can abort on a half-applied task. Deleting first removes both hazards, because nothing old remains when the new rows land. Tombstones are unioned; Settings and events are untouched. Append a `merged` event per merged component, per §9.3 step 7.
7. Call `publish(localSnapshot)` on each enabled transport. For the file transport this writes the snapshot file; for LAN it is a no-op, since the exchange in §11.6.4 already delivered it.
8. Record `lastSyncAt`, the per-transport outcome, and the merge report.

Triggers: manual `"Sync now"` on both platforms; on app foreground when `syncOnForeground`; and on a timer every `syncIntervalMinutes` while the app is open. All are subject to the single-flight lock. **No trigger may block the UI**, and a sync failure is never surfaced as a blocking dialog — capture must remain usable regardless (NFR-1).

#### 11.6.6 Pre-merge backup
Before step 6 of every sync, write the local snapshot to `backups/pre-merge-<ISO8601>.json` in application-private storage. Keep the newest **20** and delete older ones. Settings → "Restore from backup…" lists them by timestamp and restores one, replacing ideas, tasks and tombstones in a single transaction after an explicit confirmation.

This is cheap insurance: the snapshot codec already exists, and a merge bug is the highest-severity failure available in this design (§9.4).

### 11.7 `zen_app`

- **Providers are thin.** They construct dependencies, expose repository streams via `StreamProvider`, and call domain functions. **No rule, guard or validation may live in a provider.** If a decision needs a test, it belongs in `zen_domain`.
- **Lists** (§5.7, §5.8) watch Drift streams, so a completion-circle tap updates the list without manual refresh.
- **Decor** (§3.6.1) is a `DecorPack` data class holding a light and a dark `ColorScheme` plus optional ornament slots, held in a registry keyed by id and injected through a provider. Widgets read the active pack and never name a specific one. The MVP registers exactly one pack, id `Basic`, display name `"Basic"`. Adding "Autumn" later is a new const plus a registry line, which is what DECOR-3 requires.
- **Platform glue:** `file_selector` on Windows and `saf_util` on Android sit behind one `SyncFolderPicker` interface so the screens contain no platform branching.
- **Desktop shortcuts** (HOME-5) are registered with `Shortcuts`/`Actions` at the router level, not per screen.

### 11.8 Sync settings (satisfies SET-4)

These extend §3.6. They are per replica and are never merged.

| Key | Type | Factory default | Meaning |
|---|---|---|---|
| `syncFolderEnabled` | bool | `false` | File transport on/off. |
| `syncFolderLocation` | string \| null | `null` | Directory path (Windows) or SAF tree URI (Android). |
| `syncLanEnabled` | bool | `false` | LAN transport on/off. |
| `syncLanPort` | int | `51789` | Desktop listen port. |
| `syncLanPeers` | list | `[]` | Paired devices: `{replicaId, deviceName, host, port, psk}`. |
| `syncOnForeground` | bool | `true` | Sync when the app comes to the foreground. |
| `syncIntervalMinutes` | int | `15` | Periodic sync while the app is open. `0` disables. |
| `lastSyncAt` | timestamp \| null | `null` | Read-only display. |

The Settings screen gains a `"Sync"` section showing: each transport's toggle and status, the folder picker, the pairing flow, the paired-device list with an unpair action, `"Sync now"`, the last sync time and result, `"Export snapshot…"`, `"Import snapshot…"`, and `"Restore from backup…"`.

### 11.9 Build, packaging and distribution

- **Windows:** `flutter build windows --release`, packaged with Inno Setup into a single installer. The binary is unsigned, so SmartScreen warns on first run; this is accepted rather than solved with a paid certificate.
- **Android:** `flutter build apk --release`, signed with a local keystore and sideloaded. **Back up the keystore and its passwords off-device.** Losing them means a future install cannot upgrade in place and must be uninstalled first, which destroys the local database. This is the one irreversible operational mistake available in this project.
- Play Store distribution is out of scope, so Play's target-API deadlines do not bind. `targetSdk` 36 is nonetheless the right setting for device compatibility.

### 11.10 Continuous integration

`.github/workflows/ci.yaml`, on every push and pull request:

1. `dart analyze` across all four packages, warnings as errors.
2. `dart test` in `zen_domain` and `zen_sync`.
3. `flutter test` in `zen_data` and `zen_app`.
4. `dart format --set-exit-if-changed`.

On a tag: build the Windows installer and the release APK, and attach both to a GitHub release.

### 11.11 Coding conventions

- `flutter_lints` plus: `prefer_final_locals`, `avoid_dynamic_calls`, `require_trailing_commas`, `unawaited_futures`, and a ban on `DateTime.now()` outside `zen_app` (enforced with a custom lint or a CI grep).
- Every public type carries a doc comment. Where a type or function implements a spec rule, its doc comment names the requirement ID: `/// §4.2, STATUS-2. …`.
- Tests are named for the requirement they cover: `test('SUB-8: adding a subtask to a Done task is rejected', …)`.
- No `part`/`part of` except where Drift's generator requires it.
- Immutable domain classes: `final` fields, `const` constructors where possible, hand-written `copyWith`, `==` and `hashCode`. No `freezed`.
- Files stay under roughly 400 lines; screens that grow past it split out widgets.

### 11.12 Testing requirements

Beyond NFR-5:

1. **Example tests** for every rule in §4, every invariant in §3.7, and every acceptance scenario in §10, each referencing its ID.
2. **Property tests for the merge**, with hand-written generators over random snapshots and a **seeded** `Random` so failures reproduce. Assert:
   - *order-independence*: `merge([a, b]) == merge([b, a])` (AC-19);
   - *idempotence*: `merge([merge([a, b])]) == merge([a, b])`;
   - *invariant preservation*: the output satisfies every rule in §3.7 for any valid inputs;
   - *no resurrection*: no tombstoned id appears in the output (AC-17).
3. **A convergence simulation.** Two in-memory replicas, a randomly generated script of user operations (create, edit, complete, delete, convert, archive) interleaved with random sync points. After a final mutual sync, assert the replicas are field-for-field identical and all invariants hold. Run it over many seeds in CI. This is the test most likely to find what §9.4 has not anticipated.
4. **EoD tests** at exact boundary instants, including both DST transitions and the spring-forward case where the configured time does not exist.
5. **Migration tests**, generated by Drift, for every schema version.
6. **Widget tests** for the flows in §5.1, and **golden tests** for the three completion-circle states in TODO-3 plus their disabled variants, since those are visual specifications.

### 11.13 Implementation order for the agent

Each milestone ends with green tests, a commit and an updated `DECISIONS.md`. Do not begin a milestone before the previous one is green.

**M4 and M5 are executed together, in one session, with a commit at each.** Their IDs stay distinct so that `DECISIONS.md` and the commit history keep referring to the same things, but the boundary between them is not a place to stop and hand over. It cuts through shared files rather than between them:

- §5.3 and §5.4 say the Add and Edit screens are **the same screens in different modes**. Splitting means building `SCR-IDEA-FORM` and `SCR-TASK-FORM`, then re-opening both to add a mode, a panel and two actions — rework on the two largest files in the layer.
- Three affordances on M4's own screens point at M5's: ROW-3's row tap opens the Edit screen, TODO-6's link opens Archived Tasks, and REVIEW-1's top bar carries a search icon and a settings gear. Splitting means writing stubs and then deleting them.
- Archived Tasks and Search are mostly §5.6's row rendering re-used, so they are cheap once the lists exist, and expensive to retrofit if the row widget was built without them in view.
- M4 alone is demoable but not *usable*: nothing can be edited or deleted. The usual reason to cut a milestone here — shipping a usable increment sooner — does not apply.

Sequence the work by **shared component** rather than by user journey:

1. **Foundation** — theme and the `Basic` decor pack, the router, the provider wiring, the row rendering of §5.6, the completion circle of TODO-3.
2. **The two form screens**, with all five modes at once (Add, Edit; Add, Edit, Convert).
3. **The two lists**, To Do and Ideas. *Commit: M4.*
4. **Archived Tasks, Search and Settings**, which reuse step 1's rendering. *Commit: M5.*

| # | Milestone | Definition of done |
|---|---|---|
| **M0** | Repository skeleton: four packages, path dependencies, lints, CI, `.fvmrc`, README | `dart analyze` and an empty test suite pass in CI |
| **M1** | `zen_domain` model and rules: entities, value objects, Clock, §4 rules, EoD calculator | Every rule in §4 and every invariant in §3.7 covered by tests. **AC-1, AC-2, AC-3, AC-7** pass as pure domain tests. No Flutter or IO dependency in the package |
| **M2** | `zen_domain` merge: `NameUnionMergeStrategy` per §9.3 | **AC-13 through AC-19** pass; property tests (§11.12, item 2) pass over many seeds |
| **M3** | `zen_data`: Drift schema, constraints, partial unique indexes, repositories, `ConversionService`, archive sweeper | **AC-6, AC-8, AC-9, AC-10** pass against a real in-memory database, AC-8/9/10 exercising the partial unique index rather than an application check. Migration test harness in place |
| **M4** | `zen_app` capture path: Home, Add Idea, Add Task, To Do list, Ideas list, completion circles, `"Make Task"` | **AC-1, AC-2, AC-3, AC-7** pass again as widget tests; **AC-11, AC-12** pass via the `"Make Task"` entry point. The app runs on both platforms |
| **M5** | Remaining screens: Edit screens, Advanced details, Archived Tasks, Search, Settings, decor and theme | §5 fully implemented. **AC-4, AC-5** pass on the Edit Task screen; **AC-10** passes through the Archived Tasks UI; **AC-11** also passes via the Edit Idea entry point. Golden tests for the TODO-3 circle states |
| **M6** | `zen_sync` core: snapshot codec, orchestrator, pre-merge backup, `FileSnapshotTransport` including Android SAF | Two databases converge through a shared directory; convergence simulation (§11.12, item 3) passes over many seeds. **The Android SAF path needs a real device and is verified by hand** (§11.13.1) |
| **M7** | `LanSyncTransport`: server, client, discovery, pairing, crypto | Protocol, crypto and merge-exchange logic covered by automated tests against a loopback server. **End-to-end verification needs a real phone and PC on one Wi-Fi network**, including the manual host:port fallback with mDNS disabled (§11.13.1) |
| **M8** | Packaging: Inno Setup installer, signed APK, tagged release workflow | **Requires a Windows machine and an Android device** (§11.13.1). Both artifacts install and run on clean machines |

#### 11.13.1 Where each milestone can be verified

The implementing agent may be running in a **Linux container with no Windows machine, no Android device and no second host on the network**. Most of this project is verifiable there; some of it is not, and the agent MUST NOT claim a milestone is done on the strength of code that has never run on the platform it targets.

| Verifiable headlessly in a Linux container | Requires the owner's real hardware |
|---|---|
| M0–M2 entirely (`dart test`, pure Dart) | The Android SAF folder path in M6 — scoped storage, `ACTION_OPEN_DOCUMENT_TREE`, persisted grants, and grant revocation behave only on a real device |
| M3 (Drift runs on Linux; use an in-memory or temp-file database) | M7 end-to-end: mDNS discovery across two hosts, Windows Firewall prompts, Wi-Fi drop-outs, real QR scanning |
| M4–M5 widget and golden tests (`flutter test` is headless) | **Launching the app** on Windows and on an Android device — M4's "runs on both platforms" is not established by widget tests, and this is the first milestone where that applies |
| M6 merge, orchestrator, backup, and the file transport against ordinary directories | Cold-start latency against NFR-2, which is a claim about a mid-range Android phone |
| The convergence simulation (§11.12, item 3), which is pure Dart and needs no device | M8 entirely: the Windows build needs Windows plus the VS 2022 C++ toolchain; the signed APK needs a keystore and a device to install on |
| | Anything described as "feels fast" or "looks right" |

**Instructions for the agent.**
- Build everything in the left column and prove it with tests before touching the right column.
- For work in the right column, write the code and its automated tests as far as the environment allows — a loopback HTTP server exercises the LAN protocol, crypto and merge exchange without a second device — then **stop and hand the owner a written manual-verification checklist** naming each step, the expected result, and what to report back. Do not mark the milestone done until they confirm.
- Where a platform cannot be exercised at all, say so plainly in the milestone's summary. An untested Windows build is an untested Windows build.

**Standing instructions.**
- Where this document specifies exact user-facing copy, reproduce it verbatim.
- Where it is silent, choose the simplest behaviour consistent with it and record the choice in `DECISIONS.md` (§0.1). Do not invent product behaviour.
- Prefer deleting code to adding configuration.
- If a requirement in §3–§10 appears to conflict with §11, §3–§10 wins; report the conflict rather than resolving it silently.

---

## 12. Declined additions

These were considered and left out. They are recorded so that a future reader knows they were decided rather than overlooked. **The implementer MUST NOT add them.**

| # | Addition | Decision |
|---|---|---|
| Q31 | **Demotion**: converting a Task back into an Idea. ZTD's Simplify habit is largely about pruning commitments, and today the only way down is Delete. | **Not in the MVP.** Conversion stays one-way, Idea → Task. |
| Q32 | **Bulk actions**: multi-select on the Ideas list for bulk delete or bulk timeframe change, for periodic pruning of a long `Distant` list. | **Not in the MVP.** One at a time, through each Idea's Edit screen. Revisit if pruning becomes a chore in daily use. |
| Q33 | **Export / import** of the whole dataset to a file, as a backup independent of sync. | **Included**, at no extra cost: `FileSnapshotTransport` (§11.6.3) already reads and writes exactly this format, so `"Export snapshot…"` and `"Import snapshot…"` in §11.8 are that transport pointed at a one-off location. |

---

## 13. Resolved decisions

Every question raised during drafting, with the owner's resolution. All are folded into the body of this document; this table exists so that a future reader can see what was decided deliberately rather than by default.

### 13.1 Architecture (A1–A6)

| # | Resolution |
|---|---|
| A1 | **Flutter.** Chosen over Kotlin Multiplatform for identical rendering on both platforms, a native Windows binary rather than a bundled JVM, and the Drift database layer. §11.0. |
| A2 | **Both sync transports in the MVP**: file-snapshot *and* LAN. §11.6.3, §11.6.4. |
| A3 | **LAN sync is the primary route** (architecture doc option C): direct device-to-device over the local network, with no third-party software and nothing leaving the network. The file transport remains for backup, manual export and folder-based sync. |
| A4 | **Code generation for Drift only.** No `freezed`, no `riverpod_generator`. Domain classes are hand-written, per NFR-4. |
| A5 | **Pre-merge backup included.** Every sync writes a restorable snapshot before applying a merge, and the newest 20 are kept. §11.6.6. |
| A6 | **Git from the first commit**, with GitHub Actions CI. §11.10. |

### 13.2 Functional (Q1–Q30)

| # | Resolution |
|---|---|
| Q1 | No MITs, Big Rocks or weekly-review features, ever. Principle 1.2.3. |
| Q2 | `Distant` is an ordinary collapsible group, not search-only. "Groups shown by default" and "groups expanded by default" are one setting. Search also exists. |
| Q3 | Tombstones are used. They match by **id only**, never by name, so a deleted name can be used again. |
| Q4 | Merge: smallest-id selection, id-or-name matching, longest text, tag union, most urgent timeframe, Done > Blocked > Todo. Subtasks are **unioned**, with matching subtasks taking the highest-precedence status. |
| Q5 | To Do list: oldest first; no sinking of Done/Blocked; manual ordering deferred. |
| Q6 | A Done Task's subtask **statuses** are locked. No auto-reopen and no auto-complete of parents. |
| Q7 | Explicit Save, with a discard prompt. |
| Q8 | Name cap: 1000 characters. |
| Q9 | Names are single-line; Enter submits. |
| Q10 | Context and description are plain text. |
| Q11 | Idea→Task lineage fields and an internal event log are both kept. |
| Q12 | Subtasks: min 1 character, 2 lines in the list, reorderable, hard-deleted. |
| Q13 | Tags: no whitespace, any other character, max 32. |
| Q14 | Ids and timestamps are shown in an "Advanced details" section of the Edit screens. |
| Q15 | Settings are per device and are never merged. |
| Q16 | Two independent axes: `theme` (System/Light/Dark) and `decor` (skin packs, each with light and dark variants). |
| Q17 | Destructive actions ask for confirmation, controlled by a setting. |
| Q18 | Soft-deleted Tasks are restorable via Search. |
| Q19 | "Archived tasks" link at the bottom of the To Do list; Unarchive returns a Task to Todo. |
| Q20 | Home "Add" splits in place into Idea/Task; desktop keyboard shortcuts exist. |
| Q21 | Subtasks are added only from the Edit Task screen. The To Do list has no add-subtask button. |
| Q22 | Names are reserved by active Items only. Restoring or unarchiving into a name collision is prohibited outright, with the NAME-9 message. Subtask names need not be unique. |
| Q23 | Merge name-matching applies to active Items only; archived and deleted Tasks match by id. |
| Q24 | Locking a Done Task affects **status only**. The subtask list stays editable. |
| Q25 | Context / description cap: 10,000 characters. |
| Q26 | See Q21. |
| Q27 | The axis is called `decor`; the default pack is `Basic`. |
| Q28 | Advanced details: read-only, showing ids, all lifecycle timestamps, and conversion lineage for Tasks. |
| Q29 | Each Idea row carries a trailing `"Make Task"` button, spaced to prevent mis-taps (ROW-5). It opens the pre-filled Create Task screen; the Idea is consumed only on confirm; cancel returns to the Ideas tab. |
| Q30 | Adding a subtask to a `Done` Task is forbidden outright. The affordance exists only for `Todo` and `Blocked` Tasks. |

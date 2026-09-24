# Review items

Bugs and improvements raised by the owner against the M4/M5 build, after
`MANUAL_VERIFICATION.md` was completed on 2026-09-24. Each is recorded here as
reported; the reasoning behind whatever was done about it goes in
`REVIEW_DECISIONS.md`, and the commit that resolves it names the item.

Items are numbered in the order they were raised and are never renumbered.

| # | Summary | Status |
|---|---|---|
| B1 | No way back to Home after an add, save or convert | **Awaiting owner's decision** on the proposed fix |
| B2 | Only the text opens the Edit screen; the rest of the row is dead | **Done** |
| B3 | Add Task / Add Idea buttons at the foot of each list | **Blocked on B1** |
| B4 | Timeframe headers do not read as headers | **Done** |
| B5 | `"Make Task"` crowds the Idea text | **Awaiting owner's choice** of option |

---

## B1 — No way back to Home after an add, save or convert

**Reported.** On both Windows and Android, once the app navigates to the
To Do or Ideas list after adding an Item, there is no way to get Home. Pressing
`Review` from Home gives a working back arrow; arriving at the same screen by
adding an Idea or Task, by saving an edit, or by creating a Task from an Idea
does not. There should always be a way Home from the Review screen.

**Scope.** Affects every path that lands on Review other than Home ▸ Review:
`IDEAFORM-4` (after add), `IDEAFORM-5` (after save or delete), `TASKFORM-8`
(after add, save, convert or delete) and `CONVERT-5` (after cancel). On Android
the symptom is worse than a missing arrow: the system Back button exits the app.

**Specification bearing.** NAV-1 — "Android's system Back and an on-screen back
arrow (both platforms) return to the previous screen." §5.1's map likewise ends
every branch with `Back ▸ previous screen`.

## B2 — Only the text opens the Edit screen

**Reported.** ROW-3 was implemented literally: the Edit screen opens when the
name or tag *text* is tapped. With small text that is a fiddly target. The whole
list entry should open it — everything right of the completion circle on a Task
row, everything left of the `"Make Task"` button on an Idea row.

**Specification bearing.** ROW-3 says "Tapping or clicking anywhere on the name
or tag text opens the item's Edit screen", and ROW-5 requires the trailing
button not to overlap that region. Widening the region to fill the row is
consistent with both — ROW-3 names a minimum, and the trailing button stays
outside it.

## B3 — Add Task / Add Idea at the foot of each list

**Reported.** The To Do list should carry an `"Add Task"` button below the last
Task and **above** the `"Archived tasks"` link. The Ideas list should carry an
`"Add Idea"` button below every timeframe group — so with all four collapsed it
sits directly under `Distant`. Both should behave exactly as the equivalent
button on the Home screen, returning to Review whether the Item was added or
backed away from, and B1's guarantee must still hold from there.

**Specification bearing.** This one needs the owner's attention, because
**REVIEW-4 currently forbids it**: *"The Review screen is for reviewing,
completing and processing what already exists. It offers no way to author a new
Item from blank: no add-task button, no add-idea button, no add-subtask button.
Capture happens on the Home screen."* Implementing B3 as reported means amending
REVIEW-4 in `ZEN_SPEC.md`. See `REVIEW_DECISIONS.md`.

## B4 — Timeframe headers do not read as headers

**Reported.** In the Ideas list the four timeframe headers should be *slightly
larger* and *slightly fainter*, so they separate from the Ideas beneath them and
let the Ideas themselves carry more weight.

**Specification bearing.** None. IDEAS-1 fixes the headers' text and order but
says nothing about their type treatment.

## B5 — `"Make Task"` crowds the Idea text

**Reported.** The `"Make Task"` button occupies roughly the last 35% of an Idea
row's width on Android, so Idea names wrap at about the 60–65% mark. The wrap
point should be nearer 75–80%.

**Specification bearing.** IDEAS-6 fixes the label as the exact string
`"Make Task"`, and ROW-5 fixes the geometry: a touch target of at least
48 × 48 dp and at least 16 dp of clear space between the button and the text
block. Those two floors together put a hard ceiling on how much can be
recovered. See `REVIEW_DECISIONS.md` for the options and what each is worth.

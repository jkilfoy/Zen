# Review decisions

Why each item in `REVIEW.md` was resolved the way it was. Same contract as
`DECISIONS.md`: entries are append-only, and where the specification is silent
the simplest behaviour consistent with it is chosen and recorded rather than
invented.

Entries are keyed `R-<item>-<n>`.

---

## B2 — the row tap region

**R-B2-1 — The tap region fills the row's text column, and the subtask rows are
inside it.**
The cause was one line: the column holding the name and tags used
`CrossAxisAlignment.start`, so the `InkWell` wrapped around it was sized to the
*glyphs* rather than to the space available. A short name gave a short target.
Moving the `InkWell` outside that column and stretching it makes it fill the
`Expanded`, which is exactly "right of the completion circle" on a Task row and
"left of the `Make Task` button" on an Idea row, because the leading control and
the trailing action both sit outside the `Expanded`.

The subtask rows are inside the region too, so tapping a subtask's name opens the
parent Task — it is the only Edit screen a subtask has (SUB-9), so there is
nothing else the tap could sensibly mean. Their completion circles keep working
because a nested `InkResponse` wins the gesture arena against the `InkWell`
above it; `todo_list_test.dart` pins that, since it is the one thing about this
change that could regress silently.

ROW-3 is not weakened. It says tapping the name or tag text opens the Edit
screen, which is a minimum and still true. ROW-5's "MUST NOT overlap the
row-opens-Edit tap region" now means something stronger than it did: the test
measures the region's own rectangle rather than where the glyphs stop, which is
what that clause was always about.

## B4 — the timeframe headers

**R-B4-1 — 18sp in `onSurfaceVariant`.**
The headers were `titleMedium`, which is 16sp — the same size as the `bodyLarge`
an Idea's name uses. Identical size is why they read as list items rather than
as structure. They are now 18sp in the muted colour.

The step is deliberately small. `titleLarge` is 22sp and would make the four
headers shout over the Ideas they label, which is the opposite of B4's intent:
the point is for the Ideas to carry more weight, not the headers. The value
lives in one function, `groupHeaderStyle`, so it is a single edit if 18 turns
out to be wrong on a real screen.

---

## B1 — no way Home after an add, save or convert

**R-B1-1 — Every route is nested under Home.**
The route table declared all ten routes as flat siblings. `push` stacks a page
on what is there; `go` does not — it rebuilds the stack from the hierarchy the
target matches. Flat, `/review` matched one route and produced a stack of
exactly one page, so Home was discarded: no back arrow, and on Android the
system Back fell through to the launcher, which NAV-1 forbids. `go` was still
the right verb at all six call sites — `push` would leave the finished form
underneath for Back to walk into — so the fix was the table, not the verbs.

The nine routes are now children of `/`. Child paths carry no leading slash;
every location string `Routes` produces is unchanged, so nothing outside
`router.dart` moved. `go('/review')` matches `/` and `review` and builds
`[Home, Review]`.

**Two risks were raised against this before it was implemented. Both were
settled by test rather than by argument.**

*Does `push` append the whole matched branch?* If it did, pushing an Edit screen
from Review would give `[Home, Review, Home, Edit]` — which displays correctly,
so only a count would catch it. It does not: go_router 18.0.1 pushes the leaf
alone. `navigation_test.dart` asserts `inStack<HomeScreen>() == 1` after the
push, and walks Back down to Home one page at a time, so a future version
changing this semantics fails loudly rather than leaking pages.

*Does `go` bypass NAV-1's discard prompt?* It cannot, because the prompt does
not hang off `go`. `PopScope` intercepts the *pop attempt*; the `go` runs only
after `confirmDiscard` has returned true. The six save-path `go`s have nothing
to discard by definition. CONVERT-5's cancel does — and it was already covered
by `convert_test.dart`'s AC-12. Probing it, however, turned up a different
defect in the same place: see R-B1-2.

**R-B1-2 — Convert mode always intercepts the pop.**
Found while checking the question above, not reported. `PopScope` was
configured `canPop: !_dirty`, so a form the user had *not* edited popped
natively — returning to whatever pushed it. From `"Make Task"` that is the Ideas
tab and looks right. From Edit Idea (IDEAFORM-5) it is the Edit Idea screen,
which puts the user back inside the Idea they just declined to convert.

CONVERT-5 is explicit: "The app returns to the **Ideas tab**, from either entry
point." Convert mode now sets `canPop: false` unconditionally and routes both
cases — pristine and edited — through the same exit, prompting only when there
is something to discard. The Ideas-tab destination no longer depends on which
screen happened to push the form.

Two tests cover it, one per entry point, plus a third for the edited form. The
pristine-from-Edit-Idea case is the one that was broken, and it failed on first
run before the fix, which is the only real evidence a test was worth writing.

---

## B3 — an add button on each Review tab

**R-B3-1 — Built to REVIEW-4 as rewritten in v1.9, not to the report.**
B3 asked for a button at the foot of each list — above TODO-6's link on the To
Do tab, below `Distant` on the Ideas tab. The owner's rewrite specifies a
**floating action button** in the bottom-right instead. Where the report and the
specification disagree the specification wins, so that is what was built. The
FAB also sidesteps what the report's placement would have cost: a button in the
list flow scrolls away exactly when a long list makes it most useful, and on the
Ideas tab it would have had to sit below four collapsible groups whose combined
height changes as they open.

The button is `push`ed, not `go`ne to. REVIEW-4 requires save *and* cancel to
return to "the tab the button was pressed from", and pushing keeps this very
`ReviewScreen` underneath — with its tab selection and its scroll position
intact — so cancel needs no navigation logic of its own. The save paths land
back on the right tab through IDEAFORM-4 and TASKFORM-8, which already did that.

`ReviewScreen.fabClearance` is 88: REVIEW-4 requires "at least the button's
height plus its margin", which for a Material FAB is 56 + 16 = 72. The tabs
apply it as bottom padding, because the requirement is about the *list* not
being covered, and the lists are what own their padding.

The FAB is rebuilt from a `TabController` listener rather than only on tab
change, so it swaps during a swipe rather than snapping at the end of one.

---

## B5 — `"Make Task"` crowds the Idea text

**R-B5-1 — Option 4: a `TextButton`, 8 dp padding, `labelMedium`.**
Chosen by the owner from the options costed below. The width came out of the
chrome rather than the words, because IDEAS-6 fixes the label as the exact
string `"Make Task"` and §11.13's standing instruction is to reproduce specified
copy verbatim. Dropping the outline as well as the padding leaves the row
quieter, which is the other half of what B4 was after on the same screen.

ROW-5's floors are unchanged and still asserted: a 48 × 48 touch target and
16 dp of clear space. Those two put a hard ceiling of roughly 84% on the wrap
point no matter what the button says, so the measured target was the top of the
owner's stated range rather than beyond it. `convert_test.dart` asserts the text
region is now more than 70% of the row and that both floors hold — a range
rather than a pixel count, since the exact width depends on the font the
platform resolves.

### The options as costed

| # | Change | Approx. row width | Wrap at | Keeps IDEAS-6? |
|---|---|---|---|---|
| 1 | Horizontal padding 24 → 8 | ~108 dp | ~74% | Yes |
| 2 | Label `labelLarge` → `labelMedium` | ~126 dp | ~69% | Yes |
| 3 | 1 + 2 together | ~94 dp | ~77% | Yes |
| **4** | **3, plus `TextButton` — drops the outline** | **~94 dp** | **~77%** | **Yes** |
| 5 | Icon only | ~64 dp | ~84% | No |
| 6 | Reword to `"Task"` | ~80 dp | ~80% | No |

5 and 6 were not taken and would need IDEAS-6 amended. An icon also costs
discoverability on the one affordance that turns an Idea into a Task, and no
tooltip recovers that on a touch screen, where nothing hovers.

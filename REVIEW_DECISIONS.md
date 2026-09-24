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

**Not implemented — proposal below, awaiting the owner's decision.**

### Why it happens

The route table in `router.dart` declares all ten routes as **flat siblings**.
Nothing is nested under `/`.

That matters because of how the two navigation verbs differ. `push` puts a page
on top of the existing stack — Home ▸ Review gives `[Home, Review]`, so the
`AppBar` finds something to pop and draws a back arrow. `go` does not push: it
*rebuilds the whole stack* from the route hierarchy that the target location
matches. With flat routes, `/review` matches exactly one route, so the stack it
produces is `[Review]` and nothing else. Home is discarded.

Every path B1 names ends in `go`:

| Call site | Rule |
|---|---|
| `idea_form_screen.dart:145` | IDEAFORM-4, after add |
| `idea_form_screen.dart:162` | IDEAFORM-5, after delete |
| `task_form_screen.dart:250` | TASKFORM-8, after add, save or convert |
| `task_form_screen.dart:298` | TASKFORM-8, after delete |
| `task_form_screen.dart:317` | ARCH-3 / SEARCH-3, after unarchive or restore |
| `task_form_screen.dart:536` | CONVERT-5, after cancel |

`go` was the right call and still is — the alternative, `push`, would leave the
just-completed form underneath, so Back would return the user to the Add screen
they had already finished with. The defect is not the verb. It is that the route
table gives `go` nothing to rebuild *onto*.

This also explains why the symptom is worse on Android than on Windows: with a
single-entry stack there is nothing to pop, so the system Back button falls
through to the launcher and the app exits — which NAV-1 forbids in as many
words.

### Proposed fix

Nest every route under `/` as a child route, changing only the route table:

```dart
GoRoute(
  path: '/',
  builder: … HomeScreen …,
  routes: <RouteBase>[
    GoRoute(path: 'review',            …),
    GoRoute(path: 'idea/new',          …),
    GoRoute(path: 'idea/:id',          …),
    GoRoute(path: 'task/new',          …),
    GoRoute(path: 'task/new/from/:id', …),
    GoRoute(path: 'task/:id',          …),
    GoRoute(path: 'archive',           …),
    GoRoute(path: 'search',            …),
    GoRoute(path: 'settings',          …),
  ],
),
```

Child paths lose their leading `/`; every location string stays exactly as it is
(`/review`, `/task/new`), so nothing outside this file changes and `Routes`
keeps its current shape.

`go('/review')` then matches `/` **and** `review`, and builds `[Home, Review]`.
The back arrow appears, Android's Back returns to Home, and the finished form is
still gone from the stack. Every other `go` gains Home beneath it for the same
reason.

**What I like about it:** it is a change to one file, it needs no new widget and
no special-casing per screen, and it makes the structure say what §5.1's
navigation map already draws — Home is the root, everything hangs off it. A
"Home" button bolted onto the Review app bar would paper over the same defect
while leaving Android's Back still exiting the app.

**What to weigh:** deep links and `go` calls to an *Edit* screen would also get
`[Home, Edit]` rather than `[Home, Review, Edit]`, so Back from an Edit screen
reached that way lands Home rather than on the list. Nothing in the app does
that today — Edit screens are always reached with `push` from a list, which
keeps the list underneath — so it is a latent property rather than a live
behaviour change. The alternative, nesting the Edit routes under `review`
instead of under `/`, buys a more precise stack at the cost of a route table
that no longer mirrors §5.1's flat map.

**Tests it would come with:** one per entry point in the table above, asserting
that Review can pop and that what it pops to is Home. These are the cases that
regressed unnoticed, so they should be pinned rather than eyeballed.

---

## B3 — Add Task / Add Idea at the foot of each list

**Not implemented — blocked, and not only on B1.**

Two things need settling first.

**REVIEW-4 currently forbids exactly this.** §5.5: *"The Review screen is for
reviewing, completing and processing what already exists. It offers no way to
author a new Item from blank: no add-task button, no add-idea button, no
add-subtask button. Capture happens on the Home screen."* The rule then goes out
of its way to explain why `"Make Task"` is the one permitted exception —
"which processes an existing Idea rather than authoring a new Item". That is a
deliberate product decision with a stated rationale, not an oversight, and
`todo_list_test.dart` has a test named for it that B3 will turn red.

I am not going to quietly override a numbered requirement. B3 is a change to
`ZEN_SPEC.md` — REVIEW-4 amended or removed, with the version bumped — and then
an implementation. Which way you want that written is yours to decide; it is
your specification.

**It also depends on B1.** B3's acceptance says the user must still be able to
reach Home after adding or backing out, which is precisely what B1 fixes. The
buttons themselves are a few lines and need nothing from B1, but their stated
behaviour is not satisfiable until B1 lands, so shipping them first would mean
claiming an item done while half of it is false.

Once REVIEW-4 is settled and B1 is agreed, this is a small change:
`push(Routes.addTask)` from the To Do tab and `push(Routes.addIdea)` from the
Ideas tab. Both already return to Review on save through the existing
IDEAFORM-4 / TASKFORM-8 paths, and `push` means backing out returns to Review
too — so no new navigation logic is needed, only the two buttons.

---

## B5 — `"Make Task"` crowds the Idea text

**Not implemented — options below, awaiting the owner's choice.**

### Where the width goes

The button is an `OutlinedButton` with Material 3's default 24 dp horizontal
padding on each side, its label at `labelLarge` (14sp), inside a 48 × 48 minimum
touch target, with ROW-5's 16 dp gap before it. On your phone's 411 dp width
that comes to roughly 140 dp, or **34%** — which matches the 35% you measured.

**Two floors cannot move**, both from ROW-5: the touch target is at least
48 × 48 dp, and the gap is at least 16 dp. 64 dp of 411 is 15.6%, so **the wrap
point can never exceed about 84%** while ROW-5 stands. 75% is comfortably
reachable; 80% is reachable only by making the button itself no wider than its
touch target, which means dropping the words.

### Options

| # | Change | Approx. row width | Wrap at | Keeps IDEAS-6? |
|---|---|---|---|---|
| 1 | Horizontal padding 24 → 8 | ~108 dp | ~74% | Yes |
| 2 | Label `labelLarge` → `labelMedium` (14 → 12sp) | ~126 dp | ~69% | Yes |
| 3 | **1 + 2 together** | ~94 dp | **~77%** | Yes |
| 4 | 3, plus `TextButton` instead of `OutlinedButton` — drops the outline, lighter on the eye | ~94 dp | ~77% | Yes |
| 5 | Icon only, e.g. `→`, with the tooltip and accessibility label kept | ~64 dp | ~84% | **No** |
| 6 | Reword to `"Task"` or `"+ Task"` | ~80 dp | ~80% | **No** |

**My recommendation is 3**, or 4 if you want the row quieter still. It reaches
the bottom of your stated range without touching the specification, and the
button keeps a real label, which matters for a control whose whole job is to be
found by someone processing a list.

**5 and 6 need a spec change.** IDEAS-6 fixes the label as the exact string
`"Make Task"`, and the standing instruction in §11.13 is to reproduce specified
copy verbatim. An icon also costs discoverability on the one affordance that
turns an Idea into a Task — the central verb of the product — and no tooltip
recovers that on a touch screen, where nothing hovers. If you want 80%+, say so
and I will amend IDEAS-6 rather than work around it.

# CLAUDE.md — Project Constitution (Mobile App)

This file is read by the agent at the start of every session. It is not a
one-time prompt — it is the permanent rulebook. Follow it even if a
specific instruction in a chat message doesn't repeat these rules; they
still apply.

**This is a fresh project**, started from zero. An earlier prototype
exists in a separate folder — it may be referenced for UX flow/behavior
("build this screen with the same layout as the old prototype's version"),
but its code, colors, and structure are not the foundation for this build.
Nothing about it should be assumed unless explicitly pointed to.

## 1. What this project is

[Fill in: 2-3 sentences describing the app. Example: "Kurdistan Explorer
is a travel app for discovering nature spots, hotels, car rentals, tours,
and flights in the Kurdistan region."]

This repo is the **customer-facing mobile app only** (iOS + Android). The
admin/data-entry panel is a **separate project** — see
"Project structure" below.

## 2. Tech stack (locked — do not introduce alternatives without asking)

- **Frontend:** Flutter (latest stable), Dart null-safety
- **Backend:** Firebase
  - **Firestore** — primary database
  - **Firebase Authentication** — user login/signup
  - **Firebase Storage** — images (hotel/car/tour photos, user avatars)
  - **Cloud Functions** — anything that must run server-side
- **State management:** [Fill in once decided — e.g. Riverpod, Provider,
  Bloc. Pick ONE and do not mix approaches across screens.]

## 3. Project structure — two separate projects, on purpose

The admin/data-entry web panel is **not** built inside this repo. It's a
separate Flutter Web project (see the companion doc set for it). This is
deliberate, not an oversight:
- Admin code can never end up inside the mobile app binary this way —
  a stronger guarantee than hiding it in the UI.
- Each project deploys independently (admin via Firebase Hosting anytime;
  mobile app on the App Store/Play Store release cycle).
- Both projects connect to the **same Firebase project** — that's what
  makes data entered via the admin panel instantly available here.

`DATA_MODEL.md`, `SECURITY.md`, and `SEED_DATA.md` are kept as **identical
copies** in both repos. If one changes, copy the change to the other
immediately — don't let them drift. (If keeping them in sync manually
becomes a real burden later, that's the point to consider extracting a
shared Dart package — not before.)

## 4. Design — authoritative files

The complete, approved UI source of truth is the following three-file set:

1. `DESIGN_SYSTEM F.md` — shared structure, geometry, components, spacing,
   glass behavior, responsive behavior, states, navigation UI, and RTL rules.
2. `DESIGN_LIGHT F.md` — Light-theme values and colors.
3. `DESIGN_DARK F.md` — Dark-theme values and colors.

These are the only authoritative design specifications for existing and
future screens. Do not merge older design rules into them, and do not modify
them unless the user explicitly requests it.

### Rule: Light mode and dark mode are built together, not sequentially
Every color must be a **semantic token** (e.g. `colorScheme.surface`,
`colorScheme.onSurface`) with both a light and dark value defined in
the three authoritative design files — never a raw hardcoded color in a widget. Support for
both modes should work automatically via Flutter's `theme:` / `darkTheme:`
/ `themeMode:` on `MaterialApp`, not through if/else branches sprinkled
through screen code. If a token doesn't have both a light and dark value
yet, ask before building with it, rather than guessing one and leaving
the other to be patched in later.

### Rule: How each page's design actually gets handed over
Design happens outside Claude Code, screen by screen, in a separate
design tool. For each individual page, expect **all three of these
together** before building starts:
1. **A reference screenshot/image** of that exact screen — layout,
   colors, text, buttons, shapes, all visible.
2. **A full functional description** of what every button/element does —
   not just what it looks like, but what happens when it's tapped.
3. **The global palette/fonts/shapes files** (`DESIGN_SYSTEM F.md`,
   `DESIGN_LIGHT F.md`, and `DESIGN_DARK F.md`, already
   filled in) for anything not fully visible in the screenshot (exact hex
   codes, font family, spacing scale).

Do not start writing code for a page until all three are present. If any
one is missing or ambiguous (e.g. a button's action isn't described, or a
color in the screenshot doesn't match the authoritative design files),
ask before building — don't guess a plausible-looking behavior or color.

Once built, a page must visually match its reference screenshot as
closely as Flutter allows, using only tokens already defined in
the authoritative design files — never a new color/font/shape invented on the spot to
match something slightly off in the screenshot. If the screenshot and
the authoritative design files conflict, flag the conflict and ask which one is right
rather than silently picking one.

## 5. Non-negotiable working rules

### Rule: One page at a time
Only build the screen I explicitly name. When it's done:
1. Summarize what you built in plain language.
2. Tell me exactly what's still a placeholder / not wired up.
3. Stop and wait for me to say "approved, next" (or give corrections)
   before touching anything else — even if it's next on the roadmap.

Do not build ahead. Do not "helpfully" wire up screens I haven't asked for
yet, even if it seems efficient.

### Rule: Design system is locked once it exists
Once the three authoritative design files have real values (light + dark) and I've approved
them, every screen must be built using only those values. Do not
introduce a new color, font size, spacing value, or component style
without first proposing a change to `DESIGN_SYSTEM F.md` and getting my
approval.

### Rule: Read before you build
At the start of every session, and before starting any new screen, read
(in this order):
1. `CLAUDE.md` (this file)
2. `DESIGN_SYSTEM F.md`
3. `DATA_MODEL.md`
4. `SECURITY.md`
5. `ROADMAP.md` — confirm which page we're on
6. `PROGRESS.md` — confirm what's already been approved, so you don't
   redo or contradict earlier decisions

### Rule: Security is part of "done," not cleanup
Every rule in `SECURITY.md` applies as you build, not as a pass at the
end. A screen that reads/writes Firestore or Storage is not approved
until the matching security rules exist and have been tested (try
accessing data you shouldn't be able to — as an unauthenticated user, and
as a non-admin user — and confirm it's actually denied, not just hidden
in the UI).

**Any screen involving online payments is held to `SECURITY.md` section
5 specifically** — the highest-priority section in that file. Do not
build payment UI, checkout flow, or anything charge-related without
reading that section first.

### Rule: One example, seeded to Firestore, per page
Every page that reads from Firestore must have at least **one real
example document** added to the relevant collection(s) before that page
is marked approved — not a hardcoded Dart list standing in for it.

Process for each page:
1. Build the screen's Firestore read logic (query, model mapping,
   loading/error states).
2. Add exactly one example document to the collection(s) it reads —
   directly in the Firestore console or a seed script for now, since the
   admin panel (separate project) may not have that entity's form built
   yet.
3. Run the app and confirm that example shows up correctly on the real
   screen — not a mock/preview.
4. Only then mark the page approved.

Keep a running list of what's been seeded in `SEED_DATA.md`.

### Rule: Ask before assuming
If a screen's spec is ambiguous, ask a specific clarifying question
before writing code. Don't silently pick a default for anything that
affects data shape, navigation flow, or Firebase read/write patterns —
those are expensive to change later. Small visual details are fine to
pick a reasonable default for and mention.

### Rule: Every screen that touches data must respect the schema
Never invent a new Firestore field or collection on the fly. If a screen
needs a field that doesn't exist in `DATA_MODEL.md`, propose the
addition, update the doc (in both repos), and only then write the code.

## 6. Documentation the agent must keep updated

- `PROGRESS.md` — append an entry every time a page is approved.
- `DATA_MODEL.md` — update whenever a schema change is approved (and copy
  the change to the admin panel repo).
- `DESIGN_SYSTEM F.md` — update only when the user explicitly requests a
  design-system change.
- `SEED_DATA.md` — update whenever a new example document is seeded.
- `SECURITY.md` — update whenever a new rule pattern or checklist item is
  needed (and copy the change to the admin panel repo).

Never let these docs go stale.

## 7. Definition of "done" for a screen

A screen is not done until:
- It matches the approved design system (both light and dark mode).
- It reads/writes real Firestore data where the spec calls for real data
  (not hardcoded placeholder lists), unless explicitly agreed otherwise.
- Matching Firestore/Storage security rules exist and have been tested.
- At least one real example document has been seeded to Firestore and is
  confirmed rendering correctly on the actual running screen.
- Loading and empty states are handled (not just the happy path).
- Errors from Firebase calls are caught and shown to the user, not just
  thrown.
- It's been summarized to me and approved.

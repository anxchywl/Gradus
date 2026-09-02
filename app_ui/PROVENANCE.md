# Provenance

This package is a **deliberate one-time fork**, not a vendored copy kept in
sync. It is maintained here and diverges on purpose.

| Field | Value |
|---|---|
| Source repository | `github.com/anxchywl/EventsBot` |
| Source path | `app_ui/` |
| Source commit | `1fab5842be774844fe3f1d96f4a7ec0c37260d99` |
| Forked on | 2026-09-06 |

## Why a fork rather than a shared package

The same kit was previously vendored into a second project as a copy that was
supposed to stay untouched. It diverged anyway: seven files, one extra
dependency and a dropped README, with no version marker and nothing that would
detect the drift. A shared package would need a versioned artifact, a release
process and an upgrade path for every consumer — infrastructure that does not
exist. A fork is what was actually happening; this file makes it honest.

The package **name** and the token class names are kept identical to the other
two projects, so a future consolidation is a merge rather than a rewrite.

## What was removed at fork time

- Fintech, jobs and gamification components: bank card, job card, home card,
  user card, premium dialog, reward toast, level ring.
- Auth-flow inputs belonging to a host application: password, OTP and phone
  fields. Identity is the superapp's concern, not this project's.
- The calendar widgets, which no screen here needs.
- The parallel `HomeSpacing` scale and the `HomeRadius` duplicate. Radius lives
  in `AppSpacing` and there is one scale.
- The `textColor` / `textColorDark` backward-compatibility aliases. Two names
  for one token guarantee inconsistent usage.
- The `balanceCardBackground` and `serviceBackground` product tokens.
- `HomeShadows` became `AppShadows`; its `studentCard` preset became `raised`.

## What has changed since the fork

- `AppProgressBar` and `AppStepProgress` painted their unfilled track with
  `AppColors.surfaceDark` in the dark theme. That is the colour a dark card is
  already painted with, so the track was invisible on any surface that used it -
  every consumer, not just this one. Both now use a translucent white wash, which
  reads on any dark surface. `test/token_parity_test.dart` fails if either
  reverts.

- Overflow menus were a bare `PopupMenuButton` at every call site, so each one
  took Material's defaults - square corners, its own surface and type scale -
  and no two of them agreed on item structure. `AppMenu` gives every consumer
  one surface, one item height, an icon per choice, and destructive choices
  grouped last behind a divider, with a disabled choice's reason on a second
  line rather than permanently on the screen. `test/app_menu_test.dart` pins
  the grouping and the disabled behaviour.

- `AppColors.error` was being used as label text. It is a fill colour: at 14pt
  it reaches 3.6:1 on white and 4.4:1 on the dark surface, both short of the
  4.5:1 a body label needs, so the most consequential item in a menu was the
  hardest one to read. `errorText` and `errorTextDark` are the readable pair;
  `error` keeps its job as a fill. `test/token_parity_test.dart` computes both
  ratios and fails under 4.5:1.

- The comments are gone. The kit arrived with the commentary style of its
  origin: 635 `///` lines and 248 line comments, nearly all of them restating
  the declaration underneath (`/// Pure white` over `white`) or drawing a
  section banner. `AGENTS.md` here allows a comment only where the *why* is
  non-obvious, and 19 lines survive it - the contrast figures behind
  `errorText`, why the progress track is a white wash, why `AppMenu` exists.
  Nothing executable changed. This is the divergence a future consolidation
  has to take a position on, since the sibling projects still carry the
  original commentary over the same code.

## Rules

Nothing product-specific goes in here. A change belongs in this package only
when it would benefit every consumer — an accessibility gap, a bug affecting
all of them. `test/token_parity_test.dart` pins the exported token surface: if
you add or remove a token, that test fails and the diff is reviewable.

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

## Rules

Nothing product-specific goes in here. A change belongs in this package only
when it would benefit every consumer — an accessibility gap, a bug affecting
all of them. `test/token_parity_test.dart` pins the exported token surface: if
you add or remove a token, that test fails and the diff is reviewable.

# Agents

Rules for anyone writing code in this repository, human or model. They are not
suggestions: a change that breaks one is wrong even if it works. Read this file
first, then the one document that owns the area you are touching.

**Sources of truth:**

- Product behaviour and what is undecided: `docs/PRODUCT.md`
- Structure, layers, security boundaries, the control inventory, limitations and
  the threat model: `docs/ARCHITECTURE.md`
- Endpoints and wire shapes: `docs/API.md`
- Setup, checks, secrets, builds and deployment: `docs/INFRASTRUCTURE.md`
- This file: coding rules

Each document owns its subject once. If a change makes one of them wrong, fix it
in the same commit rather than adding the correction somewhere else.

Before reporting any change complete, run `./scripts/verify.sh` and report its
actual result. It runs everything CI runs.

## Packages

```text
app_ui/       shared presentation kit, forked once from the Student Events project
gradus_feature/  the embeddable feature: domain, application, data, presentation
gradus_app/      standalone host: MaterialApp, theme, locale, lifecycle
backend/      FastAPI service
```

Dependencies point one way: `gradus_app -> gradus_feature -> app_ui`. Never the other,
and never a non-presentational dependency in `app_ui`.

Nothing GPA-specific goes into `app_ui`. Change it only when the fix belongs
there rather than here - an accessibility gap, a bug affecting every consumer -
and keep it generic. `app_ui/test/token_parity_test.dart` fails if a product
concept or a second token scale appears.

There is no separate `gradus_ui` package. If product widgets outgrow
`gradus_feature/lib/src/presentation`, extract one then, not before.

## Layers

`gradus_feature/lib/src` and `backend/app` are each split, and a test enforces the
split:

- `domain/` - pure. No Flutter, no framework, no ORM, no networking, no storage.
- `application/` - controllers and use cases. Depends on domain interfaces only.
- `data/` (client) and `infrastructure/` (backend) - the only layers that know
  wire and storage shapes.
- `presentation/` (client) and `api/` (backend) - screens and routers. Never
  reach past their neighbour.

Wiring happens once: `GradusScope` on the client, `create_app` and `dependencies.py`
on the backend. Business logic does not live in a widget or a router. A widget
that decides what something means is a controller in the wrong place.

## Security

The client is never trusted to assert identity, role, ownership, verification,
permissions or whether validation passed. Reject those fields if they arrive in
a request. Role comes from the resolved credential and is rechecked at every
endpoint that needs it.

`APP_ENV` is authoritative and defaults to production. Every development
mechanism is refused at startup when `APP_ENV=production`. Never key such a
guard on a log level, a debug flag or the presence of a variable.

No build that leaves a development machine may enable development access or
carry a credential. A `--dart-define` is compiled into the binary and is
recoverable from it; it is not a secret once shipped.
`backend/tests/unit/test_ci_policy.py` fails the build if a workflow does either.

## General

- Write all code, comments, documentation and commit messages in English.
- Keep changes minimal - only touch what the task requires.
- Do not add features, abstractions, dependencies or error handling that was
  not asked for.
- Do not create a new file when editing an existing one would do.
- Do not leave debug prints, temporary variables or commented-out code.
- Never use emoji anywhere: UI, copy, source, comments, tests, docs or commits.

## Code style

- Follow the existing patterns in the file you are editing.
- Fully async backend, and blocking work goes off the event loop. There is no
  database and no ORM: if one is ever added, sessions are passed as arguments
  and never created inside a service.
- Prefer early returns over deep nesting; keep functions small.
- Do not catch broadly; catch the specific failure you can handle, and never
  swallow one silently. A control that fails open is a control that is absent.
- No `TextStyle()`, raw `Color` or raw spacing number in feature code - use
  `AppTextStyles`, `AppColors`, `AppSpacing`. Radius lives in `AppSpacing`.
- No literal user-facing text. Every string comes from the ARB files, in all
  three languages.
- `lower_snake_case.dart` files, `UpperCamelCase` types, `snake_case` Python.
  Short but descriptive: `GradusController`, not `Mgr` or `GradusDataHandler`.
- Nothing hardcoded that belongs in `backend/app/config.py`, CORS origins
  included.

## Comments

Write a comment only when the **why** is non-obvious - a hidden constraint, a
workaround, or something that would surprise a reader. All lowercase, no
punctuation at the end, one line, intent rather than implementation. No
docstrings: types and good names are enough.

```dart
// bad
// this method loads the courses from the repository

// good
// host may not register our delegate, so the feature scopes its own
```

## Tests

- `flutter_test` and `pytest` only. Hand-written fakes, no mocking package.
- A new domain rule lands with the test that proves it.
- Every icon-only control asserts a non-empty semantics label.
- Prefer a test that asserts something is *absent* where absence is the point.
- Keep coverage above the floor, but never write a test to move a number.

## Commits

Conventional prefix, lowercase, imperative: `feat:`, `fix:`, `docs:`, `chore:`,
`style:`, `refactor:`, `test:`. Optional scope, as in
`fix(editor): keep draft on validation failure`. No period at the end, no issue
numbers unless asked, no trailers.

**Subject line only.** The reasoning behind a change belongs in the document
that owns the subject, where it can be kept correct; a commit body repeats it
somewhere nobody looks and nobody updates. Write a body only when the change is
genuinely unreadable without one, and keep it to a line or two.

Prefer one commit that covers a change to several that each cover a piece of it.

## What not to do

- Do not put GPA concepts into `app_ui/`.
- Do not refactor code unrelated to the current task.
- Do not add logging unless asked.
- Do not describe deferred or simulated behaviour as if it were implemented.
- Do not commit a secret, real student data, a local path or build output.
- If a change makes a document wrong, fix the document in the same commit.

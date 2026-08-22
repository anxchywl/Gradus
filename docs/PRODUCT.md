# GPA Product

**Partly specified.** A student can enter courses by hand and see a
credit-weighted average, stored on their own device. Everything about importing
data is still open — see [decisions/0001](./decisions/0001-course-sync-and-moodle.md).

Nothing below is a decision. It records what is known, what is assumed, and what
has to be answered before the first feature endpoint or screen is written. Do
not treat an assumption here as a rule, and do not implement one without asking.

## What is known

A GPA tool for university students, mounted inside the university superapp as
one feature among several. The superapp owns identity; this feature never signs
anyone in.

Implemented: add, edit and delete a course with a title, credit weight and
optional grade; a credit-weighted average that excludes pass/fail from the
average while still counting it as attempted; device-local persistence
namespaced per account.

## What is assumed, pending confirmation

- A student enters or imports courses, each with a title, a credit weight and a
  grade, and sees a credit-weighted average.
- Some grades sit on a transcript without counting toward the average - pass,
  fail-without-penalty, transfer credit. `Course.weighsOnGpa` models this.
- An operator role exists, because the superapp distinguishes one. What an
  operator can actually do here is undecided.

## Open decisions

Each of these changes what gets built. None should be guessed.

1. **Which grade scale.** `FourPointScale` in `gpa_feature/lib/src/domain/grade.dart`
   is an example so the domain is testable. The real letter-to-points table, and
   whether it varies by faculty or intake year, is an institutional rule.
2. **Where course data comes from.** Student-entered, imported from the
   registrar, or both. This decides whether a backend is needed at all, and
   whether grades are ever writable by the student.
3. **Whether anything is stored server-side.** If a GPA is only ever computed
   from data the student typed on one device, the backend reduces to nothing.
   The current backend is a security spine with no persistence for exactly this
   reason.
4. **What an operator does.** Read aggregate statistics, correct a scale,
   nothing at all.
5. **Which GPA definitions are needed.** Term, cumulative, major-only, projected.
   Each is a different calculation over the same records.
6. **Whether projections are in scope** - "what do I need this term to reach X".
7. **How the superapp mounts this** - a tab or a route - which decides whether
   the feature keeps its own navigation.

## What is deliberately not here

Anything about implementation. Layers and boundaries are in
[ARCHITECTURE.md](./ARCHITECTURE.md), controls in [SECURITY.md](./SECURITY.md).

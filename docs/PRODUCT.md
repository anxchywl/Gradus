# GPA Product

**Partly specified.** A student can organise courses into semesters, grade each
course from assignments they enter by hand, and see a credit-weighted average,
all stored on their own device. Everything about importing data is still open -
see [decisions/0001](./decisions/0001-course-sync-and-moodle.md).

Nothing below is a decision. It records what is known, what is assumed, and what
has to be answered before the first feature endpoint or screen is written. Do
not treat an assumption here as a rule, and do not implement one without asking.

## What is known

A GPA tool for university students, mounted inside the university superapp as
one feature among several. The superapp owns identity; this feature never signs
anyone in.

Implemented: semesters, each holding courses; add, edit and delete a course with
a code, title, credit weight, grading mode, an include-in-GPA switch and an
optional letter chosen by hand; add, edit and delete assignments inside a course,
each with a weight, a maximum score and a score that stays empty until the work
is marked; a credit-weighted average that excludes pass/fail from the average
while still counting it as attempted; semester and cumulative averages reported
separately; an all-semesters view grouped by term; device-local persistence
namespaced per account, carrying forward data written before semesters existed.

### How a course reaches a grade

One rule, in `domain/course_grade.dart`, used by every screen and by the average:

- An assignment scores `earned / maximum x 100`, and contributes
  `percentage x weight / 100` toward the final course grade.
- The current grade averages **only marked work**: the denominator is the weight
  that has actually been marked. An unmarked assignment is never a zero, and a
  course with nothing marked shows `-` rather than `0%`.
- Weights must be above 0, must not exceed 100 each, and must not total more than
  100 for a course. Totals are compared as integer hundredths of a percent, so
  33.34 + 33.33 + 33.33 is accepted as exactly 100.
- A setup totalling less than 100 is incomplete, and the shortfall is named on
  screen rather than absorbed silently.
- `Max possible` is everything already banked plus full marks on every point of
  weight not yet marked, and carries its assumption next to it.
- Marked work decides the letter; a letter chosen by hand stands when nothing is
  marked. Which one is in use is shown, never inferred.
- Pass/fail and courses switched out of the GPA are described below.

Averages display to two decimals and percentages to one. Nothing rounds before
it is displayed.

## What is assumed, pending confirmation

- A student enters or imports courses, each with a title, a credit weight and a
  grade, and sees a credit-weighted average.
- Some grades sit on a transcript without counting toward the average - pass,
  fail-without-penalty, transfer credit. `Course.isEligibleForGpa` models what
  the course allows and `CourseGrade.weighsOnGpa` what the resolved grade does.
  A pass/fail course counts as attempted credit and never toward the average; a
  course switched out of the GPA counts toward neither.
- An operator role exists, because the superapp distinguishes one. What an
  operator can actually do here is undecided.

## Open decisions

Each of these changes what gets built. None should be guessed.

1. **Which grade scale.** `FourPointScale` in `gpa_feature/lib/src/domain/grade.dart`
   is an example so the domain is testable. The real letter-to-points table, and
   whether it varies by faculty or intake year, is an institutional rule. Its
   percentage cutoffs (`GradeScale.bands`) are an example on exactly the same
   terms, and they are what turns an assignment average into a letter - so every
   letter derived from marked work inherits that caveat, and so does the GPA
   computed from it. `GradeScale` is an interface for this reason: a scale that
   declines to map percentages returns no letter, and the feature shows the
   percentage alone rather than claiming a grade.
2. **Where course data comes from.** Student-entered, imported from the
   registrar, or both. This decides whether a backend is needed at all, and
   whether grades are ever writable by the student.
3. **Whether anything is stored server-side.** If a GPA is only ever computed
   from data the student typed on one device, the backend reduces to nothing.
   The current backend is a security spine with no persistence for exactly this
   reason.
4. **What an operator does.** Read aggregate statistics, correct a scale,
   nothing at all.
5. **Which GPA definitions are needed.** Term and cumulative are implemented and
   shown apart. Major-only is not, because nothing records what a major is.
6. **Whether projections are in scope** - "what do I need this term to reach X".
   Not implemented, and deliberately: a projection that assumes the current
   average continues over the remaining weight is arithmetically identical to the
   current average, so shipping it as a second figure would restate one number as
   though it were a forecast. `Max possible` is a bound, not a prediction, and
   says so on screen. A target-driven projection - "what must I score to reach
   3.5" - is a different calculation and still undecided.
7. **How the superapp mounts this** - a tab or a route - which decides whether
   the feature keeps its own navigation.

## What is deliberately not here

Anything about implementation. Layers and boundaries are in
[ARCHITECTURE.md](./ARCHITECTURE.md), controls in [SECURITY.md](./SECURITY.md).

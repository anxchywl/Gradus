# Gradus Product

**Partly specified.** A student can organise courses into semesters, grade each
course from assignments they enter by hand or fill a course in from its syllabus,
and see a credit-weighted average, all stored on their own device. Reading a
syllabus is decided and built; importing from the registrar or from Moodle is
still open decision 2 below.

Nothing below is a decision. It records what is known, what is assumed, and what
has to be answered before the first feature endpoint or screen is written. Do
not treat an assumption here as a rule, and do not implement one without asking.

## What is known

A GPA tool for university students, running on its own. It is packaged so it
can be mounted inside a larger host application later; if it is, that host owns
identity and this feature still never signs anyone in.

Implemented: semesters, each holding courses; add, edit and delete a course with
a code, title, credit weight and an optional letter chosen by hand; add, edit and
delete assignments inside a course, each with a weight, a maximum score and a
score that stays empty until the work is marked; a credit-weighted average that
counts a letter the scale gives no points to as attempted credit only; semester
and cumulative averages reported separately; an all-semesters view grouped by
term; device-local persistence namespaced per account, carrying forward data
written before semesters existed and data written before the host knew who the
student was.

### Filling a course in from its syllabus

A student adding a course can pick its syllabus instead of typing it, wherever
the host that mounts the feature can issue a token the backend verifies. No host
does yet, so today this is reachable from a development build only, and every
other build simply does not offer it. The file is read on the server and comes
back as a proposal: course code, title,
credit value with the unit as printed, and one assignment per row of the
assessment table with its weight. Nothing is applied on its own - the fields are
filled in for the student to check, and nothing is stored until Save. The
assignments it found are not listed in the form; they are reviewed on the course
once it is saved, where each can be edited or removed like any other.

- The letter grade stays unset and every score stays unmarked. Marks are the
  student's to enter; the import only sets up what to enter them against.
- Each imported assignment is out of 100, because a syllabus states weights and
  never a maximum score.
- Credits are reported in the unit the syllabus printed, usually ECTS, and are
  never converted. What an ECTS credit is worth locally is an institutional rule
  and is not one of ours to invent.
- A field the syllabus did not state is left empty and named on screen. Syllabi
  share no layout, so a partial fill is normal rather than a failure.
- Weights are kept as they were read. A set totalling over 100 is not kept at
  all: the course is saved without it and the card says why. Scaling the
  weights, or trimming an entry to fit, would be a guess.
- The grading table in a syllabus is not imported. Which scale applies is open
  decision 1 below.

**Why a model reads it rather than a parser.** Four real syllabi share no
template: three sit on the NU Course Specification Form, one per term of the
same course, and disagree about the assessment table's columns and numbering
anyway, and the fourth is an instructor's own document that never states credits
at all and carries four other assessment-shaped tables - a weekly schedule, a
table of contents, a percentage-range grading table, and policy prose about late
penalties. A rule parser finds the wrong table before the right one, and fails
worst on exactly the document that needs it most. The same course changes shape again between
instructors and between terms, so there is no stable layout to parse even within
one course code.

So the file is read on the server by a model. Which model is configuration
rather than code - the provider and the model id are both settings, and four
providers are supported. The default is free to run within its provider's rate
limits, and reads the five cases in `backend/evals/` exactly: every field and
every assessment row, on repeated runs. That is a real result on a small
sample rather than a guarantee - four documents across two layouts, one of them
read again as a Word conversion of itself - so a
document unlike them is still an open question, and about a cent per import buys
the answer for any candidate that replaces it.

The document is untrusted input in a prompt, and is treated as such: quoted
between markers, declared as data rather than instructions, with no tools on the
call and nothing the model returns allowed to select an identifier, a storage
key, a semester or an endpoint. Every value comes back sanitised and
range-checked on both sides. `pypdf` extracts the text on the server and only
the text is sent - sending the PDF itself costs several times more for no gain.
A syllabus may be a PDF or a Word document, since instructors hand out both.
A scan cannot be imported whichever it arrives as: there is no OCR, and adding
one would be a new decision. Rows are taken as the table states them, so a single
20% row whose notes read "5% each" stays one assignment rather than becoming
four the table never listed.

Two things follow from spending money per call. Extraction is rate-limited per
account and fails closed, and an idempotency key is required so a retried upload
is not paid for twice.

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
  fail-without-penalty, transfer credit. The scale marks such a letter with
  `Grade.countsTowardGpa`, and `CourseGrade.weighsOnGpa` carries it through: the
  credit is attempted, the quality points are not awarded.
- An operator role exists in the authentication seam, distinct from a student.
  What an operator can actually do here is undecided.

## Open decisions

Each of these changes what gets built. None should be guessed.

1. **Whether a course may state its own percentage cutoffs.** The scale is
   settled, but the cutoffs under it are faculty discretion, so a syllabus is
   entitled to print a different table. Today one table applies to every course
   and a student whose course differs has to correct the letter by hand.
2. **Where course data comes from.** Student-entered, read from a syllabus,
   imported from the registrar, pulled from Moodle, or some combination. This
   decides whether a backend is needed at all, and whether grades are ever
   writable by the student.

   Registrar sync is feasible and already solved elsewhere: NU's own Nuspace
   project fetches the public course catalog with no credentials, and, with a
   student's login, reads current enrolment as JSON and parses the unofficial
   transcript PDF - which carries the whole academic history with official
   grade points already in it. Moodle is untouched ground by comparison; its
   web services may not even be enabled, and letter thresholds there are set per
   course. Whether any of this belongs here at all depends on whether Gradus
   replaces the existing Nuspace Courses tab, embeds in it, or stands apart.

   Four rules hold whenever it is built, and are not open:

   - Do not scrape a registrar or an LMS where an API or a JSON endpoint exists.
   - Never store a registrar password, and never hold an LMS token server-side
     if it can live on the device. A student handing over a university password
     is a cost no amount of care at the server removes, so the UI says so
     plainly.
   - Never disable TLS verification, whatever a reference implementation does.
   - Extraction proposes, the student confirms, and the confirmation is what
     persists.

   Automated access to university systems with a student's own credentials is
   also an acceptable-use question for NU IT before it is a technical one.
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
7. **How a host would mount this** - a tab or a route - which decides whether
   the feature keeps its own navigation. The chrome half of that is settled:
   `GradusChrome.host` drops the feature's app bar and scaffold for a host that
   has its own. What is still open is navigation, because a host that mounts the
   feature in a tab and a host that pushes it as a route want the course detail
   reached differently.

## The grade scale

Settled, and taken from NU rather than invented. The quality points are the
Common Grading Scale the registrar publishes for all undergraduate programs:
`A` 4.00, `A-` 3.67, `B+` 3.33, `B` 3.00, `B-` 2.67, `C+` 2.33, `C` 2.00,
`C-` 1.67, `D+` 1.33, `D` 1.00, `F` 0.00. There is no `A+`, `D-`, `F+` or `F-`,
and the scale refuses those letters rather than inventing a value for them.

The percentage cutoffs are the ones the Course Specification Form prints, and
every syllabus in `backend/evals/` agrees on them across three terms and two
schools: 95, 90, 85, 80, 75, 70, 65, 60, 55, 50, and everything below is `F`.
They open on multiples of five, which a test pins.

Two things about that are worth stating rather than assuming. The cutoffs are
faculty discretion, not a university-wide rule - NU's own wording is "as
determined by the faculty" - so a course whose syllabus prints a different table
is entitled to, and the student would have to correct the letter by hand. And a
`P` earns no quality points but is not a zero: it leaves the average untouched
rather than dragging it down, because a course that does not weigh on the GPA is
absent from the divisor as well as the total.

### Grades that are not marks

NU also issues `P`, `AU`, `I`, `IP`, `W` and `AW`, and all six are here. None
carries quality points, so none moves the average. They divide on the second
question, which is whether the credit was attempted at all:

| Grade | In the average | In attempted credit |
|---|---|---|
| `P` | No | **Yes** - a pass is credit earned |
| `AU` `I` `IP` `W` `AW` | No | No - audited, unfinished or withdrawn |

That distinction is why `Grade` carries two flags rather than one. A pass sits
in the credits a student attempted and leaves the average untouched; a
withdrawal sits in neither, so a dropped course does not quietly inflate the
credits a transcript claims.

**A grade of this kind stands over marked work.** The percentage bands only ever
yield a letter that earns points, so a letter earning none was chosen
deliberately and states something no score can: a student who sat a midterm and
then withdrew has a `W`, not the `C+` the midterm came to. The percentage is
still shown; it just no longer decides the letter.

`GradeScale` stays an interface. A scale that declines to map percentages
returns no letter, and the feature then shows the percentage alone rather than
claiming a grade it cannot justify.

## What is deliberately not here

Anything about implementation. Layers, boundaries and the control inventory are
in [ARCHITECTURE.md](./ARCHITECTURE.md).

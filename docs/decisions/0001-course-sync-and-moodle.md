# 0001 — Course sync from the registrar, and the Moodle grade feature

Status: **audit only, nothing implemented.** Date: 2026-09-06.

Records what was learned from Nuspace, whether automatic course sync is
feasible, and how the Moodle feature would be built when it is wanted.

## Sources examined

| Source | Revision |
|---|---|
| `github.com/ulanpy/nuspace` (MIT) | `bc65ede0d648a095a32efec7118da281aefe3787`, 2026-08-30 |
| `nuspace.kz` Courses tab | observed in screenshots, 2026-09-06 |
| `moodle.nu.edu.kz` | observed in screenshots, 2026-09-06 |

## 1. What Nuspace already is

Nuspace is the superapp. It already ships a Courses section with My Courses,
Statistics, Schedule Builder and Degree Audit, a GPA figure with Projected and
Max possible, and a Sync button reading "Sync your schedule to add registered
courses".

**This project overlaps it.** Decide deliberately whether Gradus is a
replacement for that tab, a component inside it, or a separate thing. Building
a second GPA calculator beside an existing one is only justified if it does
something the existing one does not.

### Conventions worth adopting

Verified in `AGENTS.md` and `backend/README.md`:

- **Modules are bounded contexts.** `modules/<name>/` owns its API, service,
  repository, ORM models, schemas and dependencies.
- **Strict layering:** `api.py -> service.py -> repository.py -> DB`. No SQL in
  dependencies, no business logic in the API layer.
- **Cross-module calls go through `Protocol` ports** declared in the *calling*
  module's `interfaces.py`, implemented in `dependencies.py`. Ports are named
  for the role they play for the caller — `CourseCatalogLookup`,
  `StudentScheduleRegistrar` — never after the providing class.
- **Transactions commit at the request boundary.** Repositories only
  `add`/`flush`/`refresh`, never `commit`, so one scenario is one transaction.
- **Never mutate a loaded ORM object to shape a response.** The end-of-request
  commit would persist it. Build a DTO and mutate that.
- Frontend features are `features/<name>/{api,components,hooks,pages,utils}`.
- Conventional Commits; `uv`, `ruff`, `black` at line length 100, `pytest`.

The port-naming rule and the do-not-mutate-for-display rule are the two most
transferable ideas. Our layering already matches; the vocabulary differs
(`infrastructure/` rather than `repository.py`) and there is no reason to change.

### Where we deliberately differ

Nuspace has no `permissions:` block, does not pin actions to commit SHAs, and
has no secret or dependency scanning in CI. Our `test_ci_policy.py` enforces all
three. Do not relax ours to match theirs.

## 2. Automatic course sync — feasible, and already solved

**Yes, and the reference implementation is MIT-licensed and readable.** Nuspace
does it in two unrelated ways, and both matter.

### 2a. Course catalog — public, no credentials

`registrar/schedule_discovery.py:29-45` fetches
`registrar.nu.edu.kz/course-schedules` and `/course-requirements`, regexes out
`(Season Year ... termid=N)`, and takes the newest by `(year, season)`. Schedule
PDFs are then downloaded and parsed (`parsers/schedule_pdf_parser.py`) into a
catalog, refreshed by a scheduled Cloud Run job.

Useful to us for course codes, titles and credit values. No credentials, no
per-student data.

### 2b. The student's own courses — authenticated

`registrar/clients/registrar_client.py`:

1. `login()` POSTs `name`/`pass` to `/index.php?q=user/login` (Drupal), keeping
   the session cookie.
2. `fetch_schedule()` GETs `/my-registrar/personal-schedule/json` — **current
   enrolment as JSON**, no HTML parsing.
3. `fetch_unofficial_transcript_pdf()` downloads the transcript PDF.

**`degree_audit/transcript_parser.py` is the answer to "and the old ones too".**
It reads the transcript with `pypdf` and regexes out semester headers, then per
course: code, title, letter grade, credits and grade points, including transfer
credit (`T - XXX 000`) and `PASS`/`FAIL`. That single PDF is the entire academic
history with the official grade points already in it — far better than
reconstructing a scale.

### What this means for us

The whole feature is: collect credentials once per sync, call two endpoints,
parse one PDF, store courses. It is a few hundred lines, not a research project.

**Three things in their implementation must not be copied.**

1. **`verify_ssl: bool = False` (`registrar_client.py:32`), and `verify=False`
   in `schedule_discovery.py:34`.** TLS verification is disabled on a request
   that POSTs a real university password. That is a credential-interception
   hole, not a convenience. If the registrar's certificate chain is genuinely
   broken, pin its certificate; do not disable verification.
2. **A hardcoded Drupal `form_build_id` (`registrar_client.py:60`).** These are
   per-form tokens. It works until the registrar regenerates it, then every
   sync fails at once. Fetch the login page and read the current token.
3. **Credentials transiting a third-party server.** To Nuspace's credit they are
   *never persisted* — no password column exists in any ORM model, and they are
   passed per call. That is the right choice and we should match it. But the
   user is still handing their university password to an application, and no
   amount of care at the server removes that. Say so plainly in the UI.

**Recommended posture:** transient credentials, never stored, never logged,
TLS verified, and a written statement in `docs/SECURITY.md` that a sync request
carries a university password through our backend. If NU ever exposes OAuth or
an API token for the registrar, drop this immediately.

## 3. The Moodle feature — audit

Nuspace has **zero** Moodle integration (`grep -rni moodle` over the whole repo
returns nothing). This is new ground.

Goal as stated: open a course's Moodle page, download the syllabus, read the
grades, fill in what is known, work out each item's weight toward the final
grade, and skip anything missing.

### Do not scrape it

Moodle ships a REST web-service API. Scraping the HTML of a system that has an
API is more fragile, slower, and much harder to defend if anyone asks what the
traffic is.

- `POST /login/token.php` with username, password and `service=moodle_mobile_app`
  returns a token. **Confidence: high** — this is the standard Moodle mobile
  flow.
- `GET|POST /webservice/rest/server.php?wstoken=…&wsfunction=…&moodlewsrestformat=json`
  is the call surface. Functions relevant here:
  `core_webservice_get_site_info` (who am I, what is enabled),
  `core_enrol_get_users_courses` (enrolled courses),
  `gradereport_user_get_grade_items` (grade items for a user in a course),
  `core_course_get_contents` (sections, modules, file URLs — the syllabus).
  **Confidence: high on the function names, unverified on the exact response
  fields.** I could not confirm the field names for weight and percentage from
  a public source, and they vary by Moodle version.

**First step before any design work — one command, run it yourself.** I did not
probe `moodle.nu.edu.kz`, because automated requests against a university system
are not mine to make on your behalf:

```bash
curl -s "https://moodle.nu.edu.kz/login/token.php" \
  -d "username=YOUR_USER" -d "password=YOUR_PASS" -d "service=moodle_mobile_app"
```

A token means the whole feature is an API integration. An error means mobile
web services are disabled, and the honest answer is that the feature becomes
HTML scraping with a much worse risk profile — at which point reconsider it.

If a token comes back, dump the shape you actually get before designing to it:

```bash
curl -s "https://moodle.nu.edu.kz/webservice/rest/server.php" \
  -d "wstoken=TOKEN" -d "moodlewsrestformat=json" \
  -d "wsfunction=gradereport_user_get_grade_items" -d "courseid=COURSE_ID"
```

### The hard part is not the API

Fetching grade items is easy. Turning them into "your projected final grade" is
where this breaks, and the difficulty is in this order:

1. **Weights are only as good as the instructor's gradebook.** Moodle supports
   several aggregation strategies (natural, weighted mean, simple weighted
   mean), and many instructors never configure weights at all — the screenshot
   of ASC 200 shows a quiz with range 0–15 and a letter grade, and an external
   tool with no grade. If weights are absent, the syllabus is the only source,
   and it is prose.
2. **Syllabus parsing is the least reliable component in the system.** A PDF
   saying "Homework 20%, Midterm 30%, Final 50%" has no fixed layout. This is
   the one place an LLM extraction step is justified — and it must produce a
   *proposal the student confirms*, never a silently applied number.
3. **Partial-term projection is a judgement, not a fact.** With 40% of the
   weight graded, "your current grade" can mean the average of what is graded,
   or that plus assuming the rest goes perfectly, or plus assuming it matches
   current performance. Nuspace's UI already shows this three ways — GPA,
   Projected, Max possible — which is the right answer: show the assumption,
   do not pick one silently.
4. **Letter-grade thresholds are per course.** 87 is a B+ in one course and an
   A- in another.

### Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Credentials or a long-lived Moodle token stored server-side | **High** | A Moodle token is equivalent to account access and does not expire on its own. Prefer holding it on the device only. If it must reach the server, encrypt at rest with a per-user key and support revocation. |
| Acceptable-use policy | **High** | Automated access to NU systems may breach IT policy regardless of it being your own account. Check before building, not after. This is a conversation with NU IT, not a technical control. |
| Wrong projected grade shown as fact | **High** | Never display a computed projection without the assumption beside it and the inputs it used. A student dropping a course over a wrong number is real harm. |
| Syllabus extraction silently wrong | Medium | Extraction proposes, the student confirms. Store the confirmed weights, not the extracted ones. |
| Rate limiting / load on university infrastructure | Medium | On-demand per student only. No polling, no crawling every course for every user. |
| Moodle version drift changing response shapes | Medium | Pin to `core_webservice_get_site_info`'s reported version; fail loudly on an unexpected shape rather than guessing. |
| Scope creep into a full LMS mirror | Medium | Only pull grade items and the syllabus file. Not submissions, not forum posts, not classmates' data. |

### Phased plan

Each phase is independently useful and independently abandonable.

- **Phase 0 — probe.** Run the two commands above. Record the result here. If
  web services are off, stop and reconsider. *Half a day.*
- **Phase 1 — read-only grade items.** Token held on the device, one course,
  display the gradebook as Moodle reports it. No projection, no syllabus. Proves
  the API and the shape. *2–3 days.*
- **Phase 2 — weights from the gradebook.** Where the instructor configured
  weights, compute contribution to the final grade. Where they did not, say so
  explicitly rather than assuming equal weights. *2–3 days.*
- **Phase 3 — syllabus assist.** Download the syllabus, extract a proposed
  weight table, show it for confirmation, persist what the student confirms.
  *1 week, and the one most likely to disappoint.*
- **Phase 4 — projection.** Current, projected and maximum, each labelled with
  its assumption. *2–3 days.*

### Architectural placement, when it happens

Nothing above changes the layer rules. In this repository it would be:

- `domain/` — `GradeItem`, `WeightScheme`, projection functions. Pure, testable
  with no network, and the projection maths gets tests before anything talks to
  Moodle.
- `domain/repositories.dart` — a `GradebookRepository` interface. The domain
  never learns that Moodle exists.
- `data/` — the Moodle REST implementation, the only place that knows wire
  shapes and endpoint names.
- `presentation/` — confirmation UI for extracted weights, assumption labels.
- Backend — only if a token must be exchanged or a PDF parsed server-side.
  Prefer neither.

The boundary tests already enforce this, so a Moodle client cannot leak upward.

## Decisions

1. Do not scrape the registrar or Moodle where an API or JSON endpoint exists.
2. Never store a registrar password. Never store a Moodle token server-side if
   it can live on the device.
3. Never disable TLS verification, whatever the reference implementation does.
4. A projected grade is always shown with its assumption and its inputs.
5. Extraction proposes; the student confirms; the confirmation is what persists.
6. Settle the overlap with the existing Nuspace Courses tab before building any
   of this.

## Open

- Is Gradus replacing the Nuspace Courses tab, embedding in it, or separate?
- Are Moodle mobile web services enabled on `moodle.nu.edu.kz`? (Phase 0)
- What does NU IT policy say about automated access with a student's own
  credentials?
- Is registrar sync in scope here at all, given Nuspace already has it?

# Gradus Architecture

How this is put together, why, and what the client can and cannot be trusted to
enforce.

## Where everything is written down

Each document owns its subject once. Nothing is repeated between them, so a fact
that changes has exactly one place to change.

| File | Owns |
|---|---|
| [../README.md](../README.md) | Purpose, setup, tests, env vars, limits worth knowing first |
| [PRODUCT.md](./PRODUCT.md) | Product behaviour and rules; what is undecided |
| This file | Package split, layers, host contract, state, account isolation, localization, security boundaries, the control inventory, known limitations, threat model, test strategy |
| [API.md](./API.md) | Implemented endpoints, wire shapes, error codes, versioning |
| [INFRASTRUCTURE.md](./INFRASTRUCTURE.md) | Toolchain, running, checks, secrets, builds, environments, CI, deployment, recovery |
| [../AGENTS.md](../AGENTS.md) | Coding rules |

## Why three Flutter packages

The one-way chain `gradus_app -> gradus_feature -> app_ui` is enforced by each
package's pubspec rather than by convention: `app_ui` cannot reach the feature
because it does not depend on it, and there is no arrangement of imports that
would let it.

`app_ui` was forked once from the Student Events project, deliberately and
without a sync path back. The previous project vendored the same kit as a copy
that was meant to stay untouched and it diverged anyway, undetected: seven files,
an extra dependency, no version marker and nothing that would notice. A shared
package would need a versioned artifact, a release process and an upgrade path
for every consumer, none of which exists, so a fork is what was already
happening and this says so. What was dropped at fork time was everything
belonging to another product - fintech, jobs and gamification widgets, host
auth inputs, a duplicate spacing scale - and what has changed since is an
invisible progress track in the dark theme, one `AppMenu` in place of a bare
`PopupMenuButton` per call site, and a readable `errorText` token to stop a fill
colour being used as label text. The package and token names stay identical to
the sibling projects so a future consolidation is a merge rather than a rewrite,
and `app_ui/test/token_parity_test.dart` makes any further drift a visible diff.

`gradus_app` is scaffolding. It exists so the feature can be run without a host and
is not what ships: a release build of it refuses to open.

## Layers

`gradus_feature/lib/src` and `backend/app` are each split, and a test in
`test/boundaries` (client) and `tests/boundaries` (backend) fails the build if
the split is crossed.

| Layer | Holds | May not |
|---|---|---|
| `domain/` | Entities, value objects, validation, repository interfaces | Import Flutter, a web framework, an ORM, http or storage |
| `application/` | Controllers, use cases, account isolation | Depend on a concrete implementation |
| `data/` / `infrastructure/` | Repository implementations, persistence, auth resolvers | - |
| `presentation/` / `api/` | Screens, widgets, routers, formatting | Reach past their neighbour |

Wiring happens once: `GradusScope` on the client, `create_app` and
`dependencies.py` on the backend.

## Mounting inside a host

The feature runs on its own, and is built so it can also be mounted inside a
host application.

```dart
GradusFeature(
  session: GradusSession(accessToken: token, accountId: id),
  dependencies: createSampleDependencies(),
  config: const GradusConfig.sample(),
)
```

Remote configuration requires HTTPS. The standalone debug host is the only
caller that may opt into plain HTTP, and it does so explicitly.

| Concern | Owner |
|---|---|
| Authentication, token issue and refresh | Host |
| Who the student is, and what their credential may do | Host, or whatever resolves its session |
| Theme, locale, lifecycle, top-level navigation | Host |
| Which data source the feature runs on | Host, by what it passes in |
| GPA navigation, screens and state | Feature |
| GPA strings, in three languages | Feature |

The feature never creates a `MaterialApp`, never reads a locale of its own,
never persists a token, and never asks anyone to sign in.

The host supplies a token: any non-empty string the backend can exchange for an
identity. The feature does not parse it, does not refresh it, and does not
decide what it is allowed to do. **There is no role in this contract.** The
standalone host can hold a student or an operator development session, and the
difference is which token it sends; the backend decides what that token means.

## State

Flutter's own primitives only: `ChangeNotifier`, `AnimatedBuilder`, `setState`.
No state-management package.

The controller is owned by `GradusFeature`, which creates one per session and
disposes it when the session changes; `GradusScope` is the `InheritedWidget` that
exposes it, not the thing that builds it. That split matters: a scope that built
its own controller would hand out a fresh, empty one every time anything above
the feature rebuilt. `GradusScope` is keyed on the access token, so a new token
remounts the subtree and state from one session cannot structurally survive into
the next.

A route pushed onto the host's navigator builds outside the feature's subtree, so
the course detail re-exposes the controller the mount already owns rather than
creating a second one.

## Account isolation

Three mechanisms, because one is not enough:

1. **Scope lifetime.** A new token builds a new scope; the old controllers are
   disposed.
2. **Generation counter.** A load captures it at the start and refuses to write
   its result if it moved, which discards a request that was already in flight
   when the account changed.
3. **Namespaced storage.** Keys carry the schema version and the account:
   `gpa_v2_{accountId}_transcript`. A layout change discards old entries instead
   of misreading them, and one student's courses never surface for another.

The whole transcript - semesters, courses and their assignments - is one key and
one write, so a delete cannot land as a course without its semester. The
course-only layout that preceded semesters is read once from
`gpa_v1_{accountId}_courses` and carried into a single unnamed semester; the old
key is never written or destroyed, and the migration is per account like every
other key.

`accountId` is supplied by the host **alongside** the token and is never derived
from it. A token must not be written to disk, not even as part of a key.

## Localization

ARB files and Flutter's own generator, because Russian needs four plural
categories and a map of strings cannot express that.

The feature installs its own delegate over whatever the host provides, so it
works inside a host that has never heard of it. The language comes from the
host's ambient locale; anything outside English, Kazakh and Russian falls back
to English. Generated output is not committed.

No user-facing text exists outside the ARB files, and a boundary test enforces
it.

## Layout

One column on a phone, two once the window is wide enough for both to stay
readable. The breakpoints live in `presentation/gradus_responsive.dart` rather than
in the shared kit, because they are a decision about these screens.

Two widths, not one. `gradusReadingWidth` caps anything that is read as prose or
scanned as a single block - the summary card, the whole course detail - so a
label and its figure never end up a hand's width apart on a tablet. The course
grid may grow to `gradusGridWidth`, and the summary is left-aligned inside it so
both start at the same edge.

Cards are laid out with a `Wrap` rather than a grid: they are different heights,
and a grid would pad every one of them out to the tallest.

## Forms and the keyboard

A sheet on a phone gives up most of its height the moment the keyboard arrives,
and what is left is usually the wrong half: a heading, three other fields and a
note, with the one being typed into pinned against the top of the keyboard.

Every form here runs focus mode, in `presentation/focus_mode.dart`. While a
field holds the keyboard, everything that is not that field folds away -
heading, other fields, dropdowns, the switch, the notes and the gaps between
them - and Save and Cancel are replaced by Done, which puts the keyboard away
and brings the form back. One duration and one curve for all of it, since two
speeds in the same movement read as a wobble.

`SheetFocusMode` owns the focus nodes, so they outlive the folds and a field
that folds away keeps what was typed into it. The keyboard is read from the
view's insets rather than from focus alone: a field can hold focus with no
keyboard on screen, and the sheet only has a height problem when the keyboard is
actually up. The pattern is taken from the sibling project this kit was forked
from, so the two behave the same way.

Two consequences of folding a field out of the tree rather than hiding it:

- The keyboard's next-field key cannot find the node it is meant to move to, so
  each field names its successor and `moveTo` opens that fold before asking for
  focus. Walking the form never drops out of focus mode.
- A form that opens on its first field autofocuses once and never again. That
  field is unmounted while another one is being typed into, and an autofocus
  firing as it comes back would take the keyboard straight off Done.

A folded field is also out of its `Form`, so `validate()` cannot see it. Nothing
saves from inside focus mode for that reason: Done is the only action offered,
and Save comes back with the rest of the form.

## Security boundaries

Two directions, and neither trusts the other's word for anything.

| Boundary | Must be enforced by | What the client does |
|---|---|---|
| Identity | The session response | Never persists the token, never infers identity |
| Role | The token resolver, rechecked per endpoint | Sends a credential, never a claim |
| Ownership | The authority that accepts writes | Hides affordances, handles refusal gracefully |
| Grade scale and GPA rules | The server, once records are stored | May compute locally for display; the stored value is the server's |
| Rate limiting | The server | Refuses a second submit while one is in flight |
| Text rendering | The client | Plain text only, bidi overrides and controls stripped |

| Boundary | Trusted | Not trusted |
|---|---|---|
| Client to API | Nothing the client sends | Identity, role, ownership, permissions, validation outcomes |
| Host to API | A credential the configured resolver accepts | Any claim the resolver does not itself produce |
| API to storage | Server-constructed queries | Client-supplied paths or keys |

### Controls, and how each is verified

A control with no test beside it is an intention. This table is the inventory;
the tests named in it are the evidence.

| # | Control | Where | Verified by | Status |
|---|---|---|---|---|
| 1 | `APP_ENV` is authoritative and defaults to production | `app/config.py` | `test_config.py::test_environment_defaults_to_production` | Implemented |
| 2 | Development auth refused in production | `app/config.py` | `test_config.py::test_development_auth_is_refused_in_production` | Implemented |
| 3 | Development tokens required, and must differ | `app/config.py` | `test_config.py::test_development_auth_requires_both_tokens`, `::test_student_and_operator_tokens_must_differ` | Implemented |
| 4 | API documentation refused in production | `app/config.py` | `test_config.py::test_api_documentation_is_refused_in_production` | Implemented |
| 5 | CORS from config: no wildcard, no credentials, HTTPS in production | `app/config.py`, `app/main.py` | `test_config.py::test_wildcard_cors_origin_is_refused` and the malformed-origin cases | Implemented |
| 6 | Role comes from the resolved credential and is rechecked per endpoint | `app/dependencies.py` | `test_dependencies.py::test_a_client_cannot_claim_operator_status`, `::test_a_student_may_not_reach_an_operator_endpoint` | Implemented |
| 7 | Development resolver is a separate class, constant-time compare | `app/infrastructure/auth/resolvers.py` | `test_auth.py` | Implemented |
| 8 | Host resolver verifies a host token: signature, issuer, audience and expiry | `app/infrastructure/auth/resolvers.py` | `test_auth.py::test_host_resolver_accepts_a_token_the_issuer_signed` and the rejection cases | Implemented |
| 8a | An unconfigured host resolver rejects every token rather than opening | `app/infrastructure/auth/resolvers.py` | `test_auth.py::test_host_resolver_rejects_every_token`, `::test_an_unconfigured_host_stays_closed_rather_than_open` | Implemented |
| 8b | Signing algorithm allowlisted; key material must match its family | `app/config.py` | `test_config.py::test_an_unlisted_signing_algorithm_is_refused`, `::test_a_public_key_cannot_be_used_as_an_hmac_secret` | Implemented |
| 8c | Operator status comes from a configured claim matching a configured value | `app/infrastructure/auth/resolvers.py` | `test_auth.py::test_a_token_cannot_claim_operator_status`, `::test_operator_status_comes_from_the_configured_claim` | Implemented |
| 9 | Structured error envelope; no internal detail escapes | `app/api/errors.py` | `test_app.py::test_an_unexpected_error_leaks_nothing` | Implemented |
| 10 | Request ID validated on the way in, echoed on the way out | `app/main.py` | `test_app.py::test_a_hostile_request_id_is_replaced` | Implemented |
| 11 | Body cap enforced by counting bytes, not the declared length | `app/main.py` | `test_app.py::test_an_understated_content_length_does_not_bypass_the_cap` | Implemented |
| 12 | Security headers; HSTS only in production | `app/main.py` | `test_app.py::test_security_headers_are_present`, `::test_hsts_only_in_production` | Implemented |
| 13 | Idempotency and expected-version header validation | `app/api/headers.py` | `test_headers.py` | Parsing only; storage not built |
| 14 | Layer boundaries enforced by import scanning | `backend/tests/boundaries/`, `gradus_feature/test/boundaries/` | those suites | Implemented |
| 15 | No literal user-facing text outside the ARB files | `gradus_feature` | `layer_boundaries_test.dart` | Implemented |
| 16 | Development access closed by default in every build | `gradus_app/lib/dev/dev_gate.dart` | `dev_gate_test.dart` | Implemented |
| 17 | No credential compiled into any artifact | `dev_gate.dart`, workflows | `dev_gate_test.dart::no development token is compiled in by default`, `test_ci_policy.py::test_no_workflow_bakes_a_credential_into_a_build` | Implemented |
| 18 | Actions pinned to commit SHAs; scanners checksum-verified | `.github/workflows/ci.yml` | `test_ci_policy.py` | Implemented |
| 19 | Secret scanning over full history; dependency advisory scanning | `.github/workflows/ci.yml` | `test_ci_policy.py::test_secret_and_dependency_scanning_run` | Implemented |
| 20 | Container hardening: non-root, read-only, all capabilities dropped, memory capped | `backend/Dockerfile`, `docker/docker-compose.production.yml` | not yet automated | Implemented, unverified |
| 20a | Deployment refuses a development mechanism, a credential or a dirty tree | `deploy/preflight.sh` | not yet automated | Implemented, unverified |
| 21 | Per-account rate limit on syllabus extraction, failing closed | `app/infrastructure/guards.py` | `test_guards.py::test_a_caller_past_the_allowance_is_refused`, `::test_a_limiter_that_cannot_decide_refuses_rather_than_allows` | Implemented, in process only |
| 22 | Backups and restore | - | - | **Not built**, and nothing is stored |
| 23 | Uploaded document capped by size, pages and extracted characters | `app/domain/syllabus.py`, `app/infrastructure/syllabus/documents.py` | `test_syllabus_domain.py`, `test_syllabus_documents.py::test_extracted_text_is_capped` | Implemented |
| 24 | A document is identified by its bytes, not its declared type | `app/domain/syllabus.py` | `test_syllabus_api.py::test_a_file_of_an_unsupported_type_is_refused` | Implemented |
| 25 | Extracted text stripped of controls, bidi overrides and zero-width characters, on both sides | `app/domain/syllabus.py`, `gradus_feature/lib/src/domain/syllabus.dart` | `test_syllabus_domain.py`, `syllabus_test.dart` | Implemented |
| 26 | Model output is data: no tools on the call, and nothing it returns names an id, a key or an endpoint | `app/infrastructure/syllabus/extractor.py` | `test_syllabus_extractor.py::test_the_document_is_quoted_rather_than_handed_over_as_instructions`, `::test_hostile_model_output_is_cleaned_before_it_leaves` | Implemented |
| 27 | A repeated upload is not paid for twice | `app/infrastructure/guards.py` | `test_syllabus_api.py::test_a_repeated_key_is_not_paid_for_twice` | Implemented, in process only |

### Development access

The standalone host opens the feature with a placeholder session. Both defines
default to false: a debug build must request access, and a release build needs a
second explicit define on top. No workflow passes either, and no workflow passes
a token, which `test_ci_policy.py` enforces.

Development tokens have no default value in source. A build that forgets to
supply one simply does not open. This is deliberate: a default that looks like a
credential is a copy-paste hazard and a scanner false positive, and a build that
forgets one should fail closed rather than open with a known value.

| Mechanism | Guard | In a distributed build |
|---|---|---|
| Development auth adapter | Refused when `APP_ENV=production` | Never |
| Standalone host access | Two defines, both default false | Never; enforced by `test_ci_policy.py` |
| In-memory repository | Selected by the caller of `GradusFeature` | Never the default in a remote build |
| API documentation | Refused when `APP_ENV=production` | Never |

### Known limitations

Read this before assuming the service is deployable.

- **The product is only partly specified.** `PRODUCT.md` records what is built
  and what is still open. The grade scale is no longer among the open parts: the
  points are the registrar's published table and the cutoffs are the ones every
  syllabus in `backend/evals/` prints. What remains is that those cutoffs are
  faculty discretion rather than a university rule, so a course may print its
  own. NU's administrative grades are all carried, and a grade that earns no
  points stands over marked work rather than being overridden by a percentage.
- **The host authentication resolver has never verified a real token.** It
  checks a JWT's signature, issuer, audience and expiry, and rejects everything
  until an issuer and a key are configured. What has not happened is an exchange
  with an actual host application: the issuer, audience, algorithm, subject
  claim and operator claim are all configuration, and none of their values is
  set. Nothing may replace this by falling back to the development
  adapter.
- **Persistence is device-local only.** The transcript lives in that device's
  preference store. There is no server-side model and no sync: reinstalling the
  app loses it. The backend holds nothing at all - no database, no migrations,
  no volume - so `/health/ready` reports that the process is up rather than that
  a dependency answered. There is therefore nothing to back up, encrypt or
  retain, and nothing to lose. That holds only while the transcript stays on the
  device.
- **Rate limiting and idempotency are per process.** Both hold their state in
  memory in one replica. A second replica doubles the allowance and loses the
  retry protection, so a shared store is a precondition for scaling horizontally
  rather than an improvement to make later. The limiter fails closed: if it
  cannot decide, it refuses. Nothing stores an idempotency key or a version yet,
  so no mutating endpoint may be described as idempotent.
- **A syllabus leaves the device.** The document is uploaded to this service and
  its text is sent to Anthropic to be read. Syllabi are public course documents
  rather than student records, nothing is stored, and the student is told before
  the upload - but it is the one place where something the student chose travels
  off their phone.
- **Extraction quality varies with the document.** Syllabi share no layout; the
  three seen so far span two unrelated templates and a free-form Word document,
  and the table changes again with the instructor and the term for the same
  course. A partial fill is a normal outcome, the course title is the field most
  often wrong, and the assessment table is the part that reads most reliably.
  Nothing is applied without the student confirming it.
- **Extraction is measured on five documents, which is not many.** The
  extractor talks to a `StructuredModelClient`, and there are two adapters
  behind it: Anthropic, and one covering every OpenAI-compatible endpoint, which
  is how OpenAI, Gemini and DeepSeek are reached. The default is
  `gemini-3.1-flash-lite` on the second one, and it has now been run:
  `backend/evals/` scores every field and every assessment row exact across five
  documents, one of them a Word document that scores the same as its own PDF
  conversion. The
  compatibility endpoint carries a schema of almost entirely optional fields
  intact, which was the thing in doubt.

  What that does not establish is behaviour on a document unlike these three.
  The sample is two templates - one institutional form seen in three terms, and
  one free-form document - so it shows the right assessment table being found
  next to a letter-grade table and a weekly schedule, and nothing about a layout
  no one has tried yet. A scanned syllabus still cannot be read at all. A page
  cap bounds a PDF, but a Word document has no pages until something lays it
  out, so there the character cap is the only bound.

  The failure stays safe rather than silent: a model that answers off-schema
  produces nothing to parse, and the endpoint returns `extraction_unavailable`
  instead of a draft. A student sees a refusal, never a wrong grade. What it
  does cost them is a slot in their extraction allowance, which is claimed
  before the call.

  Latency is the part worth watching: those nine calls ranged from 2.6 to 14.0
  seconds, and the student is waiting through it.
- **No projected grade.** Assuming the current average continues over the
  remaining weight evaluates to the current average itself, so shipping it as a
  separate figure would dress a restatement up as a forecast. `Max possible` is
  a bound and says what it assumes. See PRODUCT.md.
- **The deployment runs, and is one container on a shared host.** `v0.1.2`
  serves `gradus.anxchywl.dev` behind another project's Caddy. There is no
  monitoring, no alerting, and no backup or restore drill - with nothing stored
  there is nothing yet to back up, which stops being true the moment open
  decision 3 is answered.
- **The identity behind it is this project's own.** No separate host
  application has agreed an issuer, so the deployment signs and verifies with
  one HS256 secret. It authenticates, but only against tokens minted here.
- **No golden tests, no device integration tests, and the client has never run
  against the deployed backend.**

### Threat model

| Threat | Control | Remaining boundary |
|---|---|---|
| Forged role or identity | Request bodies contain neither; both come from the resolved credential, and operator access is rechecked per endpoint | No host issuer, audience or claim names are set, so the verifier is untested against a real token |
| A syllabus carrying instructions aimed at the model | The document is quoted as data with a system prompt that says so; the model is given no tools, and nothing it returns selects an identifier, a storage key, a semester or an endpoint; every returned value is sanitised and range-checked on both sides | A model can still be talked into a wrong extraction, which is why the student confirms the draft rather than it being applied |
| A document that expands or never ends | Capped at three levels: bytes on the way in, pages read, and characters extracted; the read runs off the event loop | A pathological document can still spend the reader's time up to those caps |
| A token forged by swapping its algorithm | One algorithm from an allowlist that excludes `none`; an HS secret and an asymmetric public key cannot be configured together | Depends on the issuer keeping its signing key secret |
| Development access in a shipped build | Two defines, both defaulting to false, plus a CI-policy test asserting no workflow sets them | A local build can still enable them deliberately |
| Credential baked into an artifact | No default token in source; a CI-policy test rejects any credential build define | Nothing stops a developer passing one by hand locally |
| Development auth reaching production | Config refuses to construct when `APP_ENV=production` | Depends on the deployment actually setting `APP_ENV` |
| Oversized or lying request bodies | Streamed byte counting, not the declared `Content-Length` | No per-account quota yet |
| Log and response leakage | Access logs off, fixed message for unhandled errors, validation details carry locations and types but no submitted values | No structured log shipping yet |
| Malformed correlation identifiers | `X-Request-ID` is pattern-checked and replaced when it does not match | - |
| Cross-origin abuse | Origins from config, validated, no wildcard, no credentials, HTTPS required in production | - |
| Replayed or duplicate mutations | Header parsing for `Idempotency-Key` exists and is tested | The storage and locking behind it is not built; no mutating endpoint exists yet |
| Stale edits | `If-Match` parsing exists and is tested | No versioned resource exists yet |

To report a vulnerability, use a private GitHub security advisory, or contact the
repository owner privately. Do not include secrets or real student data.

## Testing strategy

| Suite | Proves |
|---|---|
| `gradus_feature/test/domain` | Credit weighting, letters that earn no points, undefined-versus-zero, weighted contributions, unallocated weight, exact weight totals, entity validation |
| `gradus_feature/test/application` | Add, edit, remove across semesters, courses and assignments; semester selection; rollback on a failed write; discarding a superseded load |
| `gradus_feature/test/data` | Round trips, corrupt entries, migration from the course-only layout, account separation, no token in a storage key |
| `gradus_feature/test/presentation` | Screens, forms, empty and error states, semantics labels, column counts and content widths at three viewport sizes |
| `gradus_feature/test/boundaries` | Layer rules, single wiring point, no literal user-facing text |
| `gradus_app/test` | The development gate is closed by default and carries no token |
| `app_ui/test` | The token surface holds no product concept and no second scale; a progress track is visible on the surface it sits on; a menu groups destructive choices last and refuses a disabled one; a destructive label meets AA on the surface it sits on |
| `backend/tests/unit` | Config guards, resolver behaviour, error envelope, body caps, header validation, role separation |
| `backend/tests/boundaries` | Layer rules, by parsing imports |

The tests that matter most assert that something is *absent*: an internal
detail missing from a 500 response, a role missing from anything the client can
send, a token missing from a default build.

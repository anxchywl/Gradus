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
| This file | Package split, layers, host contract, state, account isolation, localization, security boundaries, known limitations, threat model, test strategy |
| [API.md](./API.md) | Implemented endpoints, wire shapes, error codes, versioning |
| [INFRASTRUCTURE.md](./INFRASTRUCTURE.md) | Toolchain, running, checks, builds, environments, CI, deployment, recovery |
| [SECURITY.md](./SECURITY.md) | Control inventory and how each is verified |
| [../AGENTS.md](../AGENTS.md) | Coding rules |

## Why three Flutter packages

The one-way chain `gradus_app -> gradus_feature -> app_ui` is enforced by each
package's pubspec rather than by convention: `app_ui` cannot reach the feature
because it does not depend on it, and there is no arrangement of imports that
would let it.

`app_ui` was forked once from the Student Events project. The previous project
vendored it as a copy that was meant to stay untouched and it diverged anyway,
undetected. [PROVENANCE.md](../app_ui/PROVENANCE.md) records the source commit
and what was removed; a parity test makes any further drift a visible diff.

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

The feature is built to be mounted inside the university superapp.

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

| Boundary | Must be enforced by | What the client does |
|---|---|---|
| Identity | The session response | Never persists the token, never infers identity |
| Role | The token resolver, rechecked per endpoint | Sends a credential, never a claim |
| Ownership | The authority that accepts writes | Hides affordances, handles refusal gracefully |
| Grade scale and GPA rules | The server, once records are stored | May compute locally for display; the stored value is the server's |
| Rate limiting | The server | Refuses a second submit while one is in flight |
| Text rendering | The client | Plain text only, bidi overrides and controls stripped |

### Development access

The standalone host opens the feature with a placeholder session. Both defines
default to false: a debug build must request access, and a release build needs a
second explicit define on top. No workflow passes either, and no workflow passes
a token, which `test_ci_policy.py` enforces.

Development tokens have no default value in source. A build that forgets to
supply one simply does not open.

### Known limitations

- **The product is only partly specified.** `docs/PRODUCT.md` records what is
  built and what is still open. The grade scale in `FourPointScale` is an example
  so the domain is testable, not an institutional ruling.
- **The host authentication resolver is not implemented.** It rejects every
  token by design, because the issuer, audience, signature and claims are
  undecided. The service is therefore not deployable to production as it stands.
- **Persistence is device-local only.** The transcript lives in that device's
  preference store. There is no server-side model and no sync: reinstalling the
  app loses it. `/health/ready` opens a database session, so it is the only
  backend code path that needs one.
- **Grade scale selection is not implemented.** `FourPointScale` is the only
  scale and it is an example, not an institutional ruling. Its percentage
  cutoffs are an example on exactly the same terms as its quality points, and a
  letter derived from a percentage inherits that.
- **No projected grade.** Assuming the current average continues over the
  remaining weight evaluates to the current average itself, so shipping it as a
  separate figure would dress a restatement up as a forecast. `Max possible` is
  a bound and says what it assumes. See PRODUCT.md.
- **There is no deployment.** No deploy script, no backup script, no restore
  drill. CI validates and builds; nothing ships.
- **No golden tests, no device integration tests, no end-to-end run against a
  live backend.**

### Threat model

| Threat | Control | Remaining boundary |
|---|---|---|
| Forged role or identity | Request bodies contain neither; both come from the resolved credential, and operator access is rechecked per endpoint | Host token validation is not implemented yet |
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
| `gradus_feature/test/domain` | Credit weighting, pass/fail exclusion, undefined-versus-zero, weighted contributions, unallocated weight, exact weight totals, entity validation |
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

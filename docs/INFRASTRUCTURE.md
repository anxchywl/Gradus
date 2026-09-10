# Gradus Infrastructure

Toolchain, running, checks, builds and environments. Architecture rationale is in
[ARCHITECTURE.md](./ARCHITECTURE.md); product rules in [PRODUCT.md](./PRODUCT.md).

## Toolchain

Python 3.12 with `uv`, Flutter 3.38.5, Docker with Compose. Dependencies are
locked and committed; CI installs with `--frozen`. Only the application lockfile
(`gradus_app/pubspec.lock`) is committed on the Flutter side; the library packages
resolve through it.

## Repository layout

```text
app_ui/       shared presentation kit, forked once
gradus_feature/  the embeddable feature
gradus_app/      standalone host
backend/      FastAPI service
docker/       local, production and shared-host Compose definitions
deploy/       preflight, deployment and its rollback
scripts/      verify.sh and the coverage floor
```

## Local setup

```bash
cp .env.example .env          # then fill in the empty values

cd backend
uv sync --extra dev
uv run uvicorn app.main:create_app --factory --reload --port 8000
```

The app is built by a factory rather than at import, so importing
`app.main` never requires a configured environment.

For the standalone Flutter host, supply the development defines. They are build
arguments, not runtime variables, and never belong to a build that leaves this
machine:

```bash
cd gradus_app
flutter run \
  --dart-define=ENABLE_DEV_ACCESS=true \
  --dart-define=GRADUS_ACCESS_TOKEN="$DEVELOPMENT_AUTH_TOKEN" \
  --dart-define=GRADUS_OPERATOR_ACCESS_TOKEN="$DEVELOPMENT_OPERATOR_AUTH_TOKEN"
```

Long-press anywhere to switch between the student and operator development
sessions. That changes which token is sent; the backend decides what the token
may do. Without `ENABLE_DEV_ACCESS` the host shows a closed screen, and without
a token it says so.

## Checks

One command runs everything CI runs:

```bash
./scripts/verify.sh
```

| Stage | Command |
|---|---|
| Backend format | `uv run --frozen ruff format --check app tests` |
| Backend lint | `uv run --frozen ruff check app tests` |
| Backend types | `uv run --frozen mypy app` |
| Backend scan | `uv run --frozen bandit -q -r app` |
| Backend tests | `uv run --frozen pytest --cov=app --cov-fail-under=90 -q` |
| Localizations | `cd gradus_feature && flutter gen-l10n` |
| Client format | `dart format --output=none --set-exit-if-changed lib test` |
| Client analyze | `flutter analyze --no-pub --fatal-infos` |
| Client tests | `flutter test --no-pub --coverage` |
| Client coverage | `./scripts/coverage_floor.sh gradus_feature/coverage/lcov.info 85` |

CI additionally runs gitleaks over the full history, osv-scanner on both
lockfiles, and a debug Android build. Both scanner binaries are checksum-verified
before they run, and every action is pinned to a commit SHA;
`backend/tests/unit/test_ci_policy.py` fails the build if either stops being
true.

Passing checks demonstrate only the covered behaviour. Nothing here has been
exercised against a real database, a real host identity provider, or a deployed
environment.

## Secrets

`SYLLABUS_API_KEY` is the only credential this service holds. It lives in
`.env.production` on the server as a `SecretStr`, is never compiled into a client
build, and with it absent the extraction endpoint refuses rather than the service
failing to start.

Never in source, never in a build define, never in a log, never in a URL.
`.env` is git-ignored; `.env.example` and `deploy/production.env.example` carry
names and empty placeholders only. gitleaks scans the full history on every CI
run.

Development tokens have no default value, for the reason given under
[development access](./ARCHITECTURE.md#development-access).

## Choosing an extraction model

`SYLLABUS_PROVIDER` selects one of `anthropic`, `openai`, `gemini` or
`deepseek`. The last three speak the same wire protocol, so they share one
adapter and differ only by endpoint and model id; only the first has ever made
a real call.

Which one to use is an accuracy question, not a price question. At any plausible
number of students the difference between the cheapest and the dearest option is
tens of dollars a year, and what varies between them is whether they find the
right assessment table in a document that buries it among four other tables.
`backend/evals/` answers that question with measurements.

```bash
cd backend
SYLLABUS_API_KEY=... uv run python -m evals.run \
  --provider gemini --model gemini-3.1-flash-lite \
  --repeat 3 --price-in 0.25 --price-out 1.50
```

It runs the same reader, prompt and schema the service uses, so what it measures
is the pipeline rather than a copy of it. Each case is one document:
`evals/cases/<name>.json` holds the expected values, and the PDF it names sits in
`evals/corpus/`, which is **not committed** - a syllabus carries an instructor's
name and contact details, and the expectations are enough to reproduce a run
without it. A case whose document is absent is skipped rather than failed.

The same course from another instructor, or the same instructor in another term,
is a **separate case**: the assessment table changes with both. Name cases so that
is visible, as in `math273-2026f-a`, and set `template` so the report can group
documents that share a layout apart from the free-form ones.

A run is scored on the assessment table first, because that is what the import
exists for. Weights are compared as a multiset: rows named differently still
count, and a table whose rows were split or invented does not, even when the
total still reaches 100. `--repeat` runs every case several times, since one
sample of a model is an anecdote.

This costs money on every run, so it is not part of `verify.sh` and CI never
runs it.

## Adding user-facing text

Add the key to all three ARB files under `gradus_feature/lib/src/l10n/arb/`,
English first, then:

```bash
cd gradus_feature && flutter gen-l10n
```

Generated output is not committed. A string that exists in only one language is
a build failure waiting to happen, and no literal user-facing text may appear
outside the ARB files - a boundary test enforces that.

## Adding a repository

Define the interface in `gradus_feature/lib/src/domain/repositories.dart`, implement
it under `data/`, and wire it in `GradusScope`. Nothing above `data/` may name an
implementation, and a boundary test fails the build if it does.

## Builds

```bash
cd gradus_app
flutter build apk --debug
flutter build apk --release
```

A release build carries no development define and no token, so it refuses to
open on its own. That is correct: what ships is the feature itself, not this
development scaffolding.

## Environments

| Environment | `APP_ENV` | Auth adapter | Docs |
|---|---|---|---|
| Local | `development` | `development` | optional |
| CI | `test` | `development` | disabled |
| Staging | `production` | `host` | disabled |
| Production | `production` | `host` | disabled |

Staging and production both require a host issuer and signing key, and
`deploy/preflight.sh` refuses to ship without them.

## Deployment

The service is stateless: one container, no database, no volume, nothing to
migrate and nothing to restore. It needs `SYLLABUS_API_KEY` in its environment
to read a syllabus; without one it starts and serves health, and the extraction
endpoint refuses. It shares a host with four other projects, so it
is capped at 256 MiB and publishes no port of its own.

```bash
ENV_FILE=/path/to/.env.production ./deploy/deploy.sh
```

`deploy.sh` detects whether another project's Caddy already owns 80 and 443. If
it does, the service joins that proxy's network for ingress only through
`docker/docker-compose.shared-host.yml`; if it does not, it publishes its own
port. Preflight runs first and refuses a dirty tree, a non-production `APP_ENV`,
a development adapter, a development token, enabled API documentation, a missing
host key, or a missing proxy network. A failed deployment restores the
previous image.

The proxy needs a site block for `GRADUS_API_DOMAIN` reverse-proxying
`gradus-backend-1:8000`; the one for `gradus.anxchywl.dev` lives in the wished
repository's `infra/caddy/Caddyfile.production` beside the blocks for the other
projects on that host.

## Not built yet

Deliberately absent, so nobody assumes otherwise:

- **A released deployment.** The scripts exist and refuse to ship anything
  unsafe, but nothing has shipped: `gradus.anxchywl.dev` has no DNS record, and
  preflight refuses to deploy without a host issuer and key. Images are also
  still built on the host rather than in CI.
- **Migrations and backups.** Neither exists, because nothing is stored. If
  server-side persistence is ever chosen (open decision 3 in PRODUCT.md), both
  are required before the first production write.
- **Monitoring and alerting.**

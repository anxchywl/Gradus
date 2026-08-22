# GPA Infrastructure

Toolchain, running, checks, builds and environments. Architecture rationale is in
[ARCHITECTURE.md](./ARCHITECTURE.md); product rules in [PRODUCT.md](./PRODUCT.md).

## Toolchain

Python 3.12 with `uv`, Flutter 3.38.5, Docker with Compose. Dependencies are
locked and committed; CI installs with `--frozen`. Only the application lockfile
(`gpa_app/pubspec.lock`) is committed on the Flutter side; the library packages
resolve through it.

## Repository layout

```text
app_ui/       shared presentation kit, forked once
gpa_feature/  the embeddable feature
gpa_app/      standalone host
backend/      FastAPI service
docker/       local and production Compose definitions
scripts/      verify.sh and the coverage floor
```

## Local setup

```bash
cp .env.example .env          # then fill in the empty values
docker compose -f docker/docker-compose.yml up -d postgres

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
cd gpa_app
flutter run \
  --dart-define=ENABLE_DEV_ACCESS=true \
  --dart-define=GPA_ACCESS_TOKEN="$DEVELOPMENT_AUTH_TOKEN" \
  --dart-define=GPA_OPERATOR_ACCESS_TOKEN="$DEVELOPMENT_OPERATOR_AUTH_TOKEN"
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
| Localizations | `cd gpa_feature && flutter gen-l10n` |
| Client format | `dart format --output=none --set-exit-if-changed lib test` |
| Client analyze | `flutter analyze --no-pub --fatal-infos` |
| Client tests | `flutter test --no-pub --coverage` |
| Client coverage | `./scripts/coverage_floor.sh gpa_feature/coverage/lcov.info 85` |

CI additionally runs gitleaks over the full history, osv-scanner on both
lockfiles, and a debug Android build. Both scanner binaries are checksum-verified
before they run, and every action is pinned to a commit SHA;
`backend/tests/unit/test_ci_policy.py` fails the build if either stops being
true.

Passing checks demonstrate only the covered behaviour. Nothing here has been
exercised against a real database, a real host identity provider, or a deployed
environment.

## Adding user-facing text

Add the key to all three ARB files under `gpa_feature/lib/src/l10n/arb/`,
English first, then:

```bash
cd gpa_feature && flutter gen-l10n
```

Generated output is not committed. A string that exists in only one language is
a build failure waiting to happen, and no literal user-facing text may appear
outside the ARB files - a boundary test enforces that.

## Adding a repository

Define the interface in `gpa_feature/lib/src/domain/repositories.dart`, implement
it under `data/`, and wire it in `GpaScope`. Nothing above `data/` may name an
implementation, and a boundary test fails the build if it does.

## Builds

```bash
cd gpa_app
flutter build apk --debug
flutter build apk --release
```

A release build carries no development define and no token, so it refuses to
open on its own. That is correct: what ships is the feature mounted inside the
superapp, not this host.

## Environments

| Environment | `APP_ENV` | Auth adapter | Docs |
|---|---|---|---|
| Local | `development` | `development` | optional |
| CI | `test` | `development` | disabled |
| Staging | `production` | `host` | disabled |
| Production | `production` | `host` | disabled |

Staging and production both require an implemented host resolver, which does not
exist yet. See [SECURITY.md](./SECURITY.md).

## Not built yet

Deliberately absent, so nobody assumes otherwise:

- **Deployment.** No deploy script, no target, no rollback procedure. When it is
  written, it deploys the exact tested commit by detached checkout onto a
  verified-clean tree, and builds images in CI rather than on the host.
- **Migrations.** No ORM model exists, so `backend/migrations/` is empty. When
  the first model lands, migrations are expand-contract so the previous release
  runs against the new schema, and CI gains `alembic check`.
- **Backups.** No dump, no verification, no restore drill. Required before the
  first production write.
- **Monitoring and alerting.**

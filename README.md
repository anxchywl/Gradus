# Gradus

A GPA feature for university students, built to be mounted inside the university
superapp. The superapp owns identity; this feature never signs anyone in.

**Partly specified.** A student can organise courses into semesters, grade each
course from the assignments they enter by hand, and see a credit-weighted
average, all stored on their own device. Where course data comes from, and
whether anything is stored server-side, are still open. See
[docs/PRODUCT.md](./docs/PRODUCT.md) for those decisions.

## Packages

```text
app_ui/       shared presentation kit, forked once from the Student Events project
gradus_feature/  the embeddable feature: domain, application, data, presentation
gradus_app/      standalone host for running the feature without the superapp
backend/      FastAPI service: config guards, error envelope, health, auth seam
```

Dependencies point one way: `gradus_app -> gradus_feature -> app_ui`.

## Setup

```bash
cp .env.example .env
docker compose -f docker/docker-compose.yml up -d postgres
cd backend && uv sync --extra dev
uv run uvicorn app.main:create_app --factory --reload --port 8000
```

Full setup, the development defines for the standalone host, and the check
commands are in [docs/INFRASTRUCTURE.md](./docs/INFRASTRUCTURE.md).

## Checks

```bash
./scripts/verify.sh
```

## Documentation

Each document owns its subject once; nothing is repeated.

| File | Owns |
|---|---|
| [docs/PRODUCT.md](./docs/PRODUCT.md) | Product behaviour and what is still undecided |
| [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) | Layers, host contract, limitations, threat model |
| [docs/API.md](./docs/API.md) | Endpoints, wire shapes, error codes, versioning |
| [docs/INFRASTRUCTURE.md](./docs/INFRASTRUCTURE.md) | Toolchain, checks, builds, environments |
| [docs/SECURITY.md](./docs/SECURITY.md) | Control inventory and how each is verified |
| [AGENTS.md](./AGENTS.md) | Coding rules |

## Limits worth knowing before reading further

- No production authentication. The host resolver rejects every token by design,
  because its issuer, audience, signature and claims are undecided.
- No server-side persistence, no database migrations, no deployment, no
  backups. A student's transcript lives on their own device.
- The four-point grade scale in the domain is an example so the rules are
  testable, not an institutional decision. So are its percentage cutoffs.

Nothing here is deployable. It is a foundation, and it says so.

# gpa_calc

A GPA feature for university students, built to be mounted inside the university
superapp. The superapp owns identity; this feature never signs anyone in.

**The product is not specified yet.** What exists is the foundation: enforced
layer boundaries, configuration that refuses to run a development mechanism in
production, a hardened API spine, and a CI pipeline whose own policies are
tested. See [docs/PRODUCT.md](./docs/PRODUCT.md) for the open decisions.

## Packages

```text
app_ui/       shared presentation kit, forked once from the Student Events project
gpa_feature/  the embeddable feature: domain, application, data, presentation
gpa_app/      standalone host for running the feature without the superapp
backend/      FastAPI service: config guards, error envelope, health, auth seam
```

Dependencies point one way: `gpa_app -> gpa_feature -> app_ui`.

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
- No persistence, no migrations, no deployment, no backups.
- The four-point grade scale in the domain is an example so the rules are
  testable, not an institutional decision.

Nothing here is deployable. It is a foundation, and it says so.

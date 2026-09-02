# CLAUDE.md

The coding rules for this repository are in [AGENTS.md](./AGENTS.md). Read it
before making any change, along with the document that owns the area you are
touching:

- Product behaviour: `docs/PRODUCT.md`
- Structure, boundaries, limitations, threat model: `docs/ARCHITECTURE.md`
- Controls and how each is verified: `docs/SECURITY.md`
- Endpoints and wire shapes: `docs/API.md`
- Setup, checks, deployment, recovery: `docs/INFRASTRUCTURE.md`
- Decisions taken and integrations deferred: `docs/decisions/`

Before reporting any change complete, run `./scripts/verify.sh` and report its
actual result.

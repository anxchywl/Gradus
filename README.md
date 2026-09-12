# Gradus

A GPA tracker for university students. Organise courses into semesters, grade
each one from assignments entered by hand or read out of the course syllabus,
and see a credit-weighted average.

> **Work in progress.** The app runs and the grade rules are settled, but the
> backend is a thin service rather than a finished one, and several parts named
> below are not built yet. [Limits](#limits) says which.

## Features

- Courses grouped into semesters, with term and cumulative averages apart
- A course grade built from its assignments, counting only work that is marked
- Fill a course in from its syllabus, PDF or Word: the assessment table is read
  and proposed for the student to confirm
- English, Russian and Kazakh

## Getting started

Flutter 3.38.5, Python 3.12, `uv`, Docker, and Android or iOS tooling. Web and
desktop are not supported.

```bash
cp .env.example .env
uv sync --project backend --extra dev
uv run --project backend uvicorn app.main:create_app --factory --app-dir backend --reload --port 8000
```

```bash
cd gradus_app && flutter run --dart-define=ENABLE_DEV_ACCESS=true
```

```bash
./scripts/verify.sh    # the whole local gate, which is what CI runs
```

Build flags, settings and deployment are in
[docs/INFRASTRUCTURE.md](docs/INFRASTRUCTURE.md).

## Documentation

Each document owns its subject once; nothing is repeated.

| File | Owns |
|---|---|
| [docs/PRODUCT.md](docs/PRODUCT.md) | Product behaviour and what is still undecided |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Packages, layers, security boundaries, limitations, threat model |
| [docs/API.md](docs/API.md) | Endpoints, wire shapes, error codes, versioning |
| [docs/INFRASTRUCTURE.md](docs/INFRASTRUCTURE.md) | Toolchain, checks, secrets, builds, environments, deployment |
| [AGENTS.md](AGENTS.md) | Coding rules for anyone writing code here, human or model |

## Limits

- **Not finished.** Registrar and Moodle import, projections and scale selection
  are not built. [docs/PRODUCT.md](docs/PRODUCT.md) has the full list.
- **Nothing is stored on a server.** A transcript lives on one device, so a
  reinstall loses it.
- **A syllabus is the one thing that leaves the device**, to be read by a model.
  Nothing is stored, and the import card does not say so before the upload.
- **The grade scale is NU's**, and its cutoffs are faculty discretion, so a
  course may state its own and the letter would need correcting by hand.

It is a foundation, and it says so.

## License

[MIT](LICENSE)

# Gradus

Gradus is a GPA tracker for university students. A student organises courses
into semesters, grades each course from the assignments they enter by hand or
reads them out of the course syllabus, and sees a credit-weighted average.

It runs on its own. The feature is packaged so it can also be mounted inside a
larger host application later, and if it ever is, that host owns identity - the
feature never signs anyone in and holds no account of its own.

> **Partly specified.** Transcripts live on the device and nothing is stored
> server-side. The backend is deployed at `gradus.anxchywl.dev`, authenticating
> against tokens this project itself issues rather than a separate host
> application. The limits are listed at the bottom of this file rather than
> buried.

## Features

- Organise courses into semesters and see term and cumulative averages apart
- Add, edit and delete a course with a code, title, credit weight and an
  optional letter chosen by hand
- Add, edit and delete assignments inside a course, each with a weight, a
  maximum score and a score that stays empty until the work is marked
- Fill a course in from its syllabus, PDF or Word: code, title, credits and the whole
  assessment table, proposed for the student to confirm
- See a course grade computed from marked work only, with the unallocated
  weight and the maximum still reachable named rather than assumed
- Focus mode: with the phone's keyboard up, only the field being typed into
  stays on screen, with a Back button to return to the whole form
- English, Russian and Kazakh

Sign-in, server-side storage, registrar and Moodle import, grade projections and
scale selection are not part of the project today. See
[docs/PRODUCT.md](docs/PRODUCT.md) for the complete rules and what is still open.

## Project structure

```text
gradus_app  →  gradus_feature  →  app_ui
   host          the feature       tokens
```

| Package | Holds |
|---|---|
| `app_ui` | Design tokens and generic widgets, forked once from the Student Events project |
| `gradus_feature` | The feature itself: domain, application, data, presentation |
| `gradus_app` | Standalone development host: `MaterialApp`, theme, locale, lifecycle |
| `backend` | FastAPI service: config guards, error envelope, health, auth seam, syllabus extraction |

Dependencies point one way, enforced by each package's pubspec. Inside
`gradus_feature` the layers are `domain`, `application`, `data` and
`presentation`, and a boundary test fails the build if the split is crossed. See
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Development

You need Flutter 3.38.5, Python 3.12, `uv`, Docker, and Android or iOS tooling.
Web and desktop are not supported.

```bash
cp .env.example .env
uv sync --project backend --extra dev
uv run --project backend uvicorn app.main:create_app --factory --app-dir backend --reload --port 8000
```

```bash
cd gradus_app && flutter run --dart-define=ENABLE_DEV_ACCESS=true
```

Run the complete local quality gate, which is what CI runs:

```bash
./scripts/verify.sh
```

Full setup, the development defines for the standalone host, and the deployment
scripts are in [docs/INFRASTRUCTURE.md](docs/INFRASTRUCTURE.md).

## Configuration

`APP_ENV` is authoritative and defaults to production; every development
mechanism is refused at startup when it is `production`. The Flutter host reads
compile-time defines, which are never passed to a build that leaves a
development machine:

| Define | Default | Meaning |
|---|---|---|
| `ENABLE_DEV_ACCESS` | `false` | Lets the standalone host open the feature with a placeholder session |
| `GRADUS_ACCESS_TOKEN` | none | Development student token, passed unchanged to the backend |
| `GRADUS_OPERATOR_ACCESS_TOKEN` | none | Distinct development operator token |
| `GRADUS_BACKEND` | `sample` | `sample` keeps everything on the device; `remote` enables syllabus import |
| `GRADUS_API_BASE_URL` | none | The backend `remote` reads syllabi through; https unless it is on this machine |

Neither token has a default value, so a build that forgets one fails closed
rather than opening with a known credential.

Syllabus extraction runs against one of four providers, selected by
`SYLLABUS_PROVIDER` - `anthropic`, `openai`, `gemini` or `deepseek`. The last
three speak the same wire protocol, so switching between them is a model id and
an endpoint rather than a code change. The default pair is `gemini` and
`gemini-3.1-flash-lite`, which is free within Google's rate limits rather than
chosen on measured accuracy; moving is two lines of environment. Backend settings are documented in
[.env.example](.env.example).

## Documentation

Each document owns its subject once; nothing is repeated.

| File | Owns |
|---|---|
| [docs/PRODUCT.md](docs/PRODUCT.md) | Product behaviour and what is still undecided |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Layers, host contract, security boundaries, controls, limitations, threat model |
| [docs/API.md](docs/API.md) | Endpoints, wire shapes, error codes, versioning |
| [docs/INFRASTRUCTURE.md](docs/INFRASTRUCTURE.md) | Toolchain, checks, secrets, builds, environments, deployment |
| [AGENTS.md](AGENTS.md) | Coding rules for anyone writing code here, human or model |

## Limits worth knowing before reading further

- No way for a student to sign in yet. The deployed backend verifies tokens
  signed with one HS256 secret held on the server, because no separate host
  application issues them, and a release build of the app shows a closed
  screen. Only a development build carrying a token gets in.
- No server-side persistence and no database at all. A transcript lives on the
  student's own device, so reinstalling the app loses it, and there is nothing
  to back up.
- A syllabus is the one thing that leaves the device: the PDF or Word document
  is uploaded and its text is read by a model on the server. Nothing is stored,
  and the import card does not say at the moment of upload that the file leaves
  the phone.
- The grade scale is NU's: the registrar's published quality points, and the
  percentage cutoffs the Course Specification Form prints. Those cutoffs are
  faculty discretion, so a course may state its own and the student would have
  to correct the letter by hand.
- The deployed backend serves health and syllabus extraction, nothing else.
  It shares a host with four other projects and has no monitoring.

It is a foundation, and it says so.

## License

Gradus is licensed under the [MIT License](LICENSE).

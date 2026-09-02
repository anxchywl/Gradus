# Gradus Security

Controls, where they live, and how each is verified. Boundaries and the threat
model are in [ARCHITECTURE.md](./ARCHITECTURE.md) and are not repeated here.

## Trust boundaries

| Boundary | Trusted | Not trusted |
|---|---|---|
| Client to API | Nothing the client sends | Identity, role, ownership, permissions, validation outcomes |
| Superapp to API | A credential the configured resolver accepts | Any claim the resolver does not itself produce |
| API to database | Server-constructed queries | Client-supplied SQL, paths or keys |

## Control inventory

| # | Control | Where | Verified by | Status |
|---|---|---|---|---|
| 1 | `APP_ENV` is authoritative and defaults to production | `app/config.py` | `test_config.py::test_environment_defaults_to_production` | Implemented |
| 2 | Development auth refused in production | `app/config.py` | `test_config.py::test_development_auth_is_refused_in_production` | Implemented |
| 3 | Development tokens required, and must differ | `app/config.py` | `test_config.py::test_development_auth_requires_both_tokens`, `::test_student_and_operator_tokens_must_differ` | Implemented |
| 4 | API documentation refused in production | `app/config.py` | `test_config.py::test_api_documentation_is_refused_in_production` | Implemented |
| 5 | CORS from config: no wildcard, no credentials, HTTPS in production | `app/config.py`, `app/main.py` | `test_config.py::test_wildcard_cors_origin_is_refused` and the malformed-origin cases | Implemented |
| 6 | Role comes from the resolved credential and is rechecked per endpoint | `app/dependencies.py` | `test_dependencies.py::test_a_client_cannot_claim_operator_status`, `::test_a_student_may_not_reach_an_operator_endpoint` | Implemented |
| 7 | Development resolver is a separate class, constant-time compare | `app/infrastructure/auth/resolvers.py` | `test_auth.py` | Implemented |
| 8 | Host resolver rejects every token until implemented | `app/infrastructure/auth/resolvers.py` | `test_auth.py::test_host_resolver_rejects_every_token` | Deliberate placeholder |
| 9 | Structured error envelope; no internal detail escapes | `app/api/errors.py` | `test_app.py::test_an_unexpected_error_leaks_nothing` | Implemented |
| 10 | Request ID validated on the way in, echoed on the way out | `app/main.py` | `test_app.py::test_a_hostile_request_id_is_replaced` | Implemented |
| 11 | Body cap enforced by counting bytes, not the declared length | `app/main.py` | `test_app.py::test_an_understated_content_length_does_not_bypass_the_cap` | Implemented |
| 12 | Security headers; HSTS only in production | `app/main.py` | `test_app.py::test_security_headers_are_present`, `::test_hsts_only_in_production` | Implemented |
| 13 | Idempotency and expected-version header validation | `app/api/headers.py` | `test_headers.py` | Parsing only; storage not built |
| 14 | Layer boundaries enforced by import scanning | `tests/boundaries/`, `gradus_feature/test/boundaries/` | those suites | Implemented |
| 15 | No literal user-facing text outside the ARB files | `gradus_feature` | `layer_boundaries_test.dart` | Implemented |
| 16 | Development access closed by default in every build | `gradus_app/lib/dev/dev_gate.dart` | `dev_gate_test.dart` | Implemented |
| 17 | No credential compiled into any artifact | `dev_gate.dart`, workflows | `dev_gate_test.dart::no development token is compiled in by default`, `test_ci_policy.py::test_no_workflow_bakes_a_credential_into_a_build` | Implemented |
| 18 | Actions pinned to commit SHAs; scanners checksum-verified | `.github/workflows/ci.yml` | `test_ci_policy.py` | Implemented |
| 19 | Secret scanning over full history; dependency advisory scanning | `.github/workflows/ci.yml` | `test_ci_policy.py::test_secret_and_dependency_scanning_run` | Implemented |
| 20 | Container hardening: non-root, read-only, all capabilities dropped | `backend/Dockerfile`, `docker/docker-compose.production.yml` | not yet automated | Implemented, unverified |
| 21 | Rate limiting | - | - | **Not built** |
| 22 | Backups and restore | - | - | **Not built** |

## Secrets

Never in source, never in a build define, never in a log, never in a URL.
`SecretStr` in configuration. `.env` is git-ignored; `.env.example` carries names
and empty placeholders only. gitleaks scans the full history on every CI run.

Development tokens have **no default value**. This is deliberate: a default that
looks like a credential is a copy-paste hazard and a scanner false positive, and
a build that forgets to supply one should fail closed rather than open with a
known value.

## Development-only mechanisms

| Mechanism | Guard | In a distributed build |
|---|---|---|
| Development auth adapter | Refused when `APP_ENV=production` | Never |
| Standalone host access | Two defines, both default false | Never; enforced by `test_ci_policy.py` |
| In-memory repository | Selected by the caller of `GradusFeature` | Never the default in a remote build |
| API documentation | Refused when `APP_ENV=production` | Never |

## Known gaps

Read this before assuming the service is deployable.

- **No production authentication exists.** The host resolver is a placeholder
  that rejects everything. Nothing can be deployed until it is written, and it
  must not be replaced by falling back to the development adapter.
- **No rate limiting.** When it is added, it must fail closed: if its backing
  store is unavailable, refuse the request rather than allow it. A predecessor
  project had one limiter that failed closed and another that failed open, and
  the open one was silent.
- **No persistence, so no data-at-rest, backup or retention story.**
- **Idempotency and optimistic concurrency are parsing only.** The headers are
  validated; nothing stores a key or a version yet. Do not describe a mutating
  endpoint as idempotent until the storage behind it exists.
- **Container hardening is written but never exercised.** No image has been
  built or run in an environment resembling production.

## Reporting a vulnerability

Use a private GitHub security advisory, or contact the repository owner
privately. Do not include secrets or real student data in a report.

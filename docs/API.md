# GPA API Contract

The boundary between the Flutter repository interfaces and the backend service.
Product meaning stays in [PRODUCT.md](./PRODUCT.md); this document owns endpoint
and wire-shape decisions.

## Current implementation

Only the health checks exist. No feature endpoint has been written, because the
product is not specified.

| Endpoint | Authentication | Purpose |
|---|---|---|
| `GET /health/live` | No | Process liveness |
| `GET /health/ready` | No | Database readiness |

## Conventions every endpoint follows

- **Versioning.** Every non-health endpoint is prefixed `/api/v1`. The prefix is
  there from the first endpoint so a breaking change never needs a shim.
- **Success shape.** `{"data": ..., "meta": {"request_id": "..."}}`.
- **Error shape.** `{"error": {"code": "...", "message": "...", "request_id": "...", "details": ...}}`.
  `code` is stable and machine-readable; `message` is for a human reading logs,
  not for display. Clients switch on `code`, never on `message`.
- **Correlation.** Every response carries `X-Request-ID`. A client may supply one;
  it is used only when it matches `^[A-Za-z0-9._-]{1,64}$`, and is otherwise
  replaced.
- **Authentication.** `Authorization: Bearer <token>`. The token is resolved to
  an identity by the configured adapter. No endpoint reads identity, role or
  ownership from a body, a query parameter or any other header.
- **Caching.** Every `/api/` response is `Cache-Control: private, no-store`.

## Conventions for endpoints not yet written

These are decided in advance so the first one does not set a precedent by
accident.

- **Mutations with an external or duplicated effect** require an
  `Idempotency-Key` header matching `^[A-Za-z0-9._:-]{16,128}$`. Parsing is in
  `app/api/headers.py` and tested; the storage and locking behind it is not
  built yet.
- **Editable resources** carry a version as `ETag` and require `If-Match` on
  write. A mismatch is `409` and the client reloads before retrying.
- **Lists** paginate by opaque cursor. The client never constructs one.
- **Status codes.** `401` unauthenticated, `403` authenticated but not
  permitted, `404` absent or deliberately invisible, `409` conflict, `413` body
  too large, `422` validation, `429` rate limited, `503` a dependency is down.

## Repository mapping

Filled in as endpoints are written: each Flutter repository interface in
`gpa_feature/lib/src/domain/repositories.dart` maps to one endpoint here, with
its request, response and error codes.

| Flutter interface | Endpoint | Request | Response | Errors |
|---|---|---|---|---|
| `CourseRepository.load` | not implemented | - | - | - |
| `CourseRepository.save` | not implemented | - | - | - |
| `GradeScaleRepository.active` | not implemented | - | - | - |

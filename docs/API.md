# Gradus API Contract

The boundary between the Flutter repository interfaces and the backend service.
Product meaning stays in [PRODUCT.md](./PRODUCT.md); this document owns endpoint
and wire-shape decisions.

## Current implementation

Only the health checks exist. No feature endpoint has been written, because the
product is not specified.

| Endpoint | Authentication | Purpose |
|---|---|---|
| `POST /api/v1/syllabus-extractions` | Bearer | Read a syllabus PDF into a course draft |
| `GET /health/live` | No | Process liveness |
| `GET /health/ready` | No | Service readiness; the service has no dependency to wait on |

### Syllabus extraction

`POST /api/v1/syllabus-extractions` takes the PDF as the request body with
`Content-Type: application/pdf` - one file, so there is no form parser in the
path - and requires an `Idempotency-Key`, because the call costs money and a
retry must be recognisable as one. It stores nothing.

```json
{"data": {"code": "MATH 273", "title": "Linear Algebra with Applications",
          "credits": 8, "creditUnit": "ECTS", "term": "Fall 2026",
          "assessments": [{"name": "Midterm exam", "weight": 40}]}}
```

Every field is nullable and `assessments` may be empty: a syllabus that states
nothing recognisable is a partial answer, not an error. Weights are percentages
of the final grade and are reported as extracted, never scaled to total 100.
Credits carry the unit as printed and are never converted between credit
systems.

| Code | Status | Means |
|---|---|---|
| `document_not_a_pdf` | 422 | The bytes do not begin `%PDF-` |
| `document_empty` | 422 | Nothing was uploaded |
| `document_unreadable` | 422 | The bytes are a PDF header and not much else |
| `document_encrypted` | 422 | Password protected |
| `document_has_no_text` | 422 | No text layer; a scan, and there is no OCR |
| `document_too_large` | 413 | Larger than `SYLLABUS_DOCUMENT_MAX_BYTES` |
| `idempotency_key_invalid` | 422 | Header missing or malformed |
| `rate_limited` | 429 | Past the per-account allowance |
| `extraction_unavailable` | 503 | No API key configured, or the model call failed |

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
`gradus_feature/lib/src/domain/repositories.dart` maps to one endpoint here, with
its request, response and error codes.

| Flutter interface | Endpoint | Request | Response | Errors |
|---|---|---|---|---|
| `SyllabusImporter.importFromFile` | `POST /api/v1/syllabus-extractions` | `application/pdf` body | draft | the table above |
| `TranscriptRepository.load` | not implemented | - | - | - |
| `TranscriptRepository.save` | not implemented | - | - | - |
| `GradeScaleRepository.active` | not implemented | - | - | - |

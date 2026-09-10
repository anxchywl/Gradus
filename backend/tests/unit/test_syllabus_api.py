from __future__ import annotations

from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from app.application.syllabus_service import SyllabusService
from app.config import AuthAdapter
from app.domain.syllabus import (
    AssessmentDraft,
    ExtractionUnavailableError,
    SyllabusDraft,
)
from app.infrastructure.guards import InMemoryDraftStore, InMemoryRateLimiter
from app.infrastructure.syllabus.documents import SyllabusDocumentReader
from app.main import create_app
from tests.conftest import settings
from tests.syllabus_fixtures import syllabus_docx, text_pdf

PATH = "/api/v1/syllabus-extractions"
KEY = "an-idempotency-key-0001"
STUDENT = {"Authorization": "Bearer student-token-value"}


# no test reaches the model: extraction is a fake, and a real call would both
# cost money and make the suite depend on a third party
class FakeExtractor:
    def __init__(self, draft: SyllabusDraft | None = None) -> None:
        self.calls = 0
        self.seen_text = ""
        self._draft = draft or SyllabusDraft(
            code="MATH 273",
            title="Linear Algebra",
            credits=8.0,
            credit_unit="ECTS",
            term="Fall 2026",
            assessments=[AssessmentDraft(name="Midterm", weight=40.0)],
        )

    async def extract(self, text: str) -> SyllabusDraft:
        self.calls += 1
        self.seen_text = text
        return self._draft


class FailingExtractor:
    async def extract(self, text: str) -> SyllabusDraft:
        raise ExtractionUnavailableError(
            "extraction_unavailable",
            "The syllabus could not be read right now.",
        )


def _client(
    extractor: object,
    *,
    allowance: int = 20,
    configured: bool = True,
) -> Iterator[TestClient]:
    application = create_app(
        settings(
            AUTH_ADAPTER=AuthAdapter.development,
            DEVELOPMENT_AUTH_TOKEN="student-token-value",
            DEVELOPMENT_OPERATOR_AUTH_TOKEN="operator-token-value",
        )
    )
    with TestClient(application, raise_server_exceptions=False) as client:
        client.app.state.syllabus_service = (  # type: ignore[attr-defined]
            SyllabusService(
                reader=SyllabusDocumentReader(
                    maximum_pages=60,
                    maximum_characters=120_000,
                ),
                extractor=extractor,  # type: ignore[arg-type]
                limiter=InMemoryRateLimiter(
                    allowance=allowance,
                    window_seconds=3_600,
                ),
                drafts=InMemoryDraftStore(maximum_entries=16, ttl_seconds=900),
                maximum_document_bytes=4 * 1_024 * 1_024,
            )
            if configured
            else None
        )
        yield client


@pytest.fixture
def extractor() -> FakeExtractor:
    return FakeExtractor()


@pytest.fixture
def client(extractor: FakeExtractor) -> Iterator[TestClient]:
    yield from _client(extractor)


def _upload(
    client: TestClient,
    *,
    content: bytes | None = None,
    key: str | None = KEY,
    headers: dict[str, str] | None = None,
):
    sent = dict(STUDENT if headers is None else headers)
    if key is not None:
        sent["Idempotency-Key"] = key
    sent["Content-Type"] = "application/pdf"
    return client.post(
        PATH,
        content=content if content is not None else text_pdf("Midterm 40 percent"),
        headers=sent,
    )


def test_a_syllabus_becomes_a_draft(client: TestClient) -> None:
    response = _upload(client)

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["code"] == "MATH 273"
    assert data["creditUnit"] == "ECTS"
    assert data["assessments"] == [{"name": "Midterm", "weight": 40.0}]
    assert response.headers["Cache-Control"] == "private, no-store"


def test_the_document_text_reaches_the_extractor(
    client: TestClient,
    extractor: FakeExtractor,
) -> None:
    _upload(client, content=text_pdf("Final exam 60 percent"))

    assert "Final exam 60 percent" in extractor.seen_text


def test_an_unauthenticated_caller_is_refused(client: TestClient) -> None:
    assert _upload(client, headers={}).status_code == 401


@pytest.mark.parametrize("key", [None, "short", "has spaces in it and is long"])
def test_a_missing_or_malformed_idempotency_key_is_refused(
    client: TestClient,
    key: str | None,
) -> None:
    # the call costs money, so a retry must be recognisable as one
    response = _upload(client, key=key)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "idempotency_key_invalid"


def test_a_repeated_key_is_not_paid_for_twice(
    client: TestClient,
    extractor: FakeExtractor,
) -> None:
    first = _upload(client)
    second = _upload(client)

    assert first.json()["data"] == second.json()["data"]
    assert extractor.calls == 1


def test_a_file_of_an_unsupported_type_is_refused(
    client: TestClient,
    extractor: FakeExtractor,
) -> None:
    response = _upload(client, content=b"MZ\x90\x00 an executable")

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "document_unsupported_type"
    assert extractor.calls == 0


def test_a_word_document_is_accepted(
    client: TestClient,
    extractor: FakeExtractor,
) -> None:
    content = syllabus_docx(
        ["MATH 162 Calculus II"], rows=[("Midterm", "40%"), ("Final", "60%")]
    )

    response = _upload(client, content=content)

    assert response.status_code == 200
    assert extractor.calls == 1


def test_an_oversized_upload_never_reaches_the_reader(
    extractor: FakeExtractor,
) -> None:
    for client in _client(extractor):
        response = _upload(client, content=b"%PDF-" + b"x" * (5 * 1_024 * 1_024))

        assert response.status_code == 413
        assert extractor.calls == 0


def test_a_caller_past_the_allowance_is_refused(extractor: FakeExtractor) -> None:
    for client in _client(extractor, allowance=1):
        assert _upload(client, key="an-idempotency-key-0001").status_code == 200
        refused = _upload(client, key="an-idempotency-key-0002")

        assert refused.status_code == 429
        assert refused.json()["error"]["code"] == "rate_limited"


def test_an_unconfigured_service_refuses_rather_than_failing_open() -> None:
    for client in _client(FakeExtractor(), configured=False):
        response = _upload(client)

        assert response.status_code == 503
        assert response.json()["error"]["code"] == "extraction_unavailable"


def test_an_upstream_failure_leaks_nothing() -> None:
    for client in _client(FailingExtractor()):
        response = _upload(client)

        assert response.status_code == 503
        body = response.text
        assert "anthropic" not in body.lower()
        assert "syllabus could not be read" in body

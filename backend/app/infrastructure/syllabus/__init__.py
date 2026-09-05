from __future__ import annotations

from collections.abc import Awaitable, Callable

import anthropic

from app.application.syllabus_service import SyllabusService
from app.config import Settings
from app.infrastructure.guards import InMemoryDraftStore, InMemoryRateLimiter
from app.infrastructure.syllabus.documents import PdfDocumentReader
from app.infrastructure.syllabus.extractor import ModelSyllabusExtractor

__all__ = ["create_syllabus_service"]


def create_syllabus_service(
    settings: Settings,
) -> tuple[SyllabusService | None, Callable[[], Awaitable[None]] | None]:
    key = settings.anthropic_api_key
    if key is None:
        return None, None

    client = anthropic.AsyncAnthropic(
        api_key=key.get_secret_value(),
        timeout=settings.syllabus_timeout_seconds,
    )
    service = SyllabusService(
        reader=PdfDocumentReader(
            maximum_pages=settings.syllabus_document_max_pages,
            maximum_characters=settings.syllabus_document_max_characters,
        ),
        extractor=ModelSyllabusExtractor(
            client,
            model=settings.syllabus_model,
            maximum_output_tokens=settings.syllabus_output_tokens,
        ),
        limiter=InMemoryRateLimiter(
            allowance=settings.syllabus_rate_limit,
            window_seconds=settings.syllabus_rate_window_seconds,
        ),
        drafts=InMemoryDraftStore(maximum_entries=512, ttl_seconds=900.0),
        maximum_document_bytes=settings.syllabus_document_max_bytes,
    )
    return service, client.close

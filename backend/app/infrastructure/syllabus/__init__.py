from __future__ import annotations

from collections.abc import Awaitable, Callable

import anthropic
import openai

from app.application.syllabus_service import SyllabusService
from app.config import Settings, SyllabusProvider
from app.infrastructure.guards import InMemoryDraftStore, InMemoryRateLimiter
from app.infrastructure.syllabus.clients import (
    AnthropicModelClient,
    OpenAICompatibleModelClient,
    StructuredModelClient,
    profile_for,
)
from app.infrastructure.syllabus.documents import PdfDocumentReader
from app.infrastructure.syllabus.extractor import ModelSyllabusExtractor

__all__ = ["create_model_client", "create_syllabus_service"]


def create_model_client(settings: Settings) -> StructuredModelClient:
    key = settings.syllabus_api_key
    if key is None:
        raise ValueError("SYLLABUS_API_KEY is required to build a model client")

    if settings.syllabus_provider is SyllabusProvider.anthropic:
        return AnthropicModelClient(
            anthropic.AsyncAnthropic(
                api_key=key.get_secret_value(),
                timeout=settings.syllabus_timeout_seconds,
            ),
            model=settings.syllabus_model,
        )

    profile = profile_for(settings.syllabus_provider.value)
    return OpenAICompatibleModelClient(
        openai.AsyncOpenAI(
            api_key=key.get_secret_value(),
            base_url=settings.syllabus_base_url or profile.base_url,
            timeout=settings.syllabus_timeout_seconds,
        ),
        model=settings.syllabus_model,
        output_cap_field=profile.output_cap_field,
    )


def create_syllabus_service(
    settings: Settings,
) -> tuple[SyllabusService | None, Callable[[], Awaitable[None]] | None]:
    if not settings.syllabus_extraction_configured:
        return None, None

    client = create_model_client(settings)
    service = SyllabusService(
        reader=PdfDocumentReader(
            maximum_pages=settings.syllabus_document_max_pages,
            maximum_characters=settings.syllabus_document_max_characters,
        ),
        extractor=ModelSyllabusExtractor(
            client,
            maximum_output_tokens=settings.syllabus_output_tokens,
        ),
        limiter=InMemoryRateLimiter(
            allowance=settings.syllabus_rate_limit,
            window_seconds=settings.syllabus_rate_window_seconds,
        ),
        drafts=InMemoryDraftStore(maximum_entries=512, ttl_seconds=900.0),
        maximum_document_bytes=settings.syllabus_document_max_bytes,
    )
    return service, client.aclose

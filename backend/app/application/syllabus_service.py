from __future__ import annotations

from app.domain.syllabus import (
    DocumentReader,
    DraftStore,
    RateLimiter,
    SyllabusDraft,
    SyllabusExtractor,
    require_supported_document,
)


class SyllabusService:
    def __init__(
        self,
        *,
        reader: DocumentReader,
        extractor: SyllabusExtractor,
        limiter: RateLimiter,
        drafts: DraftStore,
        maximum_document_bytes: int,
    ) -> None:
        self._reader = reader
        self._extractor = extractor
        self._limiter = limiter
        self._drafts = drafts
        self._maximum_document_bytes = maximum_document_bytes

    async def extract(
        self,
        *,
        subject: str,
        idempotency_key: str,
        content: bytes,
    ) -> SyllabusDraft:
        # the key is scoped to the caller, so one account cannot read back
        # another account's draft by guessing a key
        scoped_key = f"{subject}:{idempotency_key}"
        remembered = await self._drafts.remembered(scoped_key)
        if remembered is not None:
            return remembered

        # the cheap checks come first: a limit that only applies after the
        # expensive call has already been paid for protects nothing
        await self._limiter.claim(subject)
        content, kind = require_supported_document(
            content, maximum_bytes=self._maximum_document_bytes
        )

        text = await self._reader.read(content, kind)
        draft = await self._extractor.extract(text)
        await self._drafts.remember(scoped_key, draft)
        return draft

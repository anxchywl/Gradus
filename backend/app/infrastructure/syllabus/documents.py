from __future__ import annotations

import io

from anyio import to_thread
from pypdf import PdfReader
from pypdf.errors import PdfReadError

from app.domain.syllabus import (
    DocumentEncryptedError,
    DocumentHasNoTextError,
    DocumentUnreadableError,
)


# pypdf is synchronous and cpu-bound, so it runs off the event loop
class PdfDocumentReader:
    def __init__(self, *, maximum_pages: int, maximum_characters: int) -> None:
        self._maximum_pages = maximum_pages
        self._maximum_characters = maximum_characters

    async def read(self, content: bytes) -> str:
        return await to_thread.run_sync(self._read, content)

    def _read(self, content: bytes) -> str:
        try:
            reader = PdfReader(io.BytesIO(content))
        except (PdfReadError, ValueError) as error:
            raise DocumentUnreadableError(
                "document_unreadable",
                "The file could not be read as a PDF.",
            ) from error

        if reader.is_encrypted:
            raise DocumentEncryptedError(
                "document_encrypted",
                "The file is password protected.",
            )

        pieces: list[str] = []
        length = 0
        # a document that expands on extraction is capped by what it produces,
        # not by the size it arrived as
        for page in reader.pages[: self._maximum_pages]:
            try:
                text = page.extract_text() or ""
            except (PdfReadError, ValueError, KeyError):
                # one unreadable page must not lose the rest of the document
                continue
            pieces.append(text)
            length += len(text)
            if length >= self._maximum_characters:
                break

        joined = "\n".join(pieces)[: self._maximum_characters]
        if not joined.strip():
            raise DocumentHasNoTextError(
                "document_has_no_text",
                "The file has no text to read; a scan cannot be imported.",
            )
        return joined

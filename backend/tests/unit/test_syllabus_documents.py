from __future__ import annotations

import pytest

from app.domain.syllabus import (
    DocumentEncryptedError,
    DocumentHasNoTextError,
    DocumentUnreadableError,
)
from app.infrastructure.syllabus.documents import PdfDocumentReader
from tests.syllabus_fixtures import blank_pdf, encrypted_pdf, text_pdf


def _reader(**overrides: int) -> PdfDocumentReader:
    settings = {"maximum_pages": 60, "maximum_characters": 120_000}
    settings.update(overrides)
    return PdfDocumentReader(**settings)  # type: ignore[arg-type]


async def test_text_is_read_out_of_a_pdf() -> None:
    text = await _reader().read(text_pdf("Midterm 40 percent"))

    assert "Midterm 40 percent" in text


async def test_a_password_protected_document_is_refused() -> None:
    with pytest.raises(DocumentEncryptedError):
        await _reader().read(encrypted_pdf())


async def test_a_document_with_no_text_layer_is_refused() -> None:
    # a scan reaches here as pages with no text, and there is no OCR
    with pytest.raises(DocumentHasNoTextError):
        await _reader().read(blank_pdf())


async def test_a_file_that_only_claims_to_be_a_pdf_is_refused() -> None:
    with pytest.raises(DocumentUnreadableError):
        await _reader().read(b"%PDF-1.4\nnot really a document")


async def test_extracted_text_is_capped() -> None:
    capped = await _reader(maximum_characters=10).read(
        text_pdf("a considerably longer syllabus than ten characters")
    )

    assert len(capped) == 10

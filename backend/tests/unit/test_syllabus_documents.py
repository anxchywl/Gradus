from __future__ import annotations

import pytest

from app.domain.syllabus import (
    DocumentEncryptedError,
    DocumentHasNoTextError,
    DocumentKind,
    DocumentUnreadableError,
)
from app.infrastructure.syllabus.documents import SyllabusDocumentReader
from tests.syllabus_fixtures import (
    blank_pdf,
    empty_docx,
    encrypted_pdf,
    syllabus_docx,
    text_pdf,
)


def _reader(**overrides: int) -> SyllabusDocumentReader:
    settings = {"maximum_pages": 60, "maximum_characters": 120_000}
    settings.update(overrides)
    return SyllabusDocumentReader(**settings)  # type: ignore[arg-type]


async def test_text_is_read_out_of_a_pdf() -> None:
    text = await _reader().read(text_pdf("Midterm 40 percent"), DocumentKind.pdf)

    assert "Midterm 40 percent" in text


async def test_a_password_protected_document_is_refused() -> None:
    with pytest.raises(DocumentEncryptedError):
        await _reader().read(encrypted_pdf(), DocumentKind.pdf)


async def test_a_document_with_no_text_layer_is_refused() -> None:
    # a scan reaches here as pages with no text, and there is no OCR
    with pytest.raises(DocumentHasNoTextError):
        await _reader().read(blank_pdf(), DocumentKind.pdf)


async def test_a_file_that_only_claims_to_be_a_pdf_is_refused() -> None:
    with pytest.raises(DocumentUnreadableError):
        await _reader().read(b"%PDF-1.4\nnot really a document", DocumentKind.pdf)


async def test_extracted_text_is_capped() -> None:
    capped = await _reader(maximum_characters=10).read(
        text_pdf("a considerably longer syllabus than ten characters"),
        DocumentKind.pdf,
    )

    assert len(capped) == 10


async def test_text_is_read_out_of_a_word_document() -> None:
    content = syllabus_docx(["MATH 162 Calculus II", "Credits (ECTS): 8 ECTS"])

    text = await _reader().read(content, DocumentKind.docx)

    assert "MATH 162 Calculus II" in text
    assert "Credits (ECTS): 8 ECTS" in text


async def test_the_assessment_table_of_a_word_document_survives() -> None:
    content = syllabus_docx(
        ["Course syllabus"],
        rows=[("Activity", "Weighting"), ("Midterm", "40%"), ("Final", "60%")],
    )

    text = await _reader().read(content, DocumentKind.docx)

    # walking paragraphs alone would drop the one table the import exists to read
    assert "Midterm" in text
    assert "40%" in text
    assert "Final" in text
    assert "60%" in text


async def test_a_word_document_keeps_its_rows_together() -> None:
    content = syllabus_docx([], rows=[("Midterm", "40%"), ("Final", "60%")])

    text = await _reader().read(content, DocumentKind.docx)

    # a name separated from its weight is what turns a table into noise
    assert "Midterm | 40%" in text
    assert "Final | 60%" in text


async def test_a_word_document_with_nothing_in_it_is_refused() -> None:
    with pytest.raises(DocumentHasNoTextError):
        await _reader().read(empty_docx(), DocumentKind.docx)


async def test_bytes_that_are_a_zip_but_not_a_word_document_are_refused() -> None:
    with pytest.raises(DocumentUnreadableError):
        await _reader().read(b"PK\x03\x04 not really a docx", DocumentKind.docx)


async def test_extracted_text_of_a_word_document_is_capped() -> None:
    content = syllabus_docx(["x" * 500 for _ in range(20)])

    text = await _reader(maximum_characters=1_000).read(content, DocumentKind.docx)

    assert len(text) == 1_000


async def test_a_merged_cell_is_not_repeated_once_per_column() -> None:
    content = syllabus_docx([], rows=[("Midterm", "Midterm"), ("Final", "60%")])

    text = await _reader().read(content, DocumentKind.docx)

    # a heading merged across columns arrives once per column it spans, and
    # repeating it wastes the tokens the document is read with
    assert "Midterm | Midterm" not in text
    assert "Final | 60%" in text


async def test_an_empty_cell_carries_nothing_and_is_dropped() -> None:
    content = syllabus_docx([], rows=[("Homework", "")])

    text = await _reader().read(content, DocumentKind.docx)

    assert "Homework" in text
    assert "Homework |" not in text

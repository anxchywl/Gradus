from __future__ import annotations

import io
import zipfile
from collections.abc import Iterator

import docx
from anyio import to_thread
from docx.opc.exceptions import OpcError
from docx.table import Table
from docx.text.paragraph import Paragraph
from pypdf import PdfReader
from pypdf.errors import PdfReadError

from app.domain.syllabus import (
    DocumentEncryptedError,
    DocumentHasNoTextError,
    DocumentKind,
    DocumentUnreadableError,
)


# both libraries are synchronous and cpu-bound, so they run off the event loop
class SyllabusDocumentReader:
    def __init__(self, *, maximum_pages: int, maximum_characters: int) -> None:
        self._maximum_pages = maximum_pages
        self._maximum_characters = maximum_characters

    async def read(self, content: bytes, kind: DocumentKind) -> str:
        reader = self._read_pdf if kind is DocumentKind.pdf else self._read_docx
        return await to_thread.run_sync(reader, content)

    # a page cap means nothing here: a docx has no pages until something lays it
    # out, so the character cap is the only bound this side
    def _read_docx(self, content: bytes) -> str:
        try:
            document = docx.Document(io.BytesIO(content))
        except (OpcError, zipfile.BadZipFile, ValueError, KeyError) as error:
            raise DocumentUnreadableError(
                "document_unreadable",
                "The file could not be read as a Word document.",
            ) from error

        pieces: list[str] = []
        length = 0
        # the assessment table is a table, so walking paragraphs alone would
        # drop the one part of the document this exists to read
        for block in self._blocks(document):
            text = (
                block.text
                if isinstance(block, Paragraph)
                else "\n".join(self._row(row) for row in block.rows)
            )
            if not text.strip():
                continue
            pieces.append(text)
            length += len(text)
            if length >= self._maximum_characters:
                break

        return self._joined(pieces)

    # a merged cell is reported once per grid column it spans, so a heading
    # across six columns arrives six times; consecutive repeats are that, not
    # content, and an empty cell carries nothing a reader needs
    def _row(self, row: object) -> str:
        seen: list[str] = []
        for cell in row.cells:  # type: ignore[attr-defined]
            text = cell.text.strip()
            if not text or (seen and seen[-1] == text):
                continue
            seen.append(text)
        return " | ".join(seen)

    # python-docx exposes paragraphs and tables separately, and a syllabus needs
    # them interleaved in the order they were written
    def _blocks(self, document: docx.document.Document) -> Iterator[Paragraph | Table]:
        body = document.element.body
        for child in body.iterchildren():
            if child.tag.endswith("}p"):
                yield Paragraph(child, document)
            elif child.tag.endswith("}tbl"):
                yield Table(child, document)

    def _read_pdf(self, content: bytes) -> str:
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

        return self._joined(pieces)

    def _joined(self, pieces: list[str]) -> str:
        joined = "\n".join(pieces)[: self._maximum_characters]
        if not joined.strip():
            raise DocumentHasNoTextError(
                "document_has_no_text",
                "The file has no text to read; a scan cannot be imported.",
            )
        return joined

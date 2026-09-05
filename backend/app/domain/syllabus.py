from __future__ import annotations

import unicodedata
from dataclasses import dataclass, field
from typing import Protocol

from app.domain.errors import AppError, ValidationError

# a syllabus lists a handful of assessments; anything beyond this is a document
# that would grow a stored transcript without bound
MAXIMUM_ASSESSMENTS = 40

MAXIMUM_TITLE_LENGTH = 120
MAXIMUM_CODE_LENGTH = 24
MAXIMUM_NAME_LENGTH = 80
MAXIMUM_TERM_LENGTH = 60
MAXIMUM_UNIT_LENGTH = 16

# a course cannot be worth more than this, and a weight is a percentage
MAXIMUM_CREDITS = 24.0
MAXIMUM_WEIGHT = 100.0

# bidi overrides and zero-width characters can make a name render as something
# other than what is stored, so they never survive extraction
_BIDI_AND_INVISIBLE = frozenset(
    "\u200b\u200c\u200d\u200e\u200f"  # zero width, and the plain marks
    "\u202a\u202b\u202c\u202d\u202e"  # embedding and override
    "\u2066\u2067\u2068\u2069"  # isolates
    "\ufeff"  # byte order mark
)


def sanitize_text(value: str | None, *, limit: int) -> str | None:
    if value is None:
        return None
    # normalizing first means a decomposed character cannot smuggle a control
    # through as a combining mark once the client recomposes it
    normalized = unicodedata.normalize("NFC", value)
    kept = [
        character
        for character in normalized
        if character not in _BIDI_AND_INVISIBLE
        and (
            character in "\t\n\r" or unicodedata.category(character) not in {"Cc", "Cf"}
        )
    ]
    collapsed = " ".join("".join(kept).split())
    if not collapsed:
        return None
    return collapsed[:limit]


@dataclass(frozen=True, slots=True)
class AssessmentDraft:
    name: str
    weight: float


@dataclass(frozen=True, slots=True)
class SyllabusDraft:
    code: str | None = None
    title: str | None = None
    credits: float | None = None
    credit_unit: str | None = None
    term: str | None = None
    assessments: list[AssessmentDraft] = field(default_factory=list)

    @property
    def total_weight(self) -> float:
        return sum(assessment.weight for assessment in self.assessments)


def _finite(value: float | None) -> float | None:
    # a model can return a string that parses to inf or nan, and either would
    # travel through json as a value no client can use
    if value is None:
        return None
    if value != value or value in (float("inf"), float("-inf")):
        return None
    return value


def _clean_weight(value: float | None) -> float | None:
    weight = _finite(value)
    if weight is None or weight <= 0 or weight > MAXIMUM_WEIGHT:
        return None
    return round(weight, 4)


def _clean_credits(value: float | None) -> float | None:
    count = _finite(value)
    if count is None or count <= 0 or count > MAXIMUM_CREDITS:
        return None
    return round(count, 4)


def build_draft(
    *,
    code: str | None,
    title: str | None,
    credit_count: float | None,
    credit_unit: str | None,
    term: str | None,
    assessments: list[tuple[str | None, float | None]],
) -> SyllabusDraft:
    """Turn extracted values into a draft, dropping whatever cannot be trusted."""
    cleaned: list[AssessmentDraft] = []
    for name, weight in assessments[:MAXIMUM_ASSESSMENTS]:
        safe_name = sanitize_text(name, limit=MAXIMUM_NAME_LENGTH)
        safe_weight = _clean_weight(weight)
        # a row missing either half is not an assessment, and inventing the
        # missing half is what turns a schedule row into a phantom assignment
        if safe_name is None or safe_weight is None:
            continue
        cleaned.append(AssessmentDraft(name=safe_name, weight=safe_weight))

    return SyllabusDraft(
        code=sanitize_text(code, limit=MAXIMUM_CODE_LENGTH),
        title=sanitize_text(title, limit=MAXIMUM_TITLE_LENGTH),
        credits=_clean_credits(credit_count),
        credit_unit=sanitize_text(credit_unit, limit=MAXIMUM_UNIT_LENGTH),
        term=sanitize_text(term, limit=MAXIMUM_TERM_LENGTH),
        assessments=cleaned,
    )


class DocumentTooLargeError(ValidationError):
    status_code = 413
    code = "document_too_large"


class DocumentUnreadableError(ValidationError):
    code = "document_unreadable"


def require_pdf(content: bytes, *, maximum_bytes: int) -> bytes:
    if not content:
        raise DocumentUnreadableError(
            "document_empty",
            "The file is empty.",
        )
    if len(content) > maximum_bytes:
        raise DocumentTooLargeError(
            "document_too_large",
            "The file is larger than this service accepts.",
        )
    # the declared content type is a claim the caller makes about its own upload
    if not content.startswith(b"%PDF-"):
        raise DocumentUnreadableError(
            "document_not_a_pdf",
            "The file is not a PDF.",
        )
    return content


class DocumentEncryptedError(ValidationError):
    code = "document_encrypted"


class DocumentHasNoTextError(ValidationError):
    code = "document_has_no_text"


class ExtractionUnavailableError(AppError):
    status_code = 503
    code = "extraction_unavailable"


class RateLimitedError(AppError):
    status_code = 429
    code = "rate_limited"


class DocumentReader(Protocol):
    async def read(self, content: bytes) -> str: ...


class SyllabusExtractor(Protocol):
    async def extract(self, text: str) -> SyllabusDraft: ...


class RateLimiter(Protocol):
    # raises rather than returning a verdict, so a caller cannot forget to look
    async def claim(self, key: str) -> None: ...


class DraftStore(Protocol):
    async def remembered(self, key: str) -> SyllabusDraft | None: ...

    async def remember(self, key: str, draft: SyllabusDraft) -> None: ...

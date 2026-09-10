from __future__ import annotations

import pytest

from app.domain.syllabus import (
    MAXIMUM_ASSESSMENTS,
    MAXIMUM_NAME_LENGTH,
    DocumentKind,
    DocumentTooLargeError,
    DocumentUnreadableError,
    SyllabusDraft,
    build_draft,
    require_supported_document,
    sanitize_text,
)

# a right-to-left override, a zero width space, an isolate and a byte order mark
CONTROL_AND_BIDI = "‮​⁦﻿"


def _draft(**overrides: object) -> SyllabusDraft:
    defaults: dict[str, object] = {
        "code": "MATH 273",
        "title": "Linear Algebra",
        "credit_count": 8.0,
        "credit_unit": "ECTS",
        "term": "Fall 2026",
        "assessments": [("Midterm", 40.0)],
    }
    return build_draft(**{**defaults, **overrides})  # type: ignore[arg-type]


def test_a_sanitized_string_carries_no_control_or_bidi_character() -> None:
    cleaned = sanitize_text(
        f"Linear{CONTROL_AND_BIDI} Algebra\x00\x1b",
        limit=MAXIMUM_NAME_LENGTH,
    )

    assert cleaned == "Linear Algebra"
    for character in CONTROL_AND_BIDI + "\x00\x1b":
        assert character not in (cleaned or "")


def test_sanitizing_collapses_whitespace_and_caps_length() -> None:
    assert sanitize_text("  Linear \t\n  Algebra  ", limit=80) == "Linear Algebra"
    assert sanitize_text("x" * 500, limit=10) == "x" * 10


def test_a_string_that_is_only_noise_becomes_nothing() -> None:
    assert sanitize_text("", limit=10) is None
    assert sanitize_text("   ", limit=10) is None
    assert sanitize_text(CONTROL_AND_BIDI, limit=10) is None
    assert sanitize_text(None, limit=10) is None


@pytest.mark.parametrize(
    "weight",
    [0.0, -5.0, 100.1, 1e309, float("nan"), None],
)
def test_an_assessment_without_a_usable_weight_is_dropped(
    weight: float | None,
) -> None:
    assert _draft(assessments=[("Midterm", weight)]).assessments == []


def test_an_assessment_without_a_name_is_dropped() -> None:
    # a schedule row names work but carries no weight of its own, and a weight
    # with nothing to call it is not an assignment either
    assert _draft(assessments=[(None, 40.0), ("   ", 20.0)]).assessments == []


def test_the_number_of_assessments_is_capped() -> None:
    many = [(f"Task {n}", 1.0) for n in range(MAXIMUM_ASSESSMENTS * 3)]

    assert len(_draft(assessments=many).assessments) == MAXIMUM_ASSESSMENTS


@pytest.mark.parametrize("count", [0.0, -1.0, 25.0, float("inf"), float("nan")])
def test_credits_outside_the_possible_range_are_dropped(count: float) -> None:
    assert _draft(credit_count=count).credits is None


def test_credits_are_never_converted_between_systems() -> None:
    # 8 ECTS is not 8 local credits, and the ratio is an institutional rule
    draft = _draft(credit_count=8.0, credit_unit="ECTS")

    assert draft.credits == 8.0
    assert draft.credit_unit == "ECTS"


def test_weights_over_budget_are_reported_rather_than_scaled() -> None:
    draft = _draft(assessments=[("Midterm", 70.0), ("Final", 70.0)])

    assert draft.total_weight == 140.0
    assert len(draft.assessments) == 2


def test_a_file_of_an_unsupported_type_is_refused() -> None:
    with pytest.raises(DocumentUnreadableError):
        require_supported_document(b"GIF89a not a document", maximum_bytes=1_000)
    with pytest.raises(DocumentUnreadableError):
        require_supported_document(b"", maximum_bytes=1_000)


def test_the_kind_comes_from_the_bytes_not_from_what_was_claimed() -> None:
    _, pdf = require_supported_document(b"%PDF-1.4 body", maximum_bytes=1_000)
    _, docx = require_supported_document(b"PK\x03\x04 zip body", maximum_bytes=1_000)

    assert pdf is DocumentKind.pdf
    assert docx is DocumentKind.docx


def test_an_oversized_file_is_refused_before_it_is_parsed() -> None:
    with pytest.raises(DocumentTooLargeError):
        require_supported_document(b"%PDF-" + b"x" * 5_000, maximum_bytes=1_000)

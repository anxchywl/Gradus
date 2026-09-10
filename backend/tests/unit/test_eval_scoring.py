from __future__ import annotations

from typing import Any

from app.domain.syllabus import AssessmentDraft, SyllabusDraft
from evals.scoring import normalize_code, score_case, similar


def _draft(**overrides: Any) -> SyllabusDraft:
    base: dict[str, Any] = {
        "code": "MATH 273",
        "title": "Linear Algebra with Applications",
        "credits": 8.0,
        "credit_unit": "ECTS",
        "term": "Fall 2026",
        "assessments": [
            AssessmentDraft(name="Midterm exam", weight=20.0),
            AssessmentDraft(name="Final exam", weight=40.0),
            AssessmentDraft(name="Homework", weight=40.0),
        ],
    }
    base.update(overrides)
    return SyllabusDraft(**base)


def _expected(**overrides: Any) -> dict[str, Any]:
    base: dict[str, Any] = {
        "code": "MATH 273",
        "title": "Linear Algebra with Applications",
        "credits": 8,
        "credit_unit": "ECTS",
        "term": "Fall 2026",
        "assessments": [
            {"name": "Midterm exam", "weight": 20},
            {"name": "Final exam", "weight": 40},
            {"name": "Homework", "weight": 40},
        ],
    }
    base.update(overrides)
    return base


def _score(draft: SyllabusDraft, expected: dict[str, Any] | None = None) -> Any:
    return score_case(
        case="c",
        template="t",
        expected=expected if expected is not None else _expected(),
        draft=draft,
        input_tokens=1_000,
        output_tokens=100,
        seconds=1.0,
    )


def test_a_document_read_correctly_is_exact() -> None:
    assert _score(_draft()).verdict == "exact"


def test_the_right_table_read_under_different_row_names_still_counts() -> None:
    score = _score(
        _draft(
            assessments=[
                AssessmentDraft(name="Midterm", weight=20.0),
                AssessmentDraft(name="Final", weight=40.0),
                AssessmentDraft(name="Problem sets", weight=40.0),
            ]
        )
    )

    # the weights identify the table; a row named differently is not a wrong table
    assert score.table.weights_matched
    assert score.verdict == "table right"
    assert score.table.name_match_rate < 1.0


def test_reading_the_weekly_schedule_instead_of_the_table_is_a_wrong_table() -> None:
    score = _score(
        _draft(
            assessments=[
                AssessmentDraft(name="Speech due", weight=5.0),
                AssessmentDraft(name="Research paper due", weight=10.0),
            ]
        )
    )

    assert not score.table.weights_matched
    assert score.verdict == "table wrong"
    assert (score.table.got_count, score.table.expected_count) == (2, 3)


def test_a_row_invented_on_top_of_the_right_ones_is_a_wrong_table() -> None:
    score = _score(
        _draft(
            assessments=[
                AssessmentDraft(name="Midterm exam", weight=20.0),
                AssessmentDraft(name="Final exam", weight=40.0),
                AssessmentDraft(name="Homework", weight=40.0),
                AssessmentDraft(name="Attendance", weight=5.0),
            ]
        )
    )

    assert not score.table.weights_matched
    assert score.table.got_total == 105.0


def test_one_row_split_into_four_is_caught_even_though_the_total_still_holds() -> None:
    score = _score(
        _draft(
            assessments=[
                AssessmentDraft(name="Midterm exam", weight=20.0),
                AssessmentDraft(name="Final exam", weight=40.0),
                AssessmentDraft(name="Module 1", weight=10.0),
                AssessmentDraft(name="Module 2", weight=10.0),
                AssessmentDraft(name="Module 3", weight=10.0),
                AssessmentDraft(name="Module 4", weight=10.0),
            ]
        )
    )

    assert score.table.got_total == score.table.expected_total
    # the totals agreeing is exactly why the totals are not what decides it
    assert not score.table.weights_matched


def test_a_field_read_wrong_does_not_hide_behind_a_correct_table() -> None:
    score = _score(_draft(title="Introduction to Something Else"))

    assert score.table.weights_matched
    assert not score.fields_matched
    assert score.verdict == "table right"


def test_a_course_code_is_compared_without_its_spacing() -> None:
    assert normalize_code("MATH273") == normalize_code("MATH 273")
    assert _score(_draft(code="MATH273")).fields_matched


def test_credits_are_compared_as_numbers_not_as_text() -> None:
    assert _score(_draft(credits=8.0), _expected(credits=8)).fields_matched
    assert not _score(_draft(credits=6.0), _expected(credits=8)).fields_matched


def test_a_missing_field_is_not_treated_as_a_match() -> None:
    assert not _score(_draft(term=None)).fields_matched


def test_a_syllabus_stating_no_assessments_is_scored_as_finding_none() -> None:
    score = _score(_draft(assessments=[]), _expected(assessments=[]))

    assert score.table.weights_matched
    assert score.verdict == "exact"


def test_similarity_tolerates_case_and_punctuation_but_not_a_different_row() -> None:
    assert similar("Midterm Exam", "midterm exam")
    assert similar("Final exam", "Final exam.")
    assert not similar("Midterm exam", "Attendance")

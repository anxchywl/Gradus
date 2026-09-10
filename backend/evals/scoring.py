from __future__ import annotations

import re
from dataclasses import dataclass
from difflib import SequenceMatcher

from app.domain.syllabus import SyllabusDraft

# two names for one row rarely agree character for character, and a row that is
# present but spelled differently is not the failure this measures
NAME_SIMILARITY = 0.8

_PUNCTUATION = re.compile(r"[^\w\s]", re.UNICODE)
_SPACES = re.compile(r"\s+")


def normalize(value: str | None) -> str:
    if value is None:
        return ""
    return _SPACES.sub(" ", _PUNCTUATION.sub(" ", value)).strip().casefold()


def normalize_code(value: str | None) -> str:
    return normalize(value).replace(" ", "")


def similar(left: str | None, right: str | None) -> bool:
    first, second = normalize(left), normalize(right)
    if first == second:
        return True
    if not first or not second:
        return False
    return SequenceMatcher(None, first, second).ratio() >= NAME_SIMILARITY


def close_enough(expected: float | None, got: float | None) -> bool:
    if expected is None or got is None:
        return expected is None and got is None
    return abs(expected - got) < 0.01


@dataclass(frozen=True)
class FieldScore:
    field: str
    expected: str
    got: str
    matched: bool


@dataclass(frozen=True)
class TableScore:
    weights_matched: bool
    expected_count: int
    got_count: int
    name_match_rate: float
    expected_total: float
    got_total: float


@dataclass(frozen=True)
class CaseScore:
    case: str
    template: str
    fields: tuple[FieldScore, ...]
    table: TableScore
    input_tokens: int
    output_tokens: int
    seconds: float

    @property
    def fields_matched(self) -> bool:
        return all(field.matched for field in self.fields)

    # the assessment table is what the import exists for, so it is graded apart
    # from the fields around it rather than averaged into them
    @property
    def verdict(self) -> str:
        if not self.table.weights_matched:
            return "table wrong"
        if self.fields_matched and self.table.name_match_rate == 1.0:
            return "exact"
        return "table right"


def score_case(
    *,
    case: str,
    template: str,
    expected: dict[str, object],
    draft: SyllabusDraft,
    input_tokens: int,
    output_tokens: int,
    seconds: float,
) -> CaseScore:
    fields = (
        FieldScore(
            "code",
            str(expected.get("code") or ""),
            draft.code or "",
            normalize_code(str(expected.get("code") or ""))
            == normalize_code(draft.code),
        ),
        FieldScore(
            "title",
            str(expected.get("title") or ""),
            draft.title or "",
            similar(str(expected.get("title") or ""), draft.title),
        ),
        FieldScore(
            "credits",
            str(expected.get("credits") or ""),
            str(draft.credits or ""),
            close_enough(_as_float(expected.get("credits")), draft.credits),
        ),
        FieldScore(
            "credit_unit",
            str(expected.get("credit_unit") or ""),
            draft.credit_unit or "",
            normalize(str(expected.get("credit_unit") or ""))
            == normalize(draft.credit_unit),
        ),
        FieldScore(
            "term",
            str(expected.get("term") or ""),
            draft.term or "",
            similar(str(expected.get("term") or ""), draft.term),
        ),
    )
    return CaseScore(
        case=case,
        template=template,
        fields=fields,
        table=score_table(expected.get("assessments") or [], draft),
        input_tokens=input_tokens,
        output_tokens=output_tokens,
        seconds=seconds,
    )


def score_table(expected_rows: object, draft: SyllabusDraft) -> TableScore:
    rows = expected_rows if isinstance(expected_rows, list) else []
    expected_weights = sorted(
        round(float(row["weight"]), 2) for row in rows if row.get("weight") is not None
    )
    got_weights = sorted(
        round(assessment.weight, 2) for assessment in draft.assessments
    )

    remaining = [assessment.name for assessment in draft.assessments]
    matched = 0
    for row in rows:
        name = row.get("name")
        found = next((got for got in remaining if similar(str(name), got)), None)
        if found is not None:
            remaining.remove(found)
            matched += 1

    return TableScore(
        weights_matched=expected_weights == got_weights,
        expected_count=len(rows),
        got_count=len(draft.assessments),
        name_match_rate=matched / len(rows) if rows else 1.0,
        expected_total=round(sum(expected_weights), 2),
        got_total=round(sum(got_weights), 2),
    )


def _as_float(value: object) -> float | None:
    if isinstance(value, int | float):
        return float(value)
    return None

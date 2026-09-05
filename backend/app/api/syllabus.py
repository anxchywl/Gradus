from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Header, Request

from app.api.errors import request_id_of
from app.api.headers import require_idempotency_key
from app.application.syllabus_service import SyllabusService
from app.dependencies import CurrentIdentity
from app.domain.syllabus import ExtractionUnavailableError, SyllabusDraft

router = APIRouter(prefix="/api/v1", tags=["syllabus"])


def _payload(draft: SyllabusDraft) -> dict[str, object]:
    return {
        "code": draft.code,
        "title": draft.title,
        "credits": draft.credits,
        "creditUnit": draft.credit_unit,
        "term": draft.term,
        "assessments": [
            {"name": assessment.name, "weight": assessment.weight}
            for assessment in draft.assessments
        ],
    }


@router.post("/syllabus-extractions", status_code=200)
async def extract_syllabus(
    request: Request,
    identity: CurrentIdentity,
    idempotency_key: Annotated[str | None, Header(alias="Idempotency-Key")] = None,
) -> dict[str, object]:
    service: SyllabusService | None = getattr(
        request.app.state,
        "syllabus_service",
        None,
    )
    if service is None:
        raise ExtractionUnavailableError(
            "extraction_unavailable",
            "Syllabus extraction is not configured.",
        )

    key = require_idempotency_key(idempotency_key)
    draft = await service.extract(
        subject=identity.external_subject,
        idempotency_key=key,
        # the body is the document itself: one file, no form parser to attack
        content=await request.body(),
    )
    return {
        "data": _payload(draft),
        "meta": {"request_id": request_id_of(request)},
    }

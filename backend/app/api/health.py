from __future__ import annotations

from fastapi import APIRouter, Request
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.api.errors import request_id_of
from app.domain.errors import ServiceUnavailableError
from app.infrastructure.db.session import DatabaseSession

router = APIRouter(tags=["health"])


@router.get("/health/live")
async def live(request: Request) -> dict[str, object]:
    return {
        "data": {"status": "ok"},
        "meta": {"request_id": request_id_of(request)},
    }


@router.get("/health/ready")
async def ready(request: Request, session: DatabaseSession) -> dict[str, object]:
    try:
        await session.execute(text("SELECT 1"))
    except SQLAlchemyError as exc:
        raise ServiceUnavailableError(
            "database_unavailable",
            "The database is not ready.",
        ) from exc
    return {
        "data": {"status": "ready"},
        "meta": {"request_id": request_id_of(request)},
    }

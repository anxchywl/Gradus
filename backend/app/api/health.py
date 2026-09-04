from __future__ import annotations

from fastapi import APIRouter, Request

from app.api.errors import request_id_of

router = APIRouter(tags=["health"])


@router.get("/health/live")
async def live(request: Request) -> dict[str, object]:
    return {
        "data": {"status": "ok"},
        "meta": {"request_id": request_id_of(request)},
    }


# the service stores nothing and calls nothing to answer a request, so there is
# no dependency to be unready for; configuration is validated at startup instead
@router.get("/health/ready")
async def ready(request: Request) -> dict[str, object]:
    return {
        "data": {"status": "ready"},
        "meta": {"request_id": request_id_of(request)},
    }

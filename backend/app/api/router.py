from __future__ import annotations

from fastapi import APIRouter

from app.api import health

router = APIRouter()
router.include_router(health.router)

# feature routers mount under /api/v1 as they are written:
#   router.include_router(courses.router, prefix="/api/v1")

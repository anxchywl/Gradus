from __future__ import annotations

from fastapi import APIRouter

from app.api import health, syllabus

router = APIRouter()
router.include_router(health.router)
router.include_router(syllabus.router)

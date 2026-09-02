from __future__ import annotations

import pytest

from app.config import AppEnvironment, AuthAdapter, Settings

BASE_ENV = {
    "APP_ENV": AppEnvironment.test,
    "DATABASE_URL": "postgresql+asyncpg://gradus:gradus@localhost:5432/gradus",
}


def settings(**overrides: object) -> Settings:
    return Settings.model_validate({**BASE_ENV, **overrides})


@pytest.fixture
def development_settings() -> Settings:
    return settings(
        AUTH_ADAPTER=AuthAdapter.development,
        DEVELOPMENT_AUTH_TOKEN="student-token-value",
        DEVELOPMENT_OPERATOR_AUTH_TOKEN="operator-token-value",
    )

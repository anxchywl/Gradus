from __future__ import annotations

import pytest
from pydantic import ValidationError as PydanticValidationError

from app.config import AppEnvironment, AuthAdapter, Settings
from tests.conftest import settings


def test_environment_defaults_to_production() -> None:
    # an omitted APP_ENV must fail closed, never open a development path
    built = Settings.model_validate(
        {"DATABASE_URL": "postgresql+asyncpg://gradus:gradus@localhost:5432/gradus"}
    )
    assert built.environment is AppEnvironment.production


def test_development_auth_is_refused_in_production() -> None:
    with pytest.raises(PydanticValidationError, match="cannot run in production"):
        settings(
            APP_ENV=AppEnvironment.production,
            AUTH_ADAPTER=AuthAdapter.development,
            DEVELOPMENT_AUTH_TOKEN="a-token",
            DEVELOPMENT_OPERATOR_AUTH_TOKEN="another-token",
        )


def test_development_auth_requires_both_tokens() -> None:
    with pytest.raises(PydanticValidationError, match="DEVELOPMENT_AUTH_TOKEN"):
        settings(AUTH_ADAPTER=AuthAdapter.development)
    with pytest.raises(
        PydanticValidationError, match="DEVELOPMENT_OPERATOR_AUTH_TOKEN"
    ):
        settings(AUTH_ADAPTER=AuthAdapter.development, DEVELOPMENT_AUTH_TOKEN="a-token")


def test_student_and_operator_tokens_must_differ() -> None:
    with pytest.raises(PydanticValidationError, match="must differ"):
        settings(
            AUTH_ADAPTER=AuthAdapter.development,
            DEVELOPMENT_AUTH_TOKEN="same-token",
            DEVELOPMENT_OPERATOR_AUTH_TOKEN="same-token",
        )


def test_api_documentation_is_refused_in_production() -> None:
    with pytest.raises(
        PydanticValidationError, match="cannot be enabled in production"
    ):
        settings(APP_ENV=AppEnvironment.production, API_DOCS_ENABLED=True)


def test_wildcard_cors_origin_is_refused() -> None:
    with pytest.raises(PydanticValidationError, match="wildcard CORS"):
        settings(CORS_ALLOWED_ORIGINS="*")


@pytest.mark.parametrize(
    "origin",
    [
        "https://example.edu/path",
        "https://example.edu?q=1",
        "https://user:pass@example.edu",
        "ftp://example.edu",
        "not-a-url",
    ],
)
def test_malformed_cors_origins_are_refused(origin: str) -> None:
    with pytest.raises(PydanticValidationError, match="CORS origins"):
        settings(CORS_ALLOWED_ORIGINS=origin)


def test_plain_http_cors_origin_is_refused_in_production() -> None:
    with pytest.raises(PydanticValidationError, match="HTTPS in production"):
        settings(
            APP_ENV=AppEnvironment.production,
            CORS_ALLOWED_ORIGINS="http://example.edu",
        )


def test_page_size_bounds_are_consistent() -> None:
    with pytest.raises(PydanticValidationError, match="cannot exceed"):
        settings(DEFAULT_PAGE_SIZE=50, MAXIMUM_PAGE_SIZE=10)


def test_request_body_limit_is_bounded() -> None:
    with pytest.raises(PydanticValidationError):
        settings(REQUEST_BODY_MAX_BYTES=1)

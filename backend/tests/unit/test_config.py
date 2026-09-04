from __future__ import annotations

import pytest
from pydantic import ValidationError as PydanticValidationError

from app.config import AppEnvironment, AuthAdapter, Settings
from tests.conftest import settings


def test_environment_defaults_to_production() -> None:
    # an omitted APP_ENV must fail closed, never open a development path
    built = Settings.model_validate({})
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


def test_superapp_auth_needs_both_an_issuer_and_a_key() -> None:
    # half a configuration must leave the host resolver closed, not open
    issuer_only = settings(SUPERAPP_JWT_ISSUER="https://superapp.example.edu")
    key_only = settings(SUPERAPP_JWT_SECRET="s" * 32)

    assert issuer_only.superapp_auth_configured is False
    assert key_only.superapp_auth_configured is False


def test_an_unlisted_signing_algorithm_is_refused() -> None:
    for algorithm in ("none", "NONE", "PS256"):
        with pytest.raises(PydanticValidationError, match="not an allowed algorithm"):
            settings(
                SUPERAPP_JWT_ISSUER="https://superapp.example.edu",
                SUPERAPP_JWT_ALGORITHM=algorithm,
                SUPERAPP_JWT_SECRET="s" * 32,
            )


def test_a_public_key_cannot_be_used_as_an_hmac_secret() -> None:
    with pytest.raises(PydanticValidationError, match="cannot be used with an HS"):
        settings(
            SUPERAPP_JWT_ISSUER="https://superapp.example.edu",
            SUPERAPP_JWT_ALGORITHM="HS256",
            SUPERAPP_JWT_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----",
        )


def test_a_short_shared_secret_is_refused() -> None:
    with pytest.raises(PydanticValidationError, match="at least 32 bytes"):
        settings(
            SUPERAPP_JWT_ISSUER="https://superapp.example.edu",
            SUPERAPP_JWT_ALGORITHM="HS256",
            SUPERAPP_JWT_SECRET="too-short",
        )


def test_an_asymmetric_algorithm_requires_a_public_key() -> None:
    with pytest.raises(PydanticValidationError, match="PUBLIC_KEY is required"):
        settings(
            SUPERAPP_JWT_ISSUER="https://superapp.example.edu",
            SUPERAPP_JWT_ALGORITHM="RS256",
            SUPERAPP_JWT_SECRET="s" * 32,
        )


def test_an_operator_claim_and_its_value_are_set_together() -> None:
    with pytest.raises(PydanticValidationError, match="together or not at all"):
        settings(
            SUPERAPP_JWT_ISSUER="https://superapp.example.edu",
            SUPERAPP_JWT_ALGORITHM="HS256",
            SUPERAPP_JWT_SECRET="s" * 32,
            SUPERAPP_OPERATOR_CLAIM="role",
        )

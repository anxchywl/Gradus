from __future__ import annotations

from enum import StrEnum
from functools import lru_cache
from urllib.parse import urlsplit

from pydantic import Field, SecretStr, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class AppEnvironment(StrEnum):
    development = "development"
    test = "test"
    production = "production"


SYLLABUS_EXTRACTION_PATH = "/api/v1/syllabus-extractions"

# "none" is never here, and neither is any algorithm the issuer has not agreed
SUPERAPP_ALGORITHMS = frozenset(
    {"RS256", "RS384", "RS512", "ES256", "ES384", "ES512", "HS256", "HS384", "HS512"}
)


class AuthAdapter(StrEnum):
    host = "host"
    development = "development"


class Settings(BaseSettings):
    # the environment is authoritative and defaults to strict, so it fails closed
    environment: AppEnvironment = Field(
        default=AppEnvironment.production,
        alias="APP_ENV",
    )
    auth_adapter: AuthAdapter = Field(default=AuthAdapter.host, alias="AUTH_ADAPTER")

    development_auth_token: SecretStr | None = Field(
        default=None,
        alias="DEVELOPMENT_AUTH_TOKEN",
    )
    development_auth_subject: str = Field(
        default="student-a",
        alias="DEVELOPMENT_AUTH_SUBJECT",
        min_length=1,
        max_length=255,
    )
    development_operator_auth_token: SecretStr | None = Field(
        default=None,
        alias="DEVELOPMENT_OPERATOR_AUTH_TOKEN",
    )
    development_operator_auth_subject: str = Field(
        default="operator-a",
        alias="DEVELOPMENT_OPERATOR_AUTH_SUBJECT",
        min_length=1,
        max_length=255,
    )

    # the superapp issues the token, this service only verifies it. with no
    # issuer and no key the host resolver stays closed rather than open
    superapp_jwt_issuer: str | None = Field(default=None, alias="SUPERAPP_JWT_ISSUER")
    superapp_jwt_audience: str | None = Field(
        default=None,
        alias="SUPERAPP_JWT_AUDIENCE",
    )
    superapp_jwt_algorithm: str = Field(
        default="RS256",
        alias="SUPERAPP_JWT_ALGORITHM",
    )
    superapp_jwt_public_key: str | None = Field(
        default=None,
        alias="SUPERAPP_JWT_PUBLIC_KEY",
    )
    superapp_jwt_secret: SecretStr | None = Field(
        default=None,
        alias="SUPERAPP_JWT_SECRET",
    )
    superapp_subject_claim: str = Field(
        default="sub",
        alias="SUPERAPP_SUBJECT_CLAIM",
        min_length=1,
        max_length=64,
    )
    superapp_operator_claim: str | None = Field(
        default=None,
        alias="SUPERAPP_OPERATOR_CLAIM",
    )
    superapp_operator_value: str | None = Field(
        default=None,
        alias="SUPERAPP_OPERATOR_VALUE",
    )

    cors_allowed_origins: list[str] = Field(
        default_factory=list,
        alias="CORS_ALLOWED_ORIGINS",
    )
    api_docs_enabled: bool = Field(default=False, alias="API_DOCS_ENABLED")
    request_body_max_bytes: int = Field(
        default=150_000,
        alias="REQUEST_BODY_MAX_BYTES",
        ge=1_024,
        le=10 * 1_024 * 1_024,
    )
    # syllabus extraction. with no key the endpoint refuses rather than the
    # service failing to start: health must stay answerable either way
    anthropic_api_key: SecretStr | None = Field(
        default=None,
        alias="ANTHROPIC_API_KEY",
    )
    syllabus_model: str = Field(
        default="claude-haiku-4-5",
        alias="SYLLABUS_MODEL",
        min_length=1,
        max_length=128,
    )
    syllabus_timeout_seconds: float = Field(
        default=45.0,
        alias="SYLLABUS_TIMEOUT_SECONDS",
        gt=0,
        le=300,
    )
    syllabus_output_tokens: int = Field(
        default=4_000,
        alias="SYLLABUS_OUTPUT_TOKENS",
        ge=256,
        le=32_000,
    )
    # a syllabus is a few hundred kilobytes; this route is the only one that
    # accepts more than the global body cap
    syllabus_document_max_bytes: int = Field(
        default=4 * 1_024 * 1_024,
        alias="SYLLABUS_DOCUMENT_MAX_BYTES",
        ge=1_024,
        le=16 * 1_024 * 1_024,
    )
    syllabus_document_max_pages: int = Field(
        default=60,
        alias="SYLLABUS_DOCUMENT_MAX_PAGES",
        ge=1,
        le=500,
    )
    syllabus_document_max_characters: int = Field(
        default=120_000,
        alias="SYLLABUS_DOCUMENT_MAX_CHARACTERS",
        ge=1_000,
        le=1_000_000,
    )
    syllabus_rate_limit: int = Field(
        default=20,
        alias="SYLLABUS_RATE_LIMIT",
        ge=1,
        le=1_000,
    )
    syllabus_rate_window_seconds: float = Field(
        default=3_600.0,
        alias="SYLLABUS_RATE_WINDOW_SECONDS",
        gt=0,
    )

    default_page_size: int = Field(default=20, alias="DEFAULT_PAGE_SIZE", ge=1, le=100)
    maximum_page_size: int = Field(default=50, alias="MAXIMUM_PAGE_SIZE", ge=1, le=200)

    @property
    def superapp_auth_configured(self) -> bool:
        has_key = bool(self.superapp_jwt_public_key) or (
            self.superapp_jwt_secret is not None
        )
        return bool(self.superapp_jwt_issuer) and has_key

    @property
    def syllabus_extraction_configured(self) -> bool:
        return self.anthropic_api_key is not None

    # only the upload route may exceed the global cap, and it says so here
    # rather than in the middleware that enforces it
    def body_limit_for(self, path: str) -> int:
        if path == SYLLABUS_EXTRACTION_PATH:
            return self.syllabus_document_max_bytes
        return self.request_body_max_bytes

    @field_validator("cors_allowed_origins", mode="before")
    @classmethod
    def parse_origins(cls, value: object) -> list[str]:
        if value is None:
            return []
        if isinstance(value, list):
            return [str(origin).strip() for origin in value if str(origin).strip()]
        if isinstance(value, str):
            return [origin.strip() for origin in value.split(",") if origin.strip()]
        raise ValueError("CORS_ALLOWED_ORIGINS must be a comma-separated list")

    @model_validator(mode="after")
    def guard_development_features(self) -> Settings:
        if self.auth_adapter == AuthAdapter.development:
            if self.environment == AppEnvironment.production:
                raise ValueError("development authentication cannot run in production")
            if self.development_auth_token is None:
                raise ValueError(
                    "DEVELOPMENT_AUTH_TOKEN is required for development authentication"
                )
            if self.development_operator_auth_token is None:
                raise ValueError(
                    "DEVELOPMENT_OPERATOR_AUTH_TOKEN is required for "
                    "development authentication"
                )
            if (
                self.development_auth_token.get_secret_value()
                == self.development_operator_auth_token.get_secret_value()
            ):
                raise ValueError("development student and operator tokens must differ")
        if self.environment == AppEnvironment.production and self.api_docs_enabled:
            raise ValueError("API documentation cannot be enabled in production")
        if "*" in self.cors_allowed_origins:
            raise ValueError("wildcard CORS origins are not allowed")
        for origin in self.cors_allowed_origins:
            parsed = urlsplit(origin)
            if (
                parsed.scheme not in {"http", "https"}
                or not parsed.netloc
                or parsed.username is not None
                or parsed.password is not None
                or parsed.path
                or parsed.query
                or parsed.fragment
            ):
                raise ValueError("CORS origins must be HTTP origins without paths")
            if (
                self.environment == AppEnvironment.production
                and parsed.scheme != "https"
            ):
                raise ValueError("CORS origins must use HTTPS in production")
        if self.superapp_auth_configured:
            algorithm = self.superapp_jwt_algorithm.upper()
            if algorithm not in SUPERAPP_ALGORITHMS:
                raise ValueError("SUPERAPP_JWT_ALGORITHM is not an allowed algorithm")
            # an rsa public key handed to an hmac verifier is the classic
            # algorithm-confusion forgery, so the family must match the material
            if algorithm.startswith("HS"):
                if self.superapp_jwt_public_key:
                    raise ValueError(
                        "SUPERAPP_JWT_PUBLIC_KEY cannot be used with an HS algorithm"
                    )
                secret = self.superapp_jwt_secret
                if secret is None:
                    raise ValueError(
                        "SUPERAPP_JWT_SECRET is required for an HS algorithm"
                    )
                if len(secret.get_secret_value().encode()) < 32:
                    raise ValueError(
                        "SUPERAPP_JWT_SECRET must be at least 32 bytes for an "
                        "HS algorithm"
                    )
            elif not self.superapp_jwt_public_key:
                raise ValueError(
                    "SUPERAPP_JWT_PUBLIC_KEY is required for an asymmetric algorithm"
                )
            if bool(self.superapp_operator_claim) != bool(self.superapp_operator_value):
                raise ValueError(
                    "SUPERAPP_OPERATOR_CLAIM and SUPERAPP_OPERATOR_VALUE are set "
                    "together or not at all"
                )
        if self.default_page_size > self.maximum_page_size:
            raise ValueError("DEFAULT_PAGE_SIZE cannot exceed MAXIMUM_PAGE_SIZE")
        return self

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        populate_by_name=True,
    )


@lru_cache
def get_settings() -> Settings:
    return Settings.model_validate({})

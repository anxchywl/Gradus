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


class AuthAdapter(StrEnum):
    host = "host"
    development = "development"


class Settings(BaseSettings):
    # the environment is authoritative and defaults to strict, so it fails closed
    environment: AppEnvironment = Field(
        default=AppEnvironment.production,
        alias="APP_ENV",
    )
    database_url: str = Field(alias="DATABASE_URL")
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
    default_page_size: int = Field(default=20, alias="DEFAULT_PAGE_SIZE", ge=1, le=100)
    maximum_page_size: int = Field(default=50, alias="MAXIMUM_PAGE_SIZE", ge=1, le=200)

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

from __future__ import annotations

import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

from app.config import AppEnvironment, AuthAdapter, Settings

BASE_ENV = {
    "APP_ENV": AppEnvironment.test,
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


HOST_ISSUER = "https://host.example.edu"
HOST_AUDIENCE = "gradus"

# one key pair for the whole session, generating rsa material is not free
_signing_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
_other_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)


def public_pem(key: rsa.RSAPrivateKey) -> str:
    return (
        key.public_key()
        .public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.SubjectPublicKeyInfo,
        )
        .decode()
    )


@pytest.fixture
def host_signing_key() -> rsa.RSAPrivateKey:
    return _signing_key


@pytest.fixture
def host_foreign_key() -> rsa.RSAPrivateKey:
    return _other_key


@pytest.fixture
def host_settings() -> Settings:
    return settings(
        HOST_JWT_ISSUER=HOST_ISSUER,
        HOST_JWT_AUDIENCE=HOST_AUDIENCE,
        HOST_JWT_ALGORITHM="RS256",
        HOST_JWT_PUBLIC_KEY=public_pem(_signing_key),
    )

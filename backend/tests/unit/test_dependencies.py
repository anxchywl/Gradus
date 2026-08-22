from __future__ import annotations

import pytest
from fastapi import APIRouter
from fastapi.testclient import TestClient

from app.config import Settings
from app.dependencies import CurrentIdentity, OperatorIdentity
from app.main import create_app
from tests.conftest import settings

guarded = APIRouter()


@guarded.get("/api/v1/whoami")
async def _whoami(identity: CurrentIdentity) -> dict[str, object]:
    return {"subject": identity.external_subject, "operator": identity.is_operator}


@guarded.get("/api/v1/operations")
async def _operations(identity: OperatorIdentity) -> dict[str, str]:
    return {"subject": identity.external_subject}


def _client(active: Settings) -> TestClient:
    application = create_app(active)
    application.include_router(guarded)
    application.state.principal_resolver = None  # replaced by lifespan on startup
    return TestClient(application, raise_server_exceptions=False)


@pytest.fixture
def client(development_settings: Settings) -> TestClient:
    return _client(development_settings)


def test_a_missing_credential_is_unauthorized(client: TestClient) -> None:
    with client:
        response = client.get("/api/v1/whoami")
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "token_missing"


def test_a_non_bearer_scheme_is_unauthorized(client: TestClient) -> None:
    with client:
        response = client.get(
            "/api/v1/whoami",
            headers={"Authorization": "Basic student-token-value"},
        )
    assert response.status_code == 401


def test_an_unknown_token_is_unauthorized(client: TestClient) -> None:
    with client:
        response = client.get(
            "/api/v1/whoami",
            headers={"Authorization": "Bearer not-a-real-token"},
        )
    assert response.status_code == 401


def test_a_student_token_resolves_to_a_non_operator(client: TestClient) -> None:
    with client:
        response = client.get(
            "/api/v1/whoami",
            headers={"Authorization": "Bearer student-token-value"},
        )
    assert response.status_code == 200
    assert response.json()["operator"] is False


def test_a_student_may_not_reach_an_operator_endpoint(client: TestClient) -> None:
    with client:
        response = client.get(
            "/api/v1/operations",
            headers={"Authorization": "Bearer student-token-value"},
        )
    assert response.status_code == 403
    assert response.json()["error"]["code"] == "operator_required"


def test_an_operator_token_reaches_an_operator_endpoint(client: TestClient) -> None:
    with client:
        response = client.get(
            "/api/v1/operations",
            headers={"Authorization": "Bearer operator-token-value"},
        )
    assert response.status_code == 200


def test_a_client_cannot_claim_operator_status(client: TestClient) -> None:
    # role comes from the resolved credential; nothing the caller sends can
    # promote it, whatever header or parameter it arrives in
    with client:
        response = client.get(
            "/api/v1/operations?is_operator=true",
            headers={
                "Authorization": "Bearer student-token-value",
                "X-Is-Operator": "true",
                "X-Role": "operator",
            },
        )
    assert response.status_code == 403


def test_the_host_adapter_rejects_every_token() -> None:
    with _client(settings()) as client:
        response = client.get(
            "/api/v1/whoami",
            headers={"Authorization": "Bearer anything-at-all"},
        )
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "host_auth_unconfigured"

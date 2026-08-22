from __future__ import annotations

import pytest

from app.config import Settings
from app.domain.errors import UnauthorizedError
from app.infrastructure.auth import create_principal_resolver
from app.infrastructure.auth.resolvers import (
    DevelopmentPrincipalResolver,
    UnavailableHostPrincipalResolver,
)
from tests.conftest import settings


async def test_host_resolver_rejects_every_token() -> None:
    resolver = create_principal_resolver(settings())
    assert isinstance(resolver, UnavailableHostPrincipalResolver)
    with pytest.raises(UnauthorizedError):
        await resolver.resolve("any-token-at-all")


async def test_development_resolver_distinguishes_the_two_identities(
    development_settings: Settings,
) -> None:
    resolver = create_principal_resolver(development_settings)
    assert isinstance(resolver, DevelopmentPrincipalResolver)

    student = await resolver.resolve("student-token-value")
    operator = await resolver.resolve("operator-token-value")

    assert student.is_operator is False
    assert operator.is_operator is True
    assert student.external_subject != operator.external_subject


async def test_development_resolver_rejects_an_unknown_token(
    development_settings: Settings,
) -> None:
    resolver = create_principal_resolver(development_settings)
    with pytest.raises(UnauthorizedError):
        await resolver.resolve("not-a-configured-token")


async def test_development_resolver_rejects_an_empty_token(
    development_settings: Settings,
) -> None:
    resolver = create_principal_resolver(development_settings)
    with pytest.raises(UnauthorizedError):
        await resolver.resolve("")

from __future__ import annotations

from hmac import compare_digest

from app.config import AuthAdapter, Settings
from app.domain.auth import AccountStatus, ExternalIdentity, TokenIdentityResolver
from app.domain.errors import UnauthorizedError


class UnavailableHostPrincipalResolver:
    """Placeholder for <AUTHENTICATION_HOST>.

    It rejects every token on purpose: the issuer, audience, signature and
    claims are not decided yet. Replace it before anything is deployed; do not
    fall back to the development resolver.
    """

    async def resolve(self, token: str) -> ExternalIdentity:
        raise UnauthorizedError(
            "host_auth_unconfigured",
            "The host authentication adapter is not configured.",
        )


class DevelopmentPrincipalResolver:
    """Local development only. Config refuses to build this in production."""

    def __init__(self, settings: Settings) -> None:
        student = settings.development_auth_token
        operator = settings.development_operator_auth_token
        if student is None or operator is None:
            raise ValueError("development authentication tokens are missing")
        self._student_token = student.get_secret_value()
        self._operator_token = operator.get_secret_value()
        self._student_subject = settings.development_auth_subject
        self._operator_subject = settings.development_operator_auth_subject

    async def resolve(self, token: str) -> ExternalIdentity:
        is_student = bool(token) and compare_digest(token, self._student_token)
        is_operator = bool(token) and compare_digest(token, self._operator_token)
        if not is_student and not is_operator:
            raise UnauthorizedError(
                "token_invalid",
                "The development authentication token is invalid.",
            )
        return ExternalIdentity(
            external_issuer="gpa-development",
            external_subject=(
                self._operator_subject if is_operator else self._student_subject
            ),
            account_status=AccountStatus.active,
            is_operator=is_operator,
        )


def create_principal_resolver(settings: Settings) -> TokenIdentityResolver:
    if settings.auth_adapter == AuthAdapter.development:
        return DevelopmentPrincipalResolver(settings)
    return UnavailableHostPrincipalResolver()

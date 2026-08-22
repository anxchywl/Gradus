from __future__ import annotations

import pytest

from app.api.headers import require_expected_version, require_idempotency_key
from app.domain.errors import ValidationError


@pytest.mark.parametrize(
    "value",
    ["a" * 16, "A-Z_0.9:key-value", "x" * 128],
)
def test_a_well_formed_idempotency_key_is_accepted(value: str) -> None:
    assert require_idempotency_key(value) == value


@pytest.mark.parametrize(
    "value",
    [
        None,
        "",
        "too-short",
        "x" * 129,
        "has spaces in it here",
        "has/slashes/in/it/here",
        "unicodeキーvalue1234",
    ],
)
def test_a_malformed_idempotency_key_is_refused(value: str | None) -> None:
    with pytest.raises(ValidationError) as failure:
        require_idempotency_key(value)
    assert failure.value.code == "idempotency_key_invalid"


@pytest.mark.parametrize(("value", "expected"), [('"3"', 3), ("3", 3), ('"17"', 17)])
def test_a_well_formed_expected_version_is_parsed(value: str, expected: int) -> None:
    assert require_expected_version(value) == expected


@pytest.mark.parametrize("value", [None, "", "0", '"0"', "-1", "abc", '"1.5"', "*"])
def test_a_malformed_expected_version_is_refused(value: str | None) -> None:
    with pytest.raises(ValidationError) as failure:
        require_expected_version(value)
    assert failure.value.code == "expected_version_invalid"

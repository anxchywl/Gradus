from __future__ import annotations

import pytest

from app.domain.syllabus import RateLimitedError, SyllabusDraft
from app.infrastructure.guards import InMemoryDraftStore, InMemoryRateLimiter


async def test_a_caller_is_refused_once_the_allowance_is_spent() -> None:
    limiter = InMemoryRateLimiter(allowance=2, window_seconds=3_600)

    await limiter.claim("student-a")
    await limiter.claim("student-a")

    with pytest.raises(RateLimitedError):
        await limiter.claim("student-a")


async def test_one_caller_does_not_spend_another_caller_s_allowance() -> None:
    limiter = InMemoryRateLimiter(allowance=1, window_seconds=3_600)

    await limiter.claim("student-a")
    await limiter.claim("student-b")

    with pytest.raises(RateLimitedError):
        await limiter.claim("student-a")


async def test_the_allowance_returns_once_the_window_has_passed() -> None:
    limiter = InMemoryRateLimiter(allowance=1, window_seconds=0.0)

    await limiter.claim("student-a")
    await limiter.claim("student-a")


async def test_a_limiter_that_cannot_decide_refuses_rather_than_allows() -> None:
    # a control that fails open is a control that is absent
    limiter = InMemoryRateLimiter(allowance=5, window_seconds=3_600)
    limiter._seen = None  # type: ignore[assignment]  # noqa: SLF001

    with pytest.raises(RateLimitedError):
        await limiter.claim("student-a")


async def test_a_remembered_draft_is_returned_without_repeating_the_work() -> None:
    store = InMemoryDraftStore(maximum_entries=8, ttl_seconds=900)
    draft = SyllabusDraft(code="MATH 273")

    await store.remember("student-a:key", draft)

    assert await store.remembered("student-a:key") is draft
    assert await store.remembered("student-a:other") is None


async def test_a_remembered_draft_expires() -> None:
    store = InMemoryDraftStore(maximum_entries=8, ttl_seconds=0.0)

    await store.remember("student-a:key", SyllabusDraft(code="MATH 273"))

    assert await store.remembered("student-a:key") is None


async def test_the_store_does_not_grow_without_bound() -> None:
    store = InMemoryDraftStore(maximum_entries=2, ttl_seconds=900)

    for index in range(5):
        await store.remember(f"key-{index}", SyllabusDraft(code=str(index)))

    assert await store.remembered("key-0") is None
    assert await store.remembered("key-4") is not None

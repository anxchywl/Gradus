from __future__ import annotations

import time
from collections import OrderedDict, deque

from app.domain.syllabus import RateLimitedError, SyllabusDraft


# one process, one replica. a second replica would double the allowance, so
# scaling horizontally means moving this to a shared store first
class InMemoryRateLimiter:
    def __init__(self, *, allowance: int, window_seconds: float) -> None:
        self._allowance = allowance
        self._window = window_seconds
        self._seen: OrderedDict[str, deque[float]] = OrderedDict()
        # bounded so a stream of distinct subjects cannot grow this without end
        self._maximum_keys = 10_000

    async def claim(self, key: str) -> None:
        try:
            self._claim(key)
        except RateLimitedError:
            raise
        except Exception as error:
            # a limiter that cannot decide refuses; one that fails open is absent
            raise RateLimitedError(
                "rate_limited",
                "Too many requests. Try again shortly.",
            ) from error

    def _claim(self, key: str) -> None:
        now = time.monotonic()
        attempts = self._seen.get(key)
        if attempts is None:
            attempts = deque()
            self._seen[key] = attempts
        while attempts and now - attempts[0] > self._window:
            attempts.popleft()
        if len(attempts) >= self._allowance:
            raise RateLimitedError(
                "rate_limited",
                "Too many requests. Try again shortly.",
            )
        attempts.append(now)
        self._seen.move_to_end(key)
        while len(self._seen) > self._maximum_keys:
            self._seen.popitem(last=False)


# a retried upload must not be paid for twice; this survives a retry, not a
# restart, and never becomes a claim that the endpoint is idempotent
class InMemoryDraftStore:
    def __init__(self, *, maximum_entries: int, ttl_seconds: float) -> None:
        self._maximum_entries = maximum_entries
        self._ttl = ttl_seconds
        self._entries: OrderedDict[str, tuple[float, SyllabusDraft]] = OrderedDict()

    async def remembered(self, key: str) -> SyllabusDraft | None:
        entry = self._entries.get(key)
        if entry is None:
            return None
        stored_at, draft = entry
        if time.monotonic() - stored_at > self._ttl:
            del self._entries[key]
            return None
        self._entries.move_to_end(key)
        return draft

    async def remember(self, key: str, draft: SyllabusDraft) -> None:
        self._entries[key] = (time.monotonic(), draft)
        self._entries.move_to_end(key)
        while len(self._entries) > self._maximum_entries:
            self._entries.popitem(last=False)

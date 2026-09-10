from __future__ import annotations

from typing import Any
from urllib.parse import urlsplit

import anthropic
import httpx2
import openai
import pytest
from pydantic import BaseModel

from app.infrastructure.syllabus.clients import (
    AnthropicModelClient,
    ModelCallError,
    OpenAICompatibleModelClient,
    profile_for,
)


class _Schema(BaseModel):
    value: str | None


class _Usage:
    def __init__(self, first: int, second: int) -> None:
        self.input_tokens = first
        self.output_tokens = second
        self.prompt_tokens = first
        self.completion_tokens = second


class _Call:
    def __init__(self, outcome: Any) -> None:
        self.outcome = outcome
        self.seen: dict[str, Any] = {}
        self.closed = False

    async def parse(self, **kwargs: Any) -> Any:
        self.seen = kwargs
        if isinstance(self.outcome, Exception):
            raise self.outcome
        return self.outcome


class _AnthropicResponse:
    def __init__(self, parsed: Any) -> None:
        self.parsed_output = parsed
        self.usage = _Usage(1_200, 90)


class _AnthropicSdk:
    def __init__(self, outcome: Any) -> None:
        self.messages = _Call(outcome)
        self.closed = False

    async def close(self) -> None:
        self.closed = True


class _Message:
    def __init__(self, parsed: Any) -> None:
        self.parsed = parsed


class _Choice:
    def __init__(self, parsed: Any) -> None:
        self.message = _Message(parsed)


_REPORTED = _Usage(1_200, 90)


class _OpenAIResponse:
    def __init__(self, parsed: Any, usage: _Usage | None = _REPORTED) -> None:
        self.choices = [_Choice(parsed)]
        self.usage = usage


class _Completions:
    def __init__(self, outcome: Any) -> None:
        self.completions = _Call(outcome)


class _OpenAISdk:
    def __init__(self, outcome: Any) -> None:
        self.chat = _Completions(outcome)
        self.closed = False

    async def close(self) -> None:
        self.closed = True


def _api_error() -> anthropic.APIError:
    request = httpx2.Request("POST", "https://api.anthropic.com/v1/messages")
    return anthropic.APIError(
        "upstream said something quoting the document", request, body=None
    )


async def test_the_anthropic_client_returns_what_was_parsed_and_what_it_cost() -> None:
    sdk = _AnthropicSdk(_AnthropicResponse(_Schema(value="ok")))
    client = AnthropicModelClient(sdk, model="claude-haiku-4-5")  # type: ignore[arg-type]

    result = await client.complete(
        system="rules", user="document", schema=_Schema, maximum_output_tokens=4_000
    )

    assert result.parsed == _Schema(value="ok")
    assert (result.input_tokens, result.output_tokens) == (1_200, 90)
    assert sdk.messages.seen["model"] == "claude-haiku-4-5"
    assert sdk.messages.seen["max_tokens"] == 4_000


async def test_an_openai_model_is_given_the_newer_output_cap_field() -> None:
    sdk = _OpenAISdk(_OpenAIResponse(_Schema(value="ok")))
    client = OpenAICompatibleModelClient(
        sdk,  # type: ignore[arg-type]
        model="gpt-5-nano",
        output_cap_field="max_completion_tokens",
    )

    await client.complete(
        system="rules", user="document", schema=_Schema, maximum_output_tokens=4_000
    )

    seen = sdk.chat.completions.seen
    assert seen["max_completion_tokens"] == 4_000
    # the older name is rejected by these models, so it must not be sent as well
    assert "max_tokens" not in seen


async def test_a_compatible_endpoint_is_given_the_older_output_cap_field() -> None:
    sdk = _OpenAISdk(_OpenAIResponse(_Schema(value="ok")))
    client = OpenAICompatibleModelClient(
        sdk,  # type: ignore[arg-type]
        model="gemini-3.1-flash-lite",
        output_cap_field="max_tokens",
    )

    await client.complete(
        system="rules", user="document", schema=_Schema, maximum_output_tokens=4_000
    )

    seen = sdk.chat.completions.seen
    assert seen["max_tokens"] == 4_000
    assert "max_completion_tokens" not in seen
    assert [message["role"] for message in seen["messages"]] == ["system", "user"]


async def test_a_response_without_usage_is_counted_as_nothing() -> None:
    sdk = _OpenAISdk(_OpenAIResponse(_Schema(value="ok"), usage=None))
    client = OpenAICompatibleModelClient(
        sdk,  # type: ignore[arg-type]
        model="gpt-5-nano",
        output_cap_field="max_completion_tokens",
    )

    result = await client.complete(
        system="rules", user="document", schema=_Schema, maximum_output_tokens=4_000
    )

    assert (result.input_tokens, result.output_tokens) == (0, 0)


async def test_an_anthropic_failure_carries_no_upstream_text() -> None:
    client = AnthropicModelClient(_AnthropicSdk(_api_error()), model="m")  # type: ignore[arg-type]

    with pytest.raises(ModelCallError) as raised:
        await client.complete(
            system="rules", user="document", schema=_Schema, maximum_output_tokens=10
        )

    assert "quoting the document" not in str(raised.value)


async def test_an_openai_failure_carries_no_upstream_text() -> None:
    sdk = _OpenAISdk(openai.OpenAIError("upstream quoted the document back"))
    client = OpenAICompatibleModelClient(
        sdk,  # type: ignore[arg-type]
        model="m",
        output_cap_field="max_tokens",
    )

    with pytest.raises(ModelCallError) as raised:
        await client.complete(
            system="rules", user="document", schema=_Schema, maximum_output_tokens=10
        )

    assert "quoted the document" not in str(raised.value)


async def test_closing_a_client_closes_the_transport_underneath_it() -> None:
    sdk = _AnthropicSdk(_AnthropicResponse(None))
    await AnthropicModelClient(sdk, model="m").aclose()  # type: ignore[arg-type]
    assert sdk.closed


def test_every_compatible_endpoint_is_https() -> None:
    for provider in ("openai", "gemini", "deepseek"):
        base_url = profile_for(provider).base_url
        # the syllabus text travels over this, so a plain http default is a leak
        assert base_url is None or urlsplit(base_url).scheme == "https"


def test_a_provider_without_a_profile_is_refused_rather_than_guessed() -> None:
    with pytest.raises(ValueError):
        profile_for("anthropic")

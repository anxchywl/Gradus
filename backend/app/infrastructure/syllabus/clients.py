from __future__ import annotations

from dataclasses import dataclass
from typing import Literal, Protocol, TypeVar

import anthropic
import openai
from openai.types.chat import ChatCompletionMessageParam
from pydantic import BaseModel

SchemaT = TypeVar("SchemaT", bound=BaseModel)

__all__ = [
    "AnthropicModelClient",
    "ModelCallError",
    "ModelResult",
    "OpenAICompatibleModelClient",
    "ProviderProfile",
    "StructuredModelClient",
    "profile_for",
]


# the provider's own error text can quote the document back, so nothing from it
# is carried into this exception
class ModelCallError(Exception):
    pass


@dataclass(frozen=True)
class ModelResult[SchemaT: BaseModel]:
    parsed: SchemaT | None
    input_tokens: int
    output_tokens: int


class StructuredModelClient(Protocol):
    async def complete(
        self,
        *,
        system: str,
        user: str,
        schema: type[SchemaT],
        maximum_output_tokens: int,
    ) -> ModelResult[SchemaT]: ...

    async def aclose(self) -> None: ...


OutputCapField = Literal["max_tokens", "max_completion_tokens"]


@dataclass(frozen=True)
class ProviderProfile:
    base_url: str | None
    # newer openai models refuse max_tokens; the compatible endpoints refuse the
    # newer name, so the cap cannot be sent under one name for all of them
    output_cap_field: OutputCapField


_PROFILES = {
    "openai": ProviderProfile(None, "max_completion_tokens"),
    "gemini": ProviderProfile(
        "https://generativelanguage.googleapis.com/v1beta/openai/", "max_tokens"
    ),
    "deepseek": ProviderProfile("https://api.deepseek.com/v1", "max_tokens"),
}


def profile_for(provider: str) -> ProviderProfile:
    profile = _PROFILES.get(provider)
    if profile is None:
        raise ValueError(f"no openai-compatible profile for {provider}")
    return profile


class AnthropicModelClient:
    def __init__(self, client: anthropic.AsyncAnthropic, *, model: str) -> None:
        self._client = client
        self._model = model

    async def complete(
        self,
        *,
        system: str,
        user: str,
        schema: type[SchemaT],
        maximum_output_tokens: int,
    ) -> ModelResult[SchemaT]:
        try:
            response = await self._client.messages.parse(
                model=self._model,
                max_tokens=maximum_output_tokens,
                system=system,
                messages=[{"role": "user", "content": user}],
                output_format=schema,
            )
        except anthropic.APIError as error:
            raise ModelCallError from error

        return ModelResult(
            parsed=response.parsed_output,
            input_tokens=response.usage.input_tokens,
            output_tokens=response.usage.output_tokens,
        )

    async def aclose(self) -> None:
        await self._client.close()


class OpenAICompatibleModelClient:
    def __init__(
        self,
        client: openai.AsyncOpenAI,
        *,
        model: str,
        output_cap_field: OutputCapField,
    ) -> None:
        self._client = client
        self._model = model
        self._output_cap_field = output_cap_field

    async def complete(
        self,
        *,
        system: str,
        user: str,
        schema: type[SchemaT],
        maximum_output_tokens: int,
    ) -> ModelResult[SchemaT]:
        messages: list[ChatCompletionMessageParam] = [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ]
        try:
            if self._output_cap_field == "max_completion_tokens":
                response = await self._client.chat.completions.parse(
                    model=self._model,
                    messages=messages,
                    response_format=schema,
                    max_completion_tokens=maximum_output_tokens,
                )
            else:
                response = await self._client.chat.completions.parse(
                    model=self._model,
                    messages=messages,
                    response_format=schema,
                    max_tokens=maximum_output_tokens,
                )
        except openai.OpenAIError as error:
            raise ModelCallError from error

        usage = response.usage
        return ModelResult(
            parsed=response.choices[0].message.parsed,
            input_tokens=usage.prompt_tokens if usage else 0,
            output_tokens=usage.completion_tokens if usage else 0,
        )

    async def aclose(self) -> None:
        await self._client.close()

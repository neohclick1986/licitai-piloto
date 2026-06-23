"""LicitaI Piloto - LLM Provider (port)."""

import json
import os
from dataclasses import dataclass
from typing import Protocol

import httpx


@dataclass
class LLMResponse:
    content: str
    tokens_input: int
    tokens_output: int
    model: str
    provider: str
    finish_reason: str = "stop"
    raw: dict | None = None


class LLMProvider(Protocol):
    async def generate(
        self,
        system: str,
        user: str,
        temperature: float = 0.2,
        max_tokens: int = 4000,
        response_format: dict | None = None,
    ) -> LLMResponse: ...


class OpenAIProvider:
    def __init__(self, api_key: str, model: str = "gpt-4o"):
        self.api_key = api_key
        self.model = model
        self._client: httpx.AsyncClient | None = None

    async def _get_client(self) -> httpx.AsyncClient:
        if not self._client:
            self._client = httpx.AsyncClient(timeout=60.0)
        return self._client

    async def generate(
        self,
        system: str,
        user: str,
        temperature: float = 0.2,
        max_tokens: int = 4000,
        response_format: dict | None = None,
    ) -> LLMResponse:
        client = await self._get_client()
        body: dict = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            "temperature": temperature,
            "max_tokens": max_tokens,
        }
        if response_format:
            body["response_format"] = response_format

        resp = await client.post(
            "https://api.openai.com/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
            json=body,
        )
        resp.raise_for_status()
        data = resp.json()

        choice = data["choices"][0]
        return LLMResponse(
            content=choice["message"]["content"],
            tokens_input=data["usage"]["prompt_tokens"],
            tokens_output=data["usage"]["completion_tokens"],
            model=self.model,
            provider="openai",
            finish_reason=choice.get("finish_reason", "stop"),
            raw=data,
        )

    async def aclose(self) -> None:
        if self._client:
            await self._client.aclose()


class OllamaProvider:
    """Provedor local (Ollama) - útil para air-gap e desenvolvimento."""

    def __init__(self, base_url: str = "http://localhost:11434", model: str = "llama3.1:8b"):
        self.base_url = base_url
        self.model = model
        self._client: httpx.AsyncClient | None = None

    async def _get_client(self) -> httpx.AsyncClient:
        if not self._client:
            self._client = httpx.AsyncClient(timeout=120.0)
        return self._client

    async def generate(
        self,
        system: str,
        user: str,
        temperature: float = 0.2,
        max_tokens: int = 4000,
        response_format: dict | None = None,
    ) -> LLMResponse:
        client = await self._get_client()
        resp = await client.post(
            f"{self.base_url}/api/chat",
            json={
                "model": self.model,
                "messages": [
                    {"role": "system", "content": system},
                    {"role": "user", "content": user},
                ],
                "stream": False,
                "options": {"temperature": temperature, "num_predict": max_tokens},
            },
        )
        resp.raise_for_status()
        data = resp.json()

        content = data["message"]["content"]
        return LLMResponse(
            content=content,
            tokens_input=data.get("prompt_eval_count", 0),
            tokens_output=data.get("eval_count", 0),
            model=self.model,
            provider="ollama",
            finish_reason="stop",
            raw=data,
        )

    async def aclose(self) -> None:
        if self._client:
            await self._client.aclose()


def get_provider(provider_name: str, settings) -> LLMProvider:
    """Factory: retorna o provider configurado."""
    if provider_name == "openai" and settings.openai_api_key:
        return OpenAIProvider(settings.openai_api_key, settings.openai_model)
    elif provider_name == "ollama":
        return OllamaProvider(settings.ollama_base_url, settings.ollama_model)
    else:
        # Fallback para Ollama se nada configurado
        return OllamaProvider(
            os.environ.get("OLLAMA_BASE_URL", "http://localhost:11434"),
            os.environ.get("OLLAMA_MODEL", "llama3.1:8b"),
        )

"""LicitaI Piloto - Fixtures de teste."""

from dataclasses import dataclass

import pytest

from packages.agents.llm.provider import LLMResponse


@dataclass
class FakeSettings:
    """Settings mínimas para testes do factory de providers."""

    openai_api_key: str | None = None
    openai_model: str = "gpt-4o"
    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = "llama3.1:8b"


class MockLLMProvider:
    """Provider de LLM que retorna uma resposta pré-configurada.

    Útil para testar a Crew-DFD sem chamar um LLM real.
    """

    def __init__(self, content: str):
        self.content = content
        self.calls: list[dict] = []

    async def generate(
        self,
        system: str,
        user: str,
        temperature: float = 0.2,
        max_tokens: int = 4000,
        response_format: dict | None = None,
    ) -> LLMResponse:
        self.calls.append(
            {
                "system": system,
                "user": user,
                "temperature": temperature,
                "max_tokens": max_tokens,
                "response_format": response_format,
            }
        )
        return LLMResponse(
            content=self.content,
            tokens_input=10,
            tokens_output=20,
            model="mock-model",
            provider="mock",
            finish_reason="stop",
        )


@pytest.fixture
def fake_settings() -> FakeSettings:
    return FakeSettings()


@pytest.fixture
def mock_llm():
    """Factory que cria um MockLLMProvider com conteúdo customizado."""

    def _make(content: str) -> MockLLMProvider:
        return MockLLMProvider(content)

    return _make

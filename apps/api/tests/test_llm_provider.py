"""Testes unitários do factory de LLM providers."""

import os

from packages.agents.llm.provider import (
    LLMProvider,
    OllamaProvider,
    OpenAIProvider,
    get_provider,
)


class TestGetProvider:
    def test_retorna_openai_quando_tem_api_key(self, fake_settings):
        fake_settings.openai_api_key = "sk-test-key"
        provider = get_provider("openai", fake_settings)
        assert isinstance(provider, OpenAIProvider)
        assert provider.api_key == "sk-test-key"

    def test_retorna_ollama_quando_solicitado(self, fake_settings):
        provider = get_provider("ollama", fake_settings)
        assert isinstance(provider, OllamaProvider)
        assert provider.base_url == fake_settings.ollama_base_url

    def test_fallback_para_ollama_sem_api_key(self, fake_settings):
        fake_settings.openai_api_key = None
        provider = get_provider("openai", fake_settings)
        assert isinstance(provider, OllamaProvider)

    def test_fallback_para_ollama_provider_desconhecido(self, fake_settings):
        provider = get_provider("anthropic", fake_settings)
        assert isinstance(provider, OllamaProvider)

    def test_fallback_usa_env_vars(self, fake_settings, monkeypatch):
        monkeypatch.setenv("OLLAMA_BASE_URL", "http://custom:11434")
        monkeypatch.setenv("OLLAMA_MODEL", "mistral:7b")
        provider = get_provider("inexistente", fake_settings)
        assert isinstance(provider, OllamaProvider)
        assert provider.base_url == "http://custom:11434"
        assert provider.model == "mistral:7b"

    def test_providers_implementam_protocol(self, fake_settings):
        fake_settings.openai_api_key = "sk-test"
        openai = get_provider("openai", fake_settings)
        ollama = get_provider("ollama", fake_settings)
        assert hasattr(openai, "generate")
        assert hasattr(ollama, "generate")

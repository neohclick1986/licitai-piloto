"""LicitaI Piloto - Settings."""

from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = "LicitaI API - Piloto"
    app_version: str = "0.1.0"
    environment: Literal["dev", "staging", "prod"] = "dev"
    debug: bool = False
    api_v1_prefix: str = "/api/v1"

    supabase_url: str
    supabase_anon_key: str
    supabase_service_role_key: str
    supabase_db_url: str

    secret_key: str
    jwt_audience: str = "authenticated"
    access_token_expire_minutes: int = 60

    llm_default_provider: Literal["openai", "anthropic", "ollama"] = "openai"
    openai_api_key: str | None = None
    openai_model: str = "gpt-4o"
    anthropic_api_key: str | None = None
    anthropic_model: str = "claude-3-5-sonnet-20241022"
    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = "llama3.1:70b"

    enable_rls: bool = True
    enable_ai: bool = True
    ai_require_human_approval: bool = True

    log_level: str = "INFO"
    cors_origins: list[str] = ["http://localhost:3000"]


import functools

@functools.lru_cache
def get_settings() -> Settings:
    return Settings()

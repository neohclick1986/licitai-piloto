"""LicitaI Piloto - Database connection + RLS."""

from collections.abc import AsyncGenerator
from typing import Any

from sqlalchemy import text
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from apps.api.src.settings import get_settings


class Base(DeclarativeBase):
    pass


_settings = get_settings()

engine = create_async_engine(
    _settings.supabase_db_url,
    pool_size=20,
    max_overflow=10,
    pool_pre_ping=True,
    echo=False,
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Sessão de banco com RLS ativo (tenant_id injetado)."""
    async with AsyncSessionLocal() as session:
        yield session


async def get_db_with_tenant(
    tenant_id: str, db: AsyncSession
) -> AsyncSession:
    """
    Configura a sessão com tenant_id para RLS.
    CRÍTICO: chamar antes de qualquer query.
    """
    if _settings.enable_rls and tenant_id:
        await db.execute(
            text("SET LOCAL app.tenant_id = :tid"),
            {"tid": tenant_id},
        )
    return db

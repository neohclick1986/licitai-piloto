"""LicitaI Piloto - Health endpoints."""

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from apps.api.src.infrastructure.db.database import get_db
from apps.api.src.settings import get_settings


router = APIRouter()


@router.get("/health")
async def health():
    return {"status": "ok"}


@router.get("/health/detailed")
async def health_detailed(db: AsyncSession = Depends(get_db)):
    settings = get_settings()
    db_ok = False
    try:
        result = await db.execute(text("SELECT 1 AS n"))
        db_ok = result.scalar() == 1
    except Exception as e:
        return {"status": "degraded", "error": str(e)}

    return {
        "status": "ok" if db_ok else "degraded",
        "app": settings.app_name,
        "version": settings.app_version,
        "db": "ok" if db_ok else "down",
        "llm_provider": settings.llm_default_provider,
        "ai_enabled": settings.enable_ai,
    }

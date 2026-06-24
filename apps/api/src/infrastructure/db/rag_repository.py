"""LicitaI Piloto - RAG Repository (Knowledge Base).

Busca chunks da base de conhecimento (Lei 14.133/2021) por metadata,
para injetar contexto legal relevante nos prompts das crews.
"""

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


async def buscar_chunks_por_artigo(
    db: AsyncSession,
    tenant_id: str | None,
    artigos: list[str],
) -> list[dict]:
    """Busca chunks da KB cuja metadata contém o número de artigo informado.

    Retorna chunks globais (tenant_id IS NULL) ou do tenant atual,
    ordenados por chunk_index.
    """
    if not artigos:
        return []
    result = await db.execute(
        text(
            """
            SELECT texto, metadata
            FROM kb_chunks
            WHERE (tenant_id IS NULL OR tenant_id = :tid)
              AND metadata->>'artigo' = ANY(:artigos)
            ORDER BY chunk_index
            """
        ),
        {"tid": tenant_id, "artigos": artigos},
    )
    return [dict(r) for r in result.mappings().all()]

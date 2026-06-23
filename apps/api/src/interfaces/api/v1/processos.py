"""LicitaI Piloto - API v1: Processos."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from apps.api.src.infrastructure.db.database import get_db, get_db_with_tenant
from apps.api.src.interfaces.api.deps import get_current_user, AuthUser


router = APIRouter(prefix="/processos", tags=["Processos"])


class CriarProcessoRequest(BaseModel):
    objeto: str = Field(..., min_length=10, description="Descrição do objeto")
    categoria: str = Field(..., description="MATERIAL | SERVICO_CONTINUO | OBRA | TI | OUTROS")
    modalidade: str = "PREGAO_ELETRONICO"
    valor_estimado: float | None = None
    area_requisitante: str | None = None


class ProcessoResponse(BaseModel):
    id: str
    numero_ano: str | None
    objeto: str
    categoria: str
    modalidade: str
    status: str
    valor_estimado: float | None
    area_requisitante: str | None
    tem_dfd: bool
    tem_pesquisa: bool
    tem_etp: bool
    tem_tr: bool
    tem_edital: bool
    tem_parecer: bool
    tem_contrato: bool
    created_at: str


@router.get("/", response_model=list[ProcessoResponse])
async def listar_processos(
    status_filter: str | None = None,
    limit: int = 50,
    offset: int = 0,
    user: AuthUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Lista processos do tenant atual."""
    if not user.tenant_id:
        raise HTTPException(status_code=403, detail="Usuário sem tenant")

    await get_db_with_tenant(user.tenant_id, db)

    query = "SELECT * FROM vw_processos_resumo WHERE tenant_id = :tid"
    params: dict = {"tid": user.tenant_id, "limit": limit, "offset": offset}
    if status_filter:
        query += " AND status = :status"
        params["status"] = status_filter
    query += " ORDER BY created_at DESC LIMIT :limit OFFSET :offset"

    result = (await db.execute(text(query), params)).mappings().all()
    return [dict(r) for r in result]


@router.post("/", response_model=ProcessoResponse, status_code=status.HTTP_201_CREATED)
async def criar_processo(
    body: CriarProcessoRequest,
    user: AuthUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Cria novo processo em RASCUNHO."""
    if not user.tenant_id:
        raise HTTPException(status_code=403, detail="Usuário sem tenant")

    await get_db_with_tenant(user.tenant_id, db)

    # Gera número do processo
    ano = "2026"
    count_row = (
        await db.execute(
            text(
                "SELECT COUNT(*) AS n FROM processos "
                "WHERE tenant_id = :tid AND EXTRACT(YEAR FROM created_at) = :ano"
            ),
            {"tid": user.tenant_id, "ano": int(ano)},
        )
    ).mappings().first()
    numero = f"{ano}/{(count_row['n'] + 1):05d}"

    new_id = UUID("00000000-0000-0000-0000-000000000000")  # gerado pelo DB
    row = (
        await db.execute(
            text("""
                INSERT INTO processos (
                    tenant_id, numero_ano, objeto, categoria, modalidade,
                    status, valor_estimado, area_requisitante, responsavel_id
                ) VALUES (
                    :tid, :numero, :objeto, :categoria, :modalidade,
                    'RASCUNHO', :valor, :area, :responsavel
                ) RETURNING *
            """),
            {
                "tid": user.tenant_id,
                "numero": numero,
                "objeto": body.objeto,
                "categoria": body.categoria,
                "modalidade": body.modalidade,
                "valor": body.valor_estimado,
                "area": body.area_requisitante,
                "responsavel": user.id,
            },
        )
    ).mappings().first()
    await db.commit()

    # Buscar na view
    view_row = (
        await db.execute(
            text("SELECT * FROM vw_processos_resumo WHERE id = :id"),
            {"id": row["id"]},
        )
    ).mappings().first()
    return dict(view_row)


@router.get("/{processo_id}", response_model=ProcessoResponse)
async def get_processo(
    processo_id: UUID,
    user: AuthUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if not user.tenant_id:
        raise HTTPException(status_code=403, detail="Usuário sem tenant")

    await get_db_with_tenant(user.tenant_id, db)
    row = (
        await db.execute(
            text("SELECT * FROM vw_processos_resumo WHERE id = :id"),
            {"id": str(processo_id)},
        )
    ).mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Processo não encontrado")
    return dict(row)

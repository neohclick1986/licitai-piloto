"""LicitaI Piloto - API v1: DFD."""

from decimal import Decimal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from apps.api.src.application.use_cases.criar_dfd import CriarDFDUseCase, CriarDFDInput
from apps.api.src.infrastructure.db.database import get_db
from apps.api.src.interfaces.api.deps import get_current_user, AuthUser
from packages.agents.llm.provider import LLMProvider, get_provider
from apps.api.src.settings import get_settings


router = APIRouter(prefix="/dfd", tags=["DFD"])


class CriarDFDRequest(BaseModel):
    processo_id: UUID
    area_requisitante: str = Field(..., min_length=3)
    objeto: str = Field(..., min_length=10)
    justificativa: str = Field(..., min_length=20)
    quantidade: Decimal | None = None
    unidade_medida: str | None = None
    valor_estimado: Decimal = Field(..., gt=0)
    prazo_entrega_dias: int | None = Field(None, ge=1, le=365)
    destino: str | None = None
    usar_ia: bool = True


class CriarDFDResponse(BaseModel):
    dfd_id: str
    processo_id: str
    versao_revisada: dict
    checklist: list[dict]
    perguntas_para_demandante: list[str]
    citacoes: list[dict]
    parecer_agente: str
    ia_usada: bool
    tokens_usados: dict | None = None


@router.post("/", response_model=CriarDFDResponse, status_code=status.HTTP_201_CREATED)
async def criar_dfd(
    body: CriarDFDRequest,
    user: AuthUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Cria DFD para o processo e opcionalmente aciona a Crew-DFD para revisar.

    **Modo com IA (padrão):**
    - Retorna versão revisada, checklist de conformidade, perguntas e citações
    - Requer humano no loop para aprovar antes de avançar

    **Modo sem IA:**
    - Persiste o DFD como enviado
    """
    if not user.tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Usuário sem tenant associado",
        )

    settings = get_settings()
    llm: LLMProvider | None = None
    if body.usar_ia and settings.enable_ai:
        llm = get_provider(settings.llm_default_provider, settings)

    use_case = CriarDFDUseCase(db, llm)

    try:
        result = await use_case.execute(
            CriarDFDInput(
                processo_id=body.processo_id,
                tenant_id=UUID(user.tenant_id),
                user_id=UUID(user.id),
                area_requisitante=body.area_requisitante,
                objeto=body.objeto,
                justificativa=body.justificativa,
                quantidade=body.quantidade,
                unidade_medida=body.unidade_medida,
                valor_estimado=body.valor_estimado,
                prazo_entrega_dias=body.prazo_entrega_dias,
                destino=body.destino,
                usar_ia=body.usar_ia and settings.enable_ai,
            )
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    return CriarDFDResponse(**result)

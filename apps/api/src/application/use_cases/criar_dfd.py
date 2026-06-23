"""LicitaI Piloto - Use Case: Criar/Atualizar DFD com revisão por IA."""

from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from uuid import UUID, uuid4

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from apps.api.src.infrastructure.db.database import get_db_with_tenant
from packages.agents.crews.crew_dfd import CrewDFD, DFDCrewInput
from packages.agents.llm.provider import LLMProvider


@dataclass
class CriarDFDInput:
    processo_id: UUID
    tenant_id: UUID
    user_id: UUID
    area_requisitante: str
    objeto: str
    justificativa: str
    quantidade: Decimal | None
    unidade_medida: str | None
    valor_estimado: Decimal
    prazo_entrega_dias: int | None
    destino: str | None
    usar_ia: bool = True


class CriarDFDUseCase:
    """Cria DFD e opcionalmente aciona a Crew-DFD para revisar."""

    def __init__(self, db: AsyncSession, llm: LLMProvider | None = None):
        self.db = db
        self.llm = llm

    async def execute(self, entrada: CriarDFDInput) -> dict:
        await get_db_with_tenant(str(entrada.tenant_id), self.db)

        # 1. Buscar contexto do tenant
        tenant_row = (
            await self.db.execute(
                text("SELECT razao_social, esfera FROM tenants WHERE id = :id"),
                {"id": str(entrada.tenant_id)},
            )
        ).mappings().first()
        contexto_tenant = dict(tenant_row) if tenant_row else {}

        # 2. Criar artefato
        artefato_id = uuid4()
        dfd_inicial = {
            "area_requisitante": entrada.area_requisitante,
            "objeto": entrada.objeto,
            "justificativa": entrada.justificativa,
            "quantidade": float(entrada.quantidade) if entrada.quantidade else None,
            "unidade_medida": entrada.unidade_medida,
            "valor_estimado": float(entrada.valor_estimado),
            "prazo_entrega_dias": entrada.prazo_entrega_dias,
            "destino": entrada.destino,
        }

        # 3. Rodar IA (opcional)
        versao_revisada = dfd_inicial
        checklist: list[dict] = []
        perguntas: list[str] = []
        citacoes: list[dict] = []
        parecer_agente = ""
        ai_gen_id: UUID | None = None

        if entrada.usar_ia and self.llm:
            crew = CrewDFD(self.llm)
            saida = await crew.executar(
                DFDCrewInput(
                    tenant_id=entrada.tenant_id,
                    processo_id=entrada.processo_id,
                    dfd_inicial=dfd_inicial,
                    contexto_tenant=contexto_tenant,
                )
            )
            versao_revisada = saida.versao_revisada
            checklist = saida.checklist
            perguntas = saida.perguntas
            citacoes = saida.citacoes
            parecer_agente = saida.parecer_agente
            ai_gen_id = uuid4()

            # Persistir AI generation
            await self.db.execute(
                text("""
                    INSERT INTO ai_generations (
                        id, tenant_id, artefato_id, crew, agent_name,
                        provider, model, prompt_hash, prompt_texto,
                        response_hash, response_texto, citacoes,
                        tokens_input, tokens_output, latencia_ms
                    ) VALUES (
                        :id, :tenant_id, :artefato_id, 'DFD', 'Analista-DFD',
                        :provider, :model, :prompt_hash, :prompt_texto,
                        :response_hash, :response_texto, :citacoes,
                        :tokens_input, :tokens_output, :latencia_ms
                    )
                """),
                {
                    "id": str(ai_gen_id),
                    "tenant_id": str(entrada.tenant_id),
                    "artefato_id": str(artefato_id),
                    "provider": saida.llm_response.provider,
                    "model": saida.llm_response.model,
                    "prompt_hash": "placeholder",
                    "prompt_texto": json.dumps(dfd_inicial, ensure_ascii=False),
                    "response_hash": "placeholder",
                    "response_texto": saida.llm_response.content,
                    "citacoes": json.dumps(citacoes, ensure_ascii=False),
                    "tokens_input": saida.llm_response.tokens_input,
                    "tokens_output": saida.llm_response.tokens_output,
                    "latencia_ms": 0,
                },
            )

        # 4. Criar artefato (com conteúdo revisado pela IA, se houver)
        conteudo_texto = json.dumps(versao_revisada, ensure_ascii=False, indent=2)
        await self.db.execute(
            text("""
                INSERT INTO artefatos (
                    id, tenant_id, processo_id, tipo, versao, titulo,
                    conteudo_texto, hash_sha256, gerado_por_user_id,
                    gerado_por_ia, ai_generation_id
                ) VALUES (
                    :id, :tenant_id, :processo_id, 'DFD', 1, :titulo,
                    :conteudo, encode(digest(:conteudo, 'sha256'), 'hex'),
                    :user_id, :gerado_por_ia, :ai_gen_id
                )
            """),
            {
                "id": str(artefato_id),
                "tenant_id": str(entrada.tenant_id),
                "processo_id": str(entrada.processo_id),
                "titulo": f"DFD - {entrada.objeto[:100]}",
                "conteudo": conteudo_texto,
                "user_id": str(entrada.user_id),
                "gerado_por_ia": entrada.usar_ia and self.llm is not None,
                "ai_gen_id": str(ai_gen_id) if ai_gen_id else None,
            },
        )

        # 5. Criar/atualizar DFD
        await self.db.execute(
            text("""
                INSERT INTO dfd (
                    id, tenant_id, processo_id, artefato_id, area_requisitante,
                    responsavel_id, objeto, justificativa, quantidade, unidade_medida,
                    valor_estimado, prazo_entrega_dias, destino, nivel_risco
                ) VALUES (
                    :id, :tenant_id, :processo_id, :artefato_id, :area,
                    :responsavel_id, :objeto, :justificativa, :qtd, :unidade,
                    :valor, :prazo, :destino, :nivel
                )
                ON CONFLICT (processo_id) DO UPDATE SET
                    objeto = EXCLUDED.objeto,
                    justificativa = EXCLUDED.justificativa,
                    valor_estimado = EXCLUDED.valor_estimado,
                    updated_at = NOW()
            """),
            {
                "id": str(uuid4()),
                "tenant_id": str(entrada.tenant_id),
                "processo_id": str(entrada.processo_id),
                "artefato_id": str(artefato_id),
                "area": versao_revisada.get("area_requisitante") or entrada.area_requisitante,
                "responsavel_id": str(entrada.user_id),
                "objeto": versao_revisada.get("objeto") or entrada.objeto,
                "justificativa": versao_revisada.get("justificativa") or entrada.justificativa,
                "qtd": versao_revisada.get("quantidade") or entrada.quantidade,
                "unidade": versao_revisada.get("unidade_medida") or entrada.unidade_medida,
                "valor": versao_revisada.get("valor_estimado") or entrada.valor_estimado,
                "prazo": versao_revisada.get("prazo_entrega_dias") or entrada.prazo_entrega_dias,
                "destino": versao_revisada.get("destino") or entrada.destino,
                "nivel": versao_revisada.get("nivel_risco", "BAIXO"),
            },
        )

        # 6. Transicionar processo
        await self.db.execute(
            text("""
                UPDATE processos
                SET status = 'DFD_ELABORACAO', area_requisitante = :area, updated_at = NOW()
                WHERE id = :id
            """),
            {"area": entrada.area_requisitante, "id": str(entrada.processo_id)},
        )

        # 7. Audit log
        await self.db.execute(
            text("""
                INSERT INTO audit_log (
                    id, tenant_id, aggregate_type, aggregate_id, event_type,
                    actor_id, payload, hash_self
                ) VALUES (
                    :id, :tenant_id, 'Processo', :proc_id, 'DFD_CRIADO',
                    :actor, :payload, encode(digest(:payload_str, 'sha256'), 'hex')
                )
            """),
            {
                "id": str(uuid4()),
                "tenant_id": str(entrada.tenant_id),
                "proc_id": str(entrada.processo_id),
                "actor": str(entrada.user_id),
                "payload": json.dumps({"artefato_id": str(artefato_id), "usou_ia": entrada.usar_ia}),
                "payload_str": str(entrada.processo_id),
            },
        )

        await self.db.commit()

        return {
            "dfd_id": str(artefato_id),
            "processo_id": str(entrada.processo_id),
            "versao_revisada": versao_revisada,
            "checklist": checklist,
            "perguntas_para_demandante": perguntas,
            "citacoes": citacoes,
            "parecer_agente": parecer_agente,
            "ia_usada": entrada.usar_ia and self.llm is not None,
            "tokens_usados": (
                {
                    "input": saida.llm_response.tokens_input if entrada.usar_ia and self.llm else 0,
                    "output": saida.llm_response.tokens_output if entrada.usar_ia and self.llm else 0,
                }
                if entrada.usar_ia and self.llm
                else None
            ),
        }


import json

"""LicitaI Piloto - Crew DFD.

Primeira crew funcional do piloto. Roda em modo "lite":
- Analista-DFD: revisa o DFD inicial e retorna versão melhorada + checklist
- Persiste geração na tabela ai_generations
- Anexa observações para revisão humana
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from uuid import UUID

from packages.agents.llm.provider import LLMProvider, LLMResponse


SYSTEM_PROMPT_DFD = """Você é um(a) especialista sênior em contratações públicas brasileiras,
com 20 anos de experiência em Documento de Formalização da Demanda (DFD).
Domina a Lei nº 14.133/2021 (especialmente art. 12), a IN SEGES/ME nº 81/2022,
e a jurisprudência do TCU.

Sua missão: revisar um DFD preliminar e retornar:
1. Uma versão REVISADA (em JSON estruturado) com melhorias de redação, completude e fundamentação
2. Um CHECKLIST de conformidade (✓/✗/⚠) com observações por item
3. Lista de PERGUNTAS ao demandante para esclarecer pontos críticos
4. CITAÇÕES legais aplicáveis

REGRAS:
- Toda afirmação jurídica deve ter FONTE (artigo, lei, IN, acórdão)
- Não invente dados técnicos não fornecidos
- Use linguagem clara e objetiva
- Se o DFD estiver muito incompleto, sinalize como PRECISA_REVISÃO_HUMANA

Responda EXCLUSIVAMENTE em JSON válido com a estrutura:
{
  "versao_revisada": {
    "objeto": "...",
    "justificativa": "...",
    "quantidade": 0,
    "unidade_medida": "...",
    "valor_estimado": 0.0,
    "prazo_entrega_dias": 0,
    "destino": "...",
    "classificacao": "BEM_COMUM|SERVICO_COMUM|OBRA|SERVICO_ESPECIALIZADO",
    "nivel_risco": "BAIXO|MEDIO|ALTO"
  },
  "checklist": [
    {"item": "Identificação do requisitante (art. 12, §1º, I)", "status": "✓|⚠|✗", "observacao": "..."},
    ...
  ],
  "perguntas_para_demandante": ["...", "..."],
  "citacoes": [
    {"fonte": "Lei 14.133/2021, art. 12, §1º", "trecho_relevante": "..."},
    ...
  ],
  "parecer_agente": "TEXTO CURTO RESUMINDO A AVALIAÇÃO"
}
"""


@dataclass
class DFDCrewInput:
    tenant_id: UUID
    processo_id: UUID
    dfd_inicial: dict
    contexto_tenant: dict
    contexto_legal: list[dict] = field(default_factory=list)


@dataclass
class DFDCrewOutput:
    versao_revisada: dict
    checklist: list[dict]
    perguntas: list[str]
    citacoes: list[dict]
    parecer_agente: str
    llm_response: LLMResponse


class CrewDFD:
    """Crew DFD - revisão e melhoria do DFD inicial."""

    def __init__(self, llm: LLMProvider):
        self.llm = llm

    async def executar(self, entrada: DFDCrewInput) -> DFDCrewOutput:
        contexto_legal_str = ""
        if entrada.contexto_legal:
            chunks_text = "\n\n".join(
                f"[Art. {c.get('metadata', {}).get('artigo', '?')}] {c['texto']}"
                for c in entrada.contexto_legal
            )
            contexto_legal_str = f"""
**Contexto legal relevante (Lei 14.133/2021 — recuperado via RAG):**
{chunks_text}
"""

        user_prompt = f"""Analise o DFD preliminar abaixo e gere a revisão.

**Órgão:** {entrada.contexto_tenant.get('razao_social')}
**Esfera:** {entrada.contexto_tenant.get('esfera')}
{contexto_legal_str}
**DFD Preliminar (fornecido pelo demandante):**
```json
{json.dumps(entrada.dfd_inicial, ensure_ascii=False, indent=2)}
```

Tarefas:
1. Corrija e aprimore a redação do DFD
2. Preencha o checklist de conformidade com art. 12 da Lei 14.133/2021
3. Liste perguntas que o demandante deve responder
4. Cite as fontes legais relevantes

Responda em JSON válido, conforme a estrutura especificada.
"""

        response = await self.llm.generate(
            system=SYSTEM_PROMPT_DFD,
            user=user_prompt,
            temperature=0.2,
            max_tokens=3000,
            response_format={"type": "json_object"},
        )

        try:
            parsed = json.loads(response.content)
        except json.JSONDecodeError:
            # Tenta extrair JSON do texto
            content = response.content
            start = content.find("{")
            end = content.rfind("}") + 1
            if start >= 0 and end > start:
                parsed = json.loads(content[start:end])
            else:
                raise ValueError(f"Resposta da IA não é JSON válido: {content[:200]}")

        return DFDCrewOutput(
            versao_revisada=parsed.get("versao_revisada", entrada.dfd_inicial),
            checklist=parsed.get("checklist", []),
            perguntas=parsed.get("perguntas_para_demandante", []),
            citacoes=parsed.get("citacoes", []),
            parecer_agente=parsed.get("parecer_agente", ""),
            llm_response=response,
        )

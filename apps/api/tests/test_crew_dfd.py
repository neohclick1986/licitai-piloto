"""Testes unitários da Crew-DFD com LLM mockado."""

import json
from uuid import uuid4

import pytest

from packages.agents.crews.crew_dfd import CrewDFD, DFDCrewInput


@pytest.fixture
def crew_input():
    return DFDCrewInput(
        tenant_id=uuid4(),
        processo_id=uuid4(),
        dfd_inicial={
            "area_requisitante": "Secretaria de Administração",
            "objeto": "Aquisição de papel A4",
            "justificativa": "Reposição de estoque",
            "quantidade": 500,
            "unidade_medida": "pacote",
            "valor_estimado": 12500.00,
            "prazo_entrega_dias": 30,
            "destino": "Almoxarifado",
        },
        contexto_tenant={"razao_social": "Prefeitura X", "esfera": "MUNICIPAL"},
    )


@pytest.fixture
def valid_llm_response():
    return json.dumps(
        {
            "versao_revisada": {
                "objeto": "Aquisição de 500 pacotes de papel A4 75g/m²",
                "justificativa": "Reposição de estoque consumido no exercício",
                "quantidade": 500,
                "unidade_medida": "pacote",
                "valor_estimado": 12500.00,
                "prazo_entrega_dias": 30,
                "destino": "Almoxarifado Central",
                "classificacao": "BEM_COMUM",
                "nivel_risco": "BAIXO",
            },
            "checklist": [
                {
                    "item": "Identificação do requisitante (art. 12, §1º, I)",
                    "status": "✓",
                    "observacao": "Presente",
                },
                {
                    "item": "Justificativa da necessidade (art. 12, §1º, II)",
                    "status": "⚠",
                    "observacao": "Ampliar detalhamento",
                },
            ],
            "perguntas_para_demandante": [
                "Qual o consumo médio mensal?",
            ],
            "citacoes": [
                {
                    "fonte": "Lei 14.133/2021, art. 12, §1º",
                    "trecho_relevante": "A fase preparatória...",
                }
            ],
            "parecer_agente": "DFD em conformidade parcial.",
        }
    )


class TestCrewDFD:
    async def test_executar_parseia_json_valido(self, mock_llm, crew_input, valid_llm_response):
        llm = mock_llm(valid_llm_response)
        crew = CrewDFD(llm)

        saida = await crew.executar(crew_input)

        assert saida.versao_revisada["objeto"] == "Aquisição de 500 pacotes de papel A4 75g/m²"
        assert saida.versao_revisada["nivel_risco"] == "BAIXO"
        assert len(saida.checklist) == 2
        assert saida.checklist[0]["status"] == "✓"
        assert len(saida.perguntas) == 1
        assert saida.citacoes[0]["fonte"] == "Lei 14.133/2021, art. 12, §1º"
        assert saida.parecer_agente == "DFD em conformidade parcial."
        assert saida.llm_response.provider == "mock"

    async def test_executar_extrai_json_de_texto(self, mock_llm, crew_input, valid_llm_response):
        llm = mock_llm(f"Aqui está o resultado:\n{valid_llm_response}\nFim.")
        crew = CrewDFD(llm)

        saida = await crew.executar(crew_input)

        assert saida.versao_revisada["objeto"] == "Aquisição de 500 pacotes de papel A4 75g/m²"
        assert len(saida.checklist) == 2

    async def test_executar_json_invalido_dispara_erro(self, mock_llm, crew_input):
        llm = mock_llm("isto não é JSON")
        crew = CrewDFD(llm)

        with pytest.raises(ValueError, match="não é JSON válido"):
            await crew.executar(crew_input)

    async def test_executar_inclui_contexto_legal_no_prompt(
        self, mock_llm, crew_input, valid_llm_response
    ):
        crew_input.contexto_legal = [
            {
                "texto": "Art. 12. O processo de licitação observará as seguintes fases...",
                "metadata": {"artigo": "12", "topico": "Fases do processo"},
            }
        ]
        llm = mock_llm(valid_llm_response)
        crew = CrewDFD(llm)

        await crew.executar(crew_input)

        assert len(llm.calls) == 1
        user_prompt = llm.calls[0]["user"]
        assert "Contexto legal relevante" in user_prompt
        assert "Art. 12" in user_prompt
        assert "Lei 14.133/2021" in user_prompt

    async def test_executar_sem_contexto_legal_nao_adiciona_secao(
        self, mock_llm, crew_input, valid_llm_response
    ):
        llm = mock_llm(valid_llm_response)
        crew = CrewDFD(llm)

        await crew.executar(crew_input)

        user_prompt = llm.calls[0]["user"]
        assert "Contexto legal relevante" not in user_prompt

    async def test_executar_passa_response_format_json(
        self, mock_llm, crew_input, valid_llm_response
    ):
        llm = mock_llm(valid_llm_response)
        crew = CrewDFD(llm)

        await crew.executar(crew_input)

        assert llm.calls[0]["response_format"] == {"type": "json_object"}

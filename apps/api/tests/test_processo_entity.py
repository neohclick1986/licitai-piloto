"""Testes unitários da entidade Processo (transições de estado)."""

import pytest

from apps.api.src.core.entities.processo import (
    Processo,
    ProcessoStatus,
)


class TestProcessoTransicoes:
    def test_processo_novo_inicia_como_rascunho(self):
        p = Processo()
        assert p.status == ProcessoStatus.RASCUNHO

    def test_transicao_valida_rascunho_para_dfd(self):
        p = Processo()
        p.transicionar_para(ProcessoStatus.DFD_ELABORACAO)
        assert p.status == ProcessoStatus.DFD_ELABORACAO

    def test_transicao_valida_dfd_para_pesquisa(self):
        p = Processo(status=ProcessoStatus.DFD_ELABORACAO)
        p.transicionar_para(ProcessoStatus.PESQUISA_PRECO)
        assert p.status == ProcessoStatus.PESQUISA_PRECO

    def test_transicao_invalida_dispara_erro(self):
        p = Processo(status=ProcessoStatus.RASCUNHO)
        with pytest.raises(ValueError, match="Transição inválida"):
            p.transicionar_para(ProcessoStatus.EM_ANDAMENTO)

    def test_transicao_invalida_pula_fases(self):
        p = Processo(status=ProcessoStatus.RASCUNHO)
        with pytest.raises(ValueError):
            p.transicionar_para(ProcessoStatus.CONTRATADO)

    def test_estado_terminal_concluido_bloqueia(self):
        p = Processo(status=ProcessoStatus.CONCLUIDO)
        assert not p.pode_transicionar_para(ProcessoStatus.EM_ANDAMENTO)
        with pytest.raises(ValueError):
            p.transicionar_para(ProcessoStatus.EM_ANDAMENTO)

    def test_estado_terminal_anulado_bloqueia(self):
        p = Processo(status=ProcessoStatus.ANULADO)
        assert p.pode_transicionar_para(ProcessoStatus.EM_ANDAMENTO) is False

    def test_estado_terminal_cancelado_bloqueia(self):
        p = Processo(status=ProcessoStatus.CANCELADO)
        assert not p.pode_transicionar_para(ProcessoStatus.RASCUNHO)

    def test_cancelamento_permitido_de_varias_fases(self):
        for status in [
            ProcessoStatus.RASCUNHO,
            ProcessoStatus.DFD_ELABORACAO,
            ProcessoStatus.PESQUISA_PRECO,
            ProcessoStatus.ETP_ELABORACAO,
        ]:
            p = Processo(status=status)
            assert p.pode_transicionar_para(ProcessoStatus.CANCELADO)

    def test_suspensao_e_retorno(self):
        p = Processo(status=ProcessoStatus.EM_ANDAMENTO)
        p.transicionar_para(ProcessoStatus.SUSPENSO)
        assert p.status == ProcessoStatus.SUSPENSO
        p.transicionar_para(ProcessoStatus.EM_ANDAMENTO)
        assert p.status == ProcessoStatus.EM_ANDAMENTO

    def test_transicao_atualiza_updated_at(self):
        p = Processo(status=ProcessoStatus.RASCUNHO)
        original_updated = p.updated_at
        p.transicionar_para(ProcessoStatus.DFD_ELABORACAO)
        assert p.updated_at >= original_updated

    def test_fluxo_completo_valido(self):
        p = Processo(status=ProcessoStatus.RASCUNHO)
        for destino in [
            ProcessoStatus.DFD_ELABORACAO,
            ProcessoStatus.PESQUISA_PRECO,
            ProcessoStatus.ETP_ELABORACAO,
            ProcessoStatus.TR_ELABORACAO,
            ProcessoStatus.EDITAL_ELABORACAO,
            ProcessoStatus.PARECER_JURIDICO,
            ProcessoStatus.PUBLICADO,
            ProcessoStatus.EM_ANDAMENTO,
            ProcessoStatus.HOMOLOGADO,
            ProcessoStatus.CONTRATADO,
            ProcessoStatus.EM_FISCALIZACAO,
            ProcessoStatus.CONCLUIDO,
        ]:
            p.transicionar_para(destino)
            assert p.status == destino

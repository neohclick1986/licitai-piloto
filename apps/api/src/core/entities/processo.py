"""LicitaI Piloto - Domain: Processo."""

from dataclasses import dataclass, field
from datetime import date, datetime, timezone
from decimal import Decimal
from enum import Enum
from uuid import UUID, uuid4


def _now_utc() -> datetime:
    return datetime.now(timezone.utc)


class ProcessoStatus(str, Enum):
    RASCUNHO = "RASCUNHO"
    DFD_ELABORACAO = "DFD_ELABORACAO"
    PESQUISA_PRECO = "PESQUISA_PRECO"
    ETP_ELABORACAO = "ETP_ELABORACAO"
    TR_ELABORACAO = "TR_ELABORACAO"
    EDITAL_ELABORACAO = "EDITAL_ELABORACAO"
    PARECER_JURIDICO = "PARECER_JURIDICO"
    PUBLICADO = "PUBLICADO"
    EM_ANDAMENTO = "EM_ANDAMENTO"
    HOMOLOGADO = "HOMOLOGADO"
    CONTRATADO = "CONTRATADO"
    EM_FISCALIZACAO = "EM_FISCALIZACAO"
    CONCLUIDO = "CONCLUIDO"
    SUSPENSO = "SUSPENSO"
    ANULADO = "ANULADO"
    CANCELADO = "CANCELADO"


class ProcessoModalidade(str, Enum):
    PREGAO_ELETRONICO = "PREGAO_ELETRONICO"
    PREGAO_PRESENCIAL = "PREGAO_PRESENCIAL"
    CONCORRENCIA = "CONCORRENCIA"
    DISPENSA = "DISPENSA"
    INEXIGIBILIDADE = "INEXIGIBILIDADE"


TRANSICOES_VALIDAS: dict[ProcessoStatus, set[ProcessoStatus]] = {
    ProcessoStatus.RASCUNHO: {ProcessoStatus.DFD_ELABORACAO, ProcessoStatus.CANCELADO},
    ProcessoStatus.DFD_ELABORACAO: {ProcessoStatus.PESQUISA_PRECO, ProcessoStatus.CANCELADO},
    ProcessoStatus.PESQUISA_PRECO: {ProcessoStatus.ETP_ELABORACAO, ProcessoStatus.CANCELADO},
    ProcessoStatus.ETP_ELABORACAO: {ProcessoStatus.TR_ELABORACAO, ProcessoStatus.CANCELADO},
    ProcessoStatus.TR_ELABORACAO: {ProcessoStatus.EDITAL_ELABORACAO, ProcessoStatus.CANCELADO},
    ProcessoStatus.EDITAL_ELABORACAO: {ProcessoStatus.PARECER_JURIDICO, ProcessoStatus.CANCELADO},
    ProcessoStatus.PARECER_JURIDICO: {
        ProcessoStatus.PUBLICADO, ProcessoStatus.EDITAL_ELABORACAO, ProcessoStatus.CANCELADO
    },
    ProcessoStatus.PUBLICADO: {
        ProcessoStatus.EM_ANDAMENTO, ProcessoStatus.SUSPENSO, ProcessoStatus.ANULADO
    },
    ProcessoStatus.EM_ANDAMENTO: {
        ProcessoStatus.HOMOLOGADO, ProcessoStatus.SUSPENSO, ProcessoStatus.ANULADO
    },
    ProcessoStatus.HOMOLOGADO: {ProcessoStatus.CONTRATADO, ProcessoStatus.ANULADO},
    ProcessoStatus.CONTRATADO: {ProcessoStatus.EM_FISCALIZACAO, ProcessoStatus.ANULADO},
    ProcessoStatus.EM_FISCALIZACAO: {ProcessoStatus.CONCLUIDO},
    ProcessoStatus.CONCLUIDO: set(),
    ProcessoStatus.SUSPENSO: {ProcessoStatus.EM_ANDAMENTO, ProcessoStatus.ANULADO},
    ProcessoStatus.ANULADO: set(),
    ProcessoStatus.CANCELADO: set(),
}


@dataclass
class Processo:
    id: UUID = field(default_factory=uuid4)
    tenant_id: UUID = field(default_factory=uuid4)
    numero_ano: str | None = None
    objeto: str = ""
    categoria: str = ""
    modalidade: ProcessoModalidade = ProcessoModalidade.PREGAO_ELETRONICO
    status: ProcessoStatus = ProcessoStatus.RASCUNHO
    valor_estimado: Decimal | None = None
    valor_homologado: Decimal | None = None
    data_inicio: date | None = None
    area_requisitante: str | None = None
    responsavel_id: UUID | None = None
    created_at: datetime = field(default_factory=_now_utc)
    updated_at: datetime = field(default_factory=_now_utc)

    def pode_transicionar_para(self, novo: ProcessoStatus) -> bool:
        return novo in TRANSICOES_VALIDAS.get(self.status, set())

    def transicionar_para(self, novo: ProcessoStatus) -> None:
        if not self.pode_transicionar_para(novo):
            raise ValueError(
                f"Transição inválida: {self.status.value} -> {novo.value}"
            )
        self.status = novo
        self.updated_at = _now_utc()

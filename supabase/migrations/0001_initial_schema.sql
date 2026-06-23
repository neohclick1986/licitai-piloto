-- LicitaI Piloto - Schema inicial (Pregão Eletrônico)
-- Migration: 0001_initial_schema.sql
-- Supabase: roda via `supabase db push` ou no SQL Editor

-- ============================================================================
-- EXTENSÕES
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "vector";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================================
-- ENUMS
-- ============================================================================
CREATE TYPE tenant_esfera AS ENUM ('FEDERAL', 'ESTADUAL', 'MUNICIPAL');
CREATE TYPE user_role AS ENUM (
    'ADMIN_TENANT', 'DEMANDANTE', 'PREGOEIRO', 'ANALISTA_TECNICO',
    'ANALISTA_JURIDICO', 'GESTOR_CONTRATOS', 'FISCAL_CONTRATO',
    'CONTROLADORIA', 'DPO'
);

CREATE TYPE processo_status AS ENUM (
    'RASCUNHO', 'DFD_ELABORACAO', 'PESQUISA_PRECO', 'ETP_ELABORACAO',
    'TR_ELABORACAO', 'EDITAL_ELABORACAO', 'PARECER_JURIDICO',
    'PUBLICADO', 'EM_ANDAMENTO', 'HOMOLOGADO', 'CONTRATADO',
    'EM_FISCALIZACAO', 'CONCLUIDO', 'SUSPENSO', 'ANULADO', 'CANCELADO'
);

CREATE TYPE processo_modalidade AS ENUM (
    'PREGAO_ELETRONICO', 'PREGAO_PRESENCIAL', 'CONCORRENCIA',
    'CONCURSO', 'LEILAO', 'DIALOGO_COMPETITIVO',
    'DISPENSA', 'INEXIGIBILIDADE'
);

CREATE TYPE fonte_tipo AS ENUM (
    'PNCP', 'COMPRAS_GOV', 'ARP', 'CONTRATO_INTERNO', 'MANUAL'
);

CREATE TYPE parecer_resultado AS ENUM (
    'FAVORAVEL', 'FAVORAVEL_COM_RESSALVAS', 'CONTRARIO', 'INVIABILIDADE'
);

CREATE TYPE contrato_status AS ENUM (
    'RASCUNHO', 'VIGENTE', 'SUSPENSO', 'ENCERRADO',
    'RESCINDIDO', 'ADITADO', 'VENCIDO'
);

-- ============================================================================
-- TABELAS
-- ============================================================================

-- Tenants (órgãos)
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cnpj CHAR(14) UNIQUE NOT NULL,
    razao_social VARCHAR(255) NOT NULL,
    nome_fantasia VARCHAR(255),
    esfera tenant_esfera NOT NULL,
    uf CHAR(2),
    municipio_cod_ibge VARCHAR(7),
    endereco JSONB,
    config JSONB DEFAULT '{}'::jsonb,
    ativo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Users (vinculados ao Supabase auth.users)
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    nome VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    role user_role NOT NULL,
    orgao_lotacao VARCHAR(255),
    cargo VARCHAR(255),
    telefone VARCHAR(20),
    mfa_enabled BOOLEAN DEFAULT FALSE,
    ativo BOOLEAN DEFAULT TRUE,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, email)
);

CREATE INDEX idx_users_tenant ON users(tenant_id);
CREATE INDEX idx_users_email ON users(email);

-- Processos
CREATE TABLE processos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    numero_ano VARCHAR(50),
    objeto TEXT NOT NULL,
    categoria VARCHAR(50),
    modalidade processo_modalidade NOT NULL DEFAULT 'PREGAO_ELETRONICO',
    criterio_julgamento VARCHAR(50) DEFAULT 'MENOR_PRECO',
    status processo_status NOT NULL DEFAULT 'RASCUNHO',
    valor_estimado NUMERIC(18,2),
    valor_homologado NUMERIC(18,2),
    data_inicio DATE DEFAULT CURRENT_DATE,
    data_publicacao_edital DATE,
    data_homologacao DATE,
    area_requisitante VARCHAR(255),
    responsavel_id UUID REFERENCES users(id),
    pca_item_id UUID,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_processos_tenant_status ON processos(tenant_id, status);
CREATE INDEX idx_processos_tenant_created ON processos(tenant_id, created_at DESC);

-- Artefatos (versões de documentos)
CREATE TABLE artefatos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    processo_id UUID NOT NULL REFERENCES processos(id) ON DELETE CASCADE,
    tipo VARCHAR(50) NOT NULL,
    versao INT NOT NULL DEFAULT 1,
    titulo VARCHAR(255),
    conteudo_texto TEXT,
    storage_path VARCHAR(500),
    hash_sha256 CHAR(64) NOT NULL,
    gerado_por_user_id UUID REFERENCES users(id),
    gerado_por_ia BOOLEAN DEFAULT FALSE,
    ai_generation_id UUID,
    parent_versao_id UUID REFERENCES artefatos(id),
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(processo_id, tipo, versao)
);

CREATE INDEX idx_artefatos_processo_tipo ON artefatos(processo_id, tipo);

-- DFD
CREATE TABLE dfd (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    processo_id UUID NOT NULL UNIQUE REFERENCES processos(id) ON DELETE CASCADE,
    artefato_id UUID NOT NULL REFERENCES artefatos(id),
    area_requisitante VARCHAR(255) NOT NULL,
    responsavel_id UUID NOT NULL REFERENCES users(id),
    objeto TEXT NOT NULL,
    justificativa TEXT NOT NULL,
    quantidade NUMERIC(18,4),
    unidade_medida VARCHAR(50),
    valor_estimado NUMERIC(18,2) NOT NULL,
    prazo_entrega_dias INT,
    destino VARCHAR(500),
    classificacao VARCHAR(50) DEFAULT 'BEM_COMUM',
    nivel_risco VARCHAR(20) DEFAULT 'BAIXO',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_dfd_tenant ON dfd(tenant_id);

-- Catálogo de itens
CREATE TABLE catalogo_itens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    codigo VARCHAR(50) NOT NULL,
    tipo VARCHAR(20) NOT NULL,
    descricao TEXT NOT NULL,
    unidade_medida VARCHAR(50),
    classe VARCHAR(100),
    embedding vector(1536),
    ativo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, codigo)
);

CREATE INDEX idx_catalogo_embedding ON catalogo_itens
    USING ivfflat (embedding vector_cosine_ops);

-- Pesquisa de Preços
CREATE TABLE pesquisas_preco (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    processo_id UUID NOT NULL REFERENCES processos(id) ON DELETE CASCADE,
    artefato_id UUID NOT NULL REFERENCES artefatos(id),
    item_catalogo_id UUID REFERENCES catalogo_itens(id),
    descricao_item TEXT NOT NULL,
    quantidade NUMERIC(18,4),
    unidade_medida VARCHAR(50),
    valor_minimo NUMERIC(18,2),
    valor_maximo NUMERIC(18,2),
    valor_medio NUMERIC(18,2),
    valor_mediano NUMERIC(18,2),
    valor_adotado NUMERIC(18,2),
    metodo_calculo VARCHAR(50),
    total_fontes_validas INT DEFAULT 0,
    total_fontes_consultadas INT DEFAULT 0,
    estatistica JSONB,
    metodologia_justificativa TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_pesquisas_processo ON pesquisas_preco(processo_id);

CREATE TABLE pesquisa_preco_fontes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    pesquisa_id UUID NOT NULL REFERENCES pesquisas_preco(id) ON DELETE CASCADE,
    fonte_tipo fonte_tipo NOT NULL,
    fonte_id_externo VARCHAR(255),
    fonte_url VARCHAR(1000),
    fornecedor_cnpj CHAR(14),
    fornecedor_razao_social VARCHAR(255),
    descricao_item TEXT,
    valor_unitario NUMERIC(18,2) NOT NULL,
    data_referencia DATE,
    data_coleta TIMESTAMPTZ DEFAULT NOW(),
    valido BOOLEAN DEFAULT TRUE,
    motivo_exclusao TEXT,
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_fontes_pesquisa ON pesquisa_preco_fontes(pesquisa_id);

-- ETP
CREATE TABLE etp (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    processo_id UUID NOT NULL UNIQUE REFERENCES processos(id) ON DELETE CASCADE,
    artefato_id UUID NOT NULL REFERENCES artefatos(id),
    descricao_necessidade TEXT NOT NULL,
    area_requisitante VARCHAR(255) NOT NULL,
    requisitos_tecnicos TEXT,
    estimativas_quantidades JSONB,
    analise_alternativas JSONB,
    solucao_escolhida TEXT NOT NULL,
    justificativa_solucao TEXT NOT NULL,
    parcelamento TEXT,
    resultados_pretendidos TEXT,
    impactos_ambientais TEXT,
    analise_risco JSONB,
    nivel_risco VARCHAR(20) DEFAULT 'BAIXO',
    checklist_conformidade JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- TR
CREATE TABLE tr (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    processo_id UUID NOT NULL UNIQUE REFERENCES processos(id) ON DELETE CASCADE,
    artefato_id UUID NOT NULL REFERENCES artefatos(id),
    etp_id UUID NOT NULL REFERENCES etp(id),
    definicao_objeto TEXT NOT NULL,
    forma_execucao TEXT,
    prazo_execucao_dias INT,
    local_entrega VARCHAR(500),
    condicoes_pagamento TEXT,
    habilitacao JSONB,
    criterios_julgamento TEXT,
    criterios_medicao JSONB,
    sancoes JSONB,
    gestao_fiscalizacao TEXT,
    clausulas_lgpd TEXT,
    clausulas_sustentabilidade TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Edital
CREATE TABLE editais (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    processo_id UUID NOT NULL UNIQUE REFERENCES processos(id) ON DELETE CASCADE,
    artefato_id UUID NOT NULL REFERENCES artefatos(id),
    numero VARCHAR(50),
    modalidade processo_modalidade NOT NULL,
    criterio_julgamento VARCHAR(50) NOT NULL,
    data_sessao_publica TIMESTAMPTZ,
    prazo_proposta_dias INT DEFAULT 8,
    regime_execucao VARCHAR(50),
    tipo_objeto VARCHAR(50) DEFAULT 'COMUM',
    beneficios_me_epp BOOLEAN DEFAULT TRUE,
    pncp_id_publicacao VARCHAR(255),
    data_publicacao_pncp TIMESTAMPTZ,
    data_homologacao DATE,
    conteudo_minuta TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pareceres
CREATE TABLE pareceres (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    processo_id UUID NOT NULL REFERENCES processos(id) ON DELETE CASCADE,
    artefato_id UUID NOT NULL REFERENCES artefatos(id),
    procurador_id UUID REFERENCES users(id),
    resultado parecer_resultado NOT NULL,
    resumo_executivo TEXT,
    analise_texto TEXT NOT NULL,
    checklist JSONB,
    riscos_juridicos JSONB,
    citacoes JSONB,
    prazo_atendimento TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_pareceres_processo ON pareceres(processo_id);

-- Fornecedores
CREATE TABLE fornecedores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    cnpj CHAR(14) NOT NULL,
    razao_social VARCHAR(255) NOT NULL,
    nome_fantasia VARCHAR(255),
    porte VARCHAR(20),
    endereco JSONB,
    contato JSONB,
    regularidade_fiscal JSONB,
    ativo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, cnpj)
);

-- Contratos
CREATE TABLE contratos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    processo_id UUID NOT NULL REFERENCES processos(id),
    artefato_id UUID NOT NULL REFERENCES artefatos(id),
    numero VARCHAR(50) NOT NULL,
    objeto TEXT NOT NULL,
    natureza VARCHAR(50) DEFAULT 'COMPRA',
    fornecedor_id UUID NOT NULL REFERENCES fornecedores(id),
    valor_inicial NUMERIC(18,2) NOT NULL,
    valor_atual NUMERIC(18,2) NOT NULL,
    data_assinatura DATE NOT NULL,
    data_vigencia_inicio DATE NOT NULL,
    data_vigencia_fim DATE NOT NULL,
    gestor_id UUID REFERENCES users(id),
    fiscal_id UUID REFERENCES users(id),
    pncp_id_publicacao VARCHAR(255),
    status contrato_status NOT NULL DEFAULT 'RASCUNHO',
    clausulas_lgpd JSONB,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, numero)
);

CREATE INDEX idx_contratos_tenant_status ON contratos(tenant_id, status);

-- AI Generations (audit trail)
CREATE TABLE ai_generations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    artefato_id UUID REFERENCES artefatos(id) ON DELETE SET NULL,
    crew VARCHAR(50) NOT NULL,
    agent_name VARCHAR(100) NOT NULL,
    provider VARCHAR(50) NOT NULL,
    model VARCHAR(100) NOT NULL,
    prompt_hash CHAR(64) NOT NULL,
    prompt_texto TEXT,
    response_hash CHAR(64) NOT NULL,
    response_texto TEXT,
    chain_of_thought JSONB,
    citacoes JSONB,
    tokens_input INT,
    tokens_output INT,
    custo_estimado NUMERIC(10,4),
    latencia_ms INT,
    temperatura DECIMAL(3,2) DEFAULT 0.2,
    human_reviewed BOOLEAN DEFAULT FALSE,
    human_reviewer_id UUID REFERENCES users(id),
    human_decision VARCHAR(20),
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ai_gen_tenant_created ON ai_generations(tenant_id, created_at DESC);

-- Audit Log (append-only)
CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    aggregate_type VARCHAR(50) NOT NULL,
    aggregate_id UUID NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    actor_id UUID REFERENCES users(id),
    actor_ip INET,
    actor_user_agent TEXT,
    payload JSONB NOT NULL,
    hash_prev CHAR(64),
    hash_self CHAR(64) NOT NULL,
    occurred_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_aggregate ON audit_log(tenant_id, aggregate_type, aggregate_id, occurred_at);
CREATE INDEX idx_audit_actor ON audit_log(tenant_id, actor_id, occurred_at DESC);

-- Trigger para imutabilidade
CREATE OR REPLACE FUNCTION prevent_audit_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'audit_log is append-only';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER no_update_audit BEFORE UPDATE ON audit_log
    FOR EACH ROW EXECUTE FUNCTION prevent_audit_modification();
CREATE TRIGGER no_delete_audit BEFORE DELETE ON audit_log
    FOR EACH ROW EXECUTE FUNCTION prevent_audit_modification();

-- RAG: Knowledge Base
CREATE TABLE kb_documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID, -- NULL = global (legislação)
    tipo VARCHAR(50) NOT NULL,
    titulo VARCHAR(500) NOT NULL,
    fonte_url VARCHAR(1000),
    data_publicacao DATE,
    hash_conteudo CHAR(64) NOT NULL,
    conteudo_texto TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE kb_chunks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID,
    document_id UUID NOT NULL REFERENCES kb_documents(id) ON DELETE CASCADE,
    chunk_index INT NOT NULL,
    texto TEXT NOT NULL,
    embedding vector(1536),
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_kb_chunks_embedding ON kb_chunks
    USING ivfflat (embedding vector_cosine_ops);
CREATE INDEX idx_kb_chunks_doc ON kb_chunks(document_id, chunk_index);

-- Outbox
CREATE TABLE outbox (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    aggregate_id UUID NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    target VARCHAR(50) NOT NULL,
    payload JSONB NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    attempts INT NOT NULL DEFAULT 0,
    last_error TEXT,
    sent_at TIMESTAMPTZ,
    next_retry_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_outbox_pending ON outbox(status, next_retry_at)
    WHERE status = 'PENDING';

-- ============================================================================
-- ROW-LEVEL SECURITY (Multi-tenancy)
-- ============================================================================

-- Helper: obter tenant_id da sessão (configurado via SET LOCAL)
CREATE OR REPLACE FUNCTION current_tenant_id()
RETURNS UUID AS $$
BEGIN
    RETURN current_setting('app.tenant_id', TRUE)::UUID;
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE;

-- Habilitar RLS nas tabelas multi-tenant
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE processos ENABLE ROW LEVEL SECURITY;
ALTER TABLE artefatos ENABLE ROW LEVEL SECURITY;
ALTER TABLE dfd ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalogo_itens ENABLE ROW LEVEL SECURITY;
ALTER TABLE pesquisas_preco ENABLE ROW LEVEL SECURITY;
ALTER TABLE pesquisa_preco_fontes ENABLE ROW LEVEL SECURITY;
ALTER TABLE etp ENABLE ROW LEVEL SECURITY;
ALTER TABLE tr ENABLE ROW LEVEL SECURITY;
ALTER TABLE editais ENABLE ROW LEVEL SECURITY;
ALTER TABLE pareceres ENABLE ROW LEVEL SECURITY;
ALTER TABLE fornecedores ENABLE ROW LEVEL SECURITY;
ALTER TABLE contratos ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_generations ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE outbox ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY tenant_isolation ON users
    FOR ALL USING (tenant_id = current_tenant_id());

CREATE POLICY tenant_isolation ON processos
    FOR ALL USING (tenant_id = current_tenant_id());

CREATE POLICY tenant_isolation ON artefatos
    FOR ALL USING (tenant_id = current_tenant_id());

CREATE POLICY tenant_isolation ON dfd
    FOR ALL USING (tenant_id = current_tenant_id());

CREATE POLICY tenant_isolation ON catalogo_itens
    FOR ALL USING (tenant_id = current_tenant_id());

CREATE POLICY tenant_isolation ON pesquisas_preco
    FOR ALL USING (tenant_id = current_tenant_id());

CREATE POLICY tenant_isolation ON pesquisa_preco_fontes
    FOR ALL USING (tenant_id = current_tenant_id());

CREATE POLICY tenant_isolation ON etp
    FOR ALL USING (tenant_id = current_tenant_id());

CREATE POLICY tenant_isolation ON tr
    FOR ALL USING (tenant_id = current_tenant_id());

CREATE POLICY tenant_isolation ON editais
    FOR ALL USING (tenant_id = current_tenant_id());

CREATE POLICY tenant_isolation ON pareceres
    FOR ALL USING (tenant_id = current_tenant_id());

CREATE POLICY tenant_isolation ON fornecedores
    FOR ALL USING (tenant_id = current_tenant_id());

CREATE POLICY tenant_isolation ON contratos
    FOR ALL USING (tenant_id = current_tenant_id());

CREATE POLICY tenant_isolation ON ai_generations
    FOR ALL USING (tenant_id = current_tenant_id());

CREATE POLICY tenant_isolation ON audit_log
    FOR ALL USING (tenant_id = current_tenant_id());

CREATE POLICY tenant_isolation ON outbox
    FOR ALL USING (tenant_id = current_tenant_id());

-- KB: leitura pública para tenant
CREATE POLICY kb_tenant_read ON kb_documents
    FOR SELECT USING (tenant_id IS NULL OR tenant_id = current_tenant_id());

CREATE POLICY kb_tenant_read ON kb_chunks
    FOR SELECT USING (tenant_id IS NULL OR tenant_id = current_tenant_id());

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Updated_at automático
CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at BEFORE UPDATE ON tenants
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON processos
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON dfd
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON etp
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON tr
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON editais
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON contratos
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- ============================================================================
-- VIEWS
-- ============================================================================

-- View: processos com último status e valor
CREATE VIEW vw_processos_resumo AS
SELECT
    p.id,
    p.tenant_id,
    p.numero_ano,
    p.objeto,
    p.modalidade,
    p.status,
    p.valor_estimado,
    p.valor_homologado,
    p.data_inicio,
    p.created_at,
    EXISTS(SELECT 1 FROM dfd d WHERE d.processo_id = p.id) AS tem_dfd,
    EXISTS(SELECT 1 FROM pesquisas_preco pp WHERE pp.processo_id = p.id) AS tem_pesquisa,
    EXISTS(SELECT 1 FROM etp e WHERE e.processo_id = p.id) AS tem_etp,
    EXISTS(SELECT 1 FROM tr t WHERE t.processo_id = p.id) AS tem_tr,
    EXISTS(SELECT 1 FROM editais ed WHERE ed.processo_id = p.id) AS tem_edital,
    EXISTS(SELECT 1 FROM pareceres pa WHERE pa.processo_id = p.id) AS tem_parecer,
    EXISTS(SELECT 1 FROM contratos c WHERE c.processo_id = p.id) AS tem_contrato
FROM processos p
WHERE p.deleted_at IS NULL;

COMMENT ON TABLE tenants IS 'Órgãos públicos (multi-tenant)';
COMMENT ON TABLE processos IS 'Processos licitatórios - aggregate root';
COMMENT ON TABLE artefatos IS 'Versões de documentos gerados (DFD, ETP, TR, etc.)';
COMMENT ON TABLE ai_generations IS 'Audit trail de todas as gerações de IA';
COMMENT ON TABLE audit_log IS 'Log imutável de eventos do sistema (chain hash)';
COMMENT ON TABLE kb_chunks IS 'Chunks de texto vetorizados para RAG';

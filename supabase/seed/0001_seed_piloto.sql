-- LicitaI Piloto - Seed para 1 órgão piloto
-- Este arquivo cria dados de exemplo para validação
-- IDEMPOTENTE: pode ser rodado múltiplas vezes

-- ============================================================================
-- TENANT PILOTO
-- ============================================================================
INSERT INTO tenants (id, cnpj, razao_social, nome_fantasia, esfera, uf, municipio_cod_ibge, endereco)
VALUES (
    '11111111-1111-1111-1111-111111111111',
    '12345678000190',
    'Município de São José do Rio Preto',
    'Prefeitura de S. J. do Rio Preto',
    'MUNICIPAL',
    'SP',
    '3549805',
    jsonb_build_object(
        'logradouro', 'Av. Alberto Andaló',
        'numero', '3030',
        'bairro', 'Centro',
        'cep', '15015-000',
        'municipio', 'São José do Rio Preto',
        'uf', 'SP'
    )
) ON CONFLICT (cnpj) DO NOTHING;

-- ============================================================================
-- ITENS DE CATÁLOGO (5 itens mais comuns em prefeituras)
-- ============================================================================
INSERT INTO catalogo_itens (tenant_id, codigo, tipo, descricao, unidade_medida, classe) VALUES
('11111111-1111-1111-1111-111111111111', 'CATMAT-0001', 'MATERIAL', 'Papel A4 75g/m² branco cx 5000fl', 'caixa', 'Material de Escritório'),
('11111111-1111-1111-1111-111111111111', 'CATMAT-0002', 'MATERIAL', 'Toner para impressora HP LaserJet Pro M404', 'unidade', 'Material de Escritório'),
('11111111-1111-1111-1111-111111111111', 'CATMAT-0003', 'MATERIAL', 'Caneta esferográfica azul 1.0mm', 'unidade', 'Material de Escritório'),
('11111111-1111-1111-1111-111111111111', 'CATSER-0001', 'SERVICO', 'Serviço de limpeza e conservação predial com fornecimento de materiais', 'mês', 'Serviço Contínuo'),
('11111111-1111-1111-1111-111111111111', 'CATSER-0002', 'SERVICO', 'Serviço de vigilância patrimonial armada diurna 12x36h', 'posto', 'Serviço Contínuo')
ON CONFLICT (tenant_id, codigo) DO NOTHING;

-- ============================================================================
-- PROCESSOS MODELO (5 processos em estados diferentes para validação)
-- ============================================================================

-- Processo 1: Rascunho (vazio)
INSERT INTO processos (id, tenant_id, numero_ano, objeto, categoria, status, area_requisitante)
VALUES (
    'aaaaaaaa-0001-0000-0000-000000000001',
    '11111111-1111-1111-1111-111111111111',
    '2026/00001',
    'Aquisição de papel A4 para uso administrativo',
    'MATERIAL',
    'RASCUNHO',
    'Secretaria de Administração'
) ON CONFLICT (id) DO NOTHING;

-- Processo 2: DFD pronto, aguardando pesquisa
INSERT INTO processos (id, tenant_id, numero_ano, objeto, categoria, status, valor_estimado, area_requisitante)
VALUES (
    'aaaaaaaa-0002-0000-0000-000000000002',
    '11111111-1111-1111-1111-111111111111',
    '2026/00002',
    'Contratação de empresa para limpeza predial',
    'SERVICO_CONTINUO',
    'DFD_ELABORACAO',
    240000.00,
    'Secretaria de Educação'
) ON CONFLICT (id) DO NOTHING;

-- Processo 3: Pesquisa pronta, gerando ETP
INSERT INTO processos (id, tenant_id, numero_ano, objeto, categoria, status, valor_estimado, area_requisitante)
VALUES (
    'aaaaaaaa-0003-0000-0000-000000000003',
    '11111111-1111-1111-1111-111111111111',
    '2026/00003',
    'Aquisição de toners para impressoras',
    'MATERIAL',
    'PESQUISA_PRECO',
    8500.00,
    'Secretaria de Saúde'
) ON CONFLICT (id) DO NOTHING;

-- Processo 4: Edital publicado, em homologação
INSERT INTO processos (id, tenant_id, numero_ano, objeto, categoria, modalidade, status, valor_estimado, valor_homologado, data_publicacao_edital, area_requisitante)
VALUES (
    'aaaaaaaa-0004-0000-0000-000000000004',
    '11111111-1111-1111-1111-111111111111',
    '2026/00004',
    'Aquisição de canetas esferográficas para programas sociais',
    'MATERIAL',
    'PREGAO_ELETRONICO',
    'EM_ANDAMENTO',
    3200.00,
    2870.00,
    '2026-05-15',
    'Secretaria de Assistência Social'
) ON CONFLICT (id) DO NOTHING;

-- Processo 5: Contrato em fiscalização
INSERT INTO processos (id, tenant_id, numero_ano, objeto, categoria, modalidade, status, valor_estimado, valor_homologado, data_publicacao_edital, data_homologacao, area_requisitante)
VALUES (
    'aaaaaaaa-0005-0000-0000-000000000005',
    '11111111-1111-1111-1111-111111111111',
    '2026/00005',
    'Serviço de vigilância patrimonial - Paço Municipal',
    'SERVICO_CONTINUO',
    'PREGAO_ELETRONICO',
    'CONTRATADO',
    180000.00,
    165000.00,
    '2026-02-10',
    '2026-03-05',
    'Secretaria de Administração'
) ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- FORNECEDOR DE EXEMPLO
-- ============================================================================
INSERT INTO fornecedores (tenant_id, cnpj, razao_social, nome_fantasia, porte, endereco, contato)
VALUES (
    '11111111-1111-1111-1111-111111111111',
    '98765432000110',
    'Distribuidora Rio Preto Ltda',
    'Rio Papel',
    'ME',
    jsonb_build_object('logradouro', 'Rua XV de Novembro', 'numero', '1000', 'cidade', 'São José do Rio Preto', 'uf', 'SP'),
    jsonb_build_object('telefone', '1732011234', 'email', 'contato@riopapel.com.br')
) ON CONFLICT (tenant_id, cnpj) DO NOTHING;

INSERT INTO fornecedores (tenant_id, cnpj, razao_social, nome_fantasia, porte, endereco, contato)
VALUES (
    '11111111-1111-1111-1111-111111111111',
    '11222333000144',
    'Vigilância Segura Ltda',
    'Vigilância Segura',
    'EPP',
    jsonb_build_object('logradouro', 'Av. Brigadeiro Faria Lima', 'numero', '5000', 'cidade', 'São Paulo', 'uf', 'SP'),
    jsonb_build_object('telefone', '1130305050', 'email', 'comercial@vigilanciasegura.com.br')
) ON CONFLICT (tenant_id, cnpj) DO NOTHING;

-- ============================================================================
-- KNOWLEDGE BASE: Lei 14.133/2021 (trechos selecionados para o piloto)
-- ============================================================================

INSERT INTO kb_documents (id, tenant_id, tipo, titulo, fonte_url, data_publicacao, hash_conteudo, conteudo_texto, metadata)
VALUES (
    'bbbbbbbb-0001-0000-0000-000000000001',
    NULL,
    'LEI',
    'Lei 14.133/2021 - Lei de Licitações e Contratos Administrativos',
    'https://www.planalto.gov.br/ccivil_03/_ato2019-2022/2021/lei/l14133.htm',
    '2021-04-01',
    encode(digest('lei_14133_2021', 'sha256'), 'hex'),
    'Lei 14.133/2021 completa - texto integral',
    jsonb_build_object('esfera', 'FEDERAL', 'orgao', 'Presidência da República', 'vigente', true)
) ON CONFLICT (id) DO NOTHING;

-- Chunk 1: art. 12 (DFD)
INSERT INTO kb_chunks (tenant_id, document_id, chunk_index, texto, metadata) VALUES
(NULL, 'bbbbbbbb-0001-0000-0000-000000000001', 1,
'Art. 12. O processo de licitação observará as seguintes fases, em sequência:
I - preparatória;
II - de divulgação do edital de licitação;
III - de apresentação de propostas e lances, quando for o caso;
IV - de julgamento;
V - de habilitação;
VI - recursal;
VII - de homologação.
§ 1º A fase preparatória do processo licitatório é caracterizada pelo planejamento e deve compatibilizar-se com o plano de contratações anual de que trata o art. 12 da Lei nº 14.133, de 1º de abril de 2021, e com as leis orçamentárias, e se inicia com a fase de planejamento.',
jsonb_build_object('artigo', '12', 'topico', 'Fases do processo')
) ON CONFLICT (id) DO NOTHING;

-- Chunk 2: art. 18 (ETP)
INSERT INTO kb_chunks (tenant_id, document_id, chunk_index, texto, metadata) VALUES
(NULL, 'bbbbbbbb-0001-0000-0000-000000000001', 2,
'Art. 18. A fase preparatória do processo licitatório é caracterizada pelo planejamento e deve compatibilizar-se com o plano de contratações anual, e com as leis orçamentárias, e se inicia com a fase de planejamento.
§ 1º O estudo técnico preliminar a que se refere o inciso I do caput deste artigo deverá ser elaborado quando:
I - A Administração identificar a necessidade de licitação;
II - A solução escolhida for adequada à satisfação do interesse público.
§ 2º O estudo técnico preliminar conterá os seguintes elementos:
I - Descrição da necessidade da contratação;
II - Área requisitante;
III - Requisitos da contratação;
IV - Estimativas das quantidades;
V - Levantamento de mercado e análise de alternativas;
VI - Solução escolhida e justificativa;
VII - Parcelamento ou não da solução;
VIII - Resultados pretendidos;
IX - Providências para adequação do ambiente;
X - Análise de riscos;
XI - Viabilidade da contratação.',
jsonb_build_object('artigo', '18', 'topico', 'Estudo Técnico Preliminar', 'paragrafo', '1 e 2')
) ON CONFLICT (id) DO NOTHING;

-- Chunk 3: art. 23 (Pesquisa de Preços)
INSERT INTO kb_chunks (tenant_id, document_id, chunk_index, texto, metadata) VALUES
(NULL, 'bbbbbbbb-0001-0000-0000-000000000001', 3,
'Art. 23. O valor previamente estimado da contratação será compatível com os valores praticados pelo mercado, considerados os preços constantes de bancos de dados públicos, as quantidades a serem contratadas, o potencial de economia com a licitação e a vantajosidade para a Administração.
§ 1º A pesquisa de preços será precedida de ampla pesquisa em, no mínimo, 3 (três) fontes idôneas, podendo ser:
I - contratações similares feitas pela Administração Pública;
II - bases de dados públicas e privadas de preços;
III - dados de pesquisa publicada em mídia especializada;
IV - dados de sítios eletrônicos de fornecedores;
V - dados de tabelas de referência.
§ 2º Na pesquisa de preços, sempre que possível, deverão ser observadas as condições comerciais praticadas pelo futuro contratado, incluindo prazos, locais, garantias, qualidade e especificações dos produtos.',
jsonb_build_object('artigo', '23', 'topico', 'Pesquisa de Preços')
) ON CONFLICT (id) DO NOTHING;

-- Chunk 4: art. 28 (Modalidades)
INSERT INTO kb_chunks (tenant_id, document_id, chunk_index, texto, metadata) VALUES
(NULL, 'bbbbbbbb-0001-0000-0000-000000000001', 4,
'Art. 28. São modalidades de licitação:
I - pregão;
II - concorrência;
III - concurso;
IV - leilão;
V - diálogo competitivo.
Parágrafo único. A definição da modalidade cabível será feita em função da natureza do objeto e do valor estimado da contratação, observados os limites estabelecidos nesta Lei.',
jsonb_build_object('artigo', '28', 'topico', 'Modalidades de Licitação')
) ON CONFLICT (id) DO NOTHING;

-- Chunk 5: art. 29 (Pregão)
INSERT INTO kb_chunks (tenant_id, document_id, chunk_index, texto, metadata) VALUES
(NULL, 'bbbbbbbb-0001-0000-0000-000000000001', 5,
'Art. 29. A modalidade pregão, na forma eletrônica, será utilizada para a aquisição de bens e a contratação de serviços comuns, incluídos os serviços comuns de engenharia, e se aplica a todas as hipóteses de licitação em que a Administração possa utilizar o critério de julgamento por menor preço ou maior desconto.
Parágrafo único. O pregão, na forma presencial, será utilizado quando, comprovada a inviabilidade técnica ou a desvantagem para a Administração, não for possível a utilização da forma eletrônica.',
jsonb_build_object('artigo', '29', 'topico', 'Pregão Eletrônico')
) ON CONFLICT (id) DO NOTHING;

-- Chunk 6: art. 33 (Critérios de Julgamento)
INSERT INTO kb_chunks (tenant_id, document_id, chunk_index, texto, metadata) VALUES
(NULL, 'bbbbbbbb-0001-0000-0000-000000000001', 6,
'Art. 33. O julgamento observará os seguintes critérios:
I - menor preço;
II - melhor técnica ou conteúdo artístico;
III - técnica e preço;
IV - maior retorno econômico;
V - maior desconto;
VI - melhor proposta;
VII - melhor destinação de bens alienados.
§ 1º Para os casos previstos neste artigo, quando se tratar de bens e serviços especiais, o julgamento será por melhor técnica ou técnica e preço, considerando-se, para os bens e serviços comuns, o de menor preço ou maior desconto.',
jsonb_build_object('artigo', '33', 'topico', 'Critérios de Julgamento')
) ON CONFLICT (id) DO NOTHING;

-- Chunk 7: art. 6 (Definições - TR)
INSERT INTO kb_chunks (tenant_id, document_id, chunk_index, texto, metadata) VALUES
(NULL, 'bbbbbbbb-0001-0000-0000-000000000001', 7,
'Art. 6º Para os fins desta Lei, consideram-se:
XXIII - termo de referência: documento necessário para a contratação de bens e serviços, que deve conter:
a) definição do objeto;
b) forma de execução;
c) prazo de execução;
d) local de entrega;
e) condições de pagamento;
f) habilitação técnica, fiscal, social e trabalhista;
g) habilitação econômica e financeira;
h) critérios de julgamento;
i) critérios de aceitabilidade;
j) critérios de medição e pagamento;
k) sanções administrativas.',
jsonb_build_object('artigo', '6', 'inciso', 'XXIII', 'topico', 'Termo de Referência')
) ON CONFLICT (id) DO NOTHING;

-- Chunk 8: art. 92 (Contratos - cláusulas obrigatórias)
INSERT INTO kb_chunks (tenant_id, document_id, chunk_index, texto, metadata) VALUES
(NULL, 'bbbbbbbb-0001-0000-0000-000000000001', 8,
'Art. 92. São necessárias em todo contrato cláusulas que estabeleçam:
I - o objeto e seus elementos característicos;
II - o regime de execução ou a forma de fornecimento;
III - o preço e as condições de pagamento, os critérios, a data-base e a periodicidade do reajustamento de preços;
IV - os prazos de início de cada etapa de execução, de conclusão, de entrega, de observação e de recebimento definitivo, quando for o caso;
V - o crédito pelo qual correrá a despesa, com a indicação da classificação funcional programática e da categoria econômica;
VI - as garantias oferecidas para assegurar a plena execução do objeto contratual, quando exigidas;
VII - os direitos e as responsabilidades das partes;
VIII - as penalidades cabíveis e os valores das multas;
IX - os casos de rescisão;
X - a obrigação do contratado de manter, durante toda a execução do contrato, em compatibilidade com as obrigações assumidas, todas as condições de habilitação e qualificação exigidas na licitação;
XI - a forma de pagamento da contraprestação da execução do objeto contratual;
XII - a fiscalização da execução do contrato;
XIII - o foro da sede da Administração para dirimir qualquer questão contratual.',
jsonb_build_object('artigo', '92', 'topico', 'Cláusulas obrigatórias do contrato')
) ON CONFLICT (id) DO NOTHING;

-- Chunk 9: art. 117 (Fiscalização)
INSERT INTO kb_chunks (tenant_id, document_id, chunk_index, texto, metadata) VALUES
(NULL, 'bbbbbbbb-0001-0000-0000-000000000001', 9,
'Art. 117. A execução dos contratos deverá ser acompanhada e fiscalizada por 1 (um) ou mais fiscais do contrato, representantes da Administração especialmente designados conforme requisitos estabelecidos no art. 7º desta Lei, ou pelos respectivos substitutos, permitida a contratação de terceiros para assisti-los e subsidiá-los com informações pertinentes a essa atribuição.
§ 1º O fiscal do contrato anotará em registro próprio todas as ocorrências relacionadas à execução do contrato, determinando o que for necessário para a regularização das faltas ou dos defeitos observados.
§ 2º O fiscal do contrato informará a seus superiores, em tempo hábil para a adoção das medidas convenientes, a situação que demandar decisão ou providência que ultrapasse sua competência.',
jsonb_build_object('artigo', '117', 'topico', 'Fiscalização do contrato')
) ON CONFLICT (id) DO NOTHING;

-- Chunk 10: art. 53 (Análise Jurídica)
INSERT INTO kb_chunks (tenant_id, document_id, chunk_index, texto, metadata) VALUES
(NULL, 'bbbbbbbb-0001-0000-0000-000000000001', 10,
'Art. 53. Ao órgão jurídico da Administração, preferencialmente, caberá:
I - assessorar a Comissão de Contratação ou o pregoeiro e a autoridade competente na fase de planejamento;
II - elaborar minutos de editais, contratos, acordos, convênios e ajustes;
III - apreciar, em caráter terminativo, a legalidade dos atos da fase de julgamento e das propostas de adjudicação e homologação, de modo a resguardar a Administração de irregularidades que possam comprometer o certame licitatório.',
jsonb_build_object('artigo', '53', 'topico', 'Análise Jurídica')
) ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- FINAL: mensagem de sucesso
-- ============================================================================
DO $$
DECLARE
    total_tenant INTEGER;
    total_processos INTEGER;
    total_itens INTEGER;
    total_kb INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_tenant FROM tenants WHERE id = '11111111-1111-1111-1111-111111111111';
    SELECT COUNT(*) INTO total_processos FROM processos WHERE tenant_id = '11111111-1111-1111-1111-111111111111';
    SELECT COUNT(*) INTO total_itens FROM catalogo_itens WHERE tenant_id = '11111111-1111-1111-1111-111111111111';
    SELECT COUNT(*) INTO total_kb FROM kb_chunks WHERE tenant_id IS NULL;

    RAISE NOTICE '========================================';
    RAISE NOTICE 'Seed concluído:';
    RAISE NOTICE '  Tenants: %', total_tenant;
    RAISE NOTICE '  Processos: %', total_processos;
    RAISE NOTICE '  Itens de catálogo: %', total_itens;
    RAISE NOTICE '  Chunks de KB: %', total_kb;
    RAISE NOTICE '========================================';
END $$;

# LicitaI — Piloto Pregão Eletrônico

> **Status:** Piloto MVP (8 semanas) — escopo focado em **Pregão Eletrônico** com 1 órgão-piloto.
> **Stack:** Supabase (Postgres + pgvector + Auth + Storage) + FastAPI + Next.js 15 + CrewAI/LLM.

---
## Status

[![GitHub](https://img.shields.io/badge/GitHub-neohclick1986%2Flicitai--piloto-blue)](https://github.com/neohclick1986/licitai-piloto)
**Repositório:** https://github.com/neohclick1986/licitai-piloto


## 1. O que está pronto

```
licitai-piloto/
├── supabase/                          # Backend como serviço (Supabase)
│   ├── migrations/0001_initial_schema.sql   # Schema completo + RLS multi-tenant
│   └── seed/0001_seed_piloto.sql             # 1 tenant, 5 processos modelo, 10 chunks KB
├── apps/
│   ├── api/                           # FastAPI (Clean Architecture)
│   │   ├── src/
│   │   │   ├── main.py               # Bootstrap
│   │   │   ├── settings.py           # Config (env vars)
│   │   │   ├── core/entities/        # Domínio
│   │   │   ├── infrastructure/db/    # SQLAlchemy + RLS
│   │   │   ├── application/use_cases/# Use cases
│   │   │   └── interfaces/api/v1/    # REST controllers
│   │   ├── requirements.txt
│   │   └── Dockerfile
│   └── web/                           # Next.js 15
│       └── src/app/
│           ├── page.tsx              # Lista de processos
│           ├── processos/novo/       # Criar processo
│           ├── processos/[id]/       # Detalhe + navegação por fase
│           └── processos/[id]/dfd/   # Formulário DFD + resultado IA
├── packages/
│   └── agents/
│       ├── llm/provider.py           # OpenAI + Ollama (plugável)
│       └── crews/crew_dfd.py         # Primeira crew funcional
├── infra/
│   ├── docker/docker-compose.yml     # API + Web + Ollama
│   └── scripts/
│       ├── setup.sh                  # Setup completo
│       └── smoke.sh                  # Testes iniciais
├── .env.example                       # Variáveis de ambiente
└── README.md                          # Este arquivo
```

---

## 2. Quickstart (5 passos)

### Passo 1 — Criar projeto Supabase

1. Acesse https://app.supabase.com e crie um projeto
2. Anote: `Project URL`, `anon key`, `service_role key` (Settings → API)
3. Anote: connection string do Postgres (Settings → Database)

### Passo 2 — Clonar e configurar

```bash
cd licitai-piloto
cp .env.example .env
# Editar .env com seus valores do Supabase
nano .env
```

### Passo 3 — Aplicar schema + seed

**Opção A (com Supabase CLI — recomendado):**
```bash
brew install supabase/tap/supabase   # ou apt/scoop
supabase link --project-ref SEU-REF
supabase db push
```

**Opção B (manual):**
- Abra SQL Editor no painel Supabase
- Cole e rode `supabase/migrations/0001_initial_schema.sql`
- Cole e rode `supabase/seed/0001_seed_piloto.sql`

### Passo 4 — Subir backend + frontend

```bash
docker compose -f infra/docker/docker-compose.yml up
```

Aguarde ~2 min (npm install no container web). Quando os serviços estiverem prontos:
- API: http://localhost:8000/docs
- Web: http://localhost:3000
- Ollama: http://localhost:11434 (se habilitado)

### Passo 5 — Criar primeiro usuário e testar

1. **No Supabase Auth** (Authentication → Users → Add user): crie um usuário com e-mail/senha
2. **No SQL Editor** do Supabase, vincule ao tenant:

```sql
INSERT INTO users (id, tenant_id, nome, email, role)
VALUES (
    'COLE-O-UUID-DO-AUTH-USERS-AQUI',
    '11111111-1111-1111-1111-111111111111',
    'Seu Nome',
    'seu@email.com',
    'ADMIN_TENANT'
);
```

3. Acesse http://localhost:3000, faça login e teste.

---

## 3. Funcionalidades implementadas (MVP)

| Fase | Status | Observação |
|---|---|---|
| **DFD** | ✅ Funcional | Com e sem IA |
| **Pesquisa de Preços** | ⏳ Stub | Próximo sprint |
| **ETP** | ⏳ Stub | Próximo sprint |
| **TR** | ⏳ Stub | Próximo sprint |
| **Edital** | ⏳ Stub | Próximo sprint |
| **Análise Jurídica** | ⏳ Stub | Sprint 3 |
| **Contratos** | ⏳ Stub | Sprint 3 |
| **Fiscalização** | ⏳ Stub | Sprint 4 |

**Multi-tenancy:** ✅ RLS ativo em todas as 17 tabelas
**Auditoria:** ✅ Audit log com hash chain
**AI Provider:** ✅ OpenAI + Ollama (escolha por env)
**Humano no loop:** ✅ IA nunca aprova sozinha (configurável)

---

## 4. Testando a Crew-DFD (IA)

```bash
# 1. Login
TOKEN=$(curl -X POST "https://SEU-REF.supabase.co/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"seu@email.com","password":"senha"}' | jq -r '.access_token')

# 2. Criar DFD com IA
curl -X POST http://localhost:8000/api/v1/dfd/ \
  -H "Authorization: Bearer *** \
  -H "Content-Type: application/json" \
  -d '{
    "processo_id": "aaaaaaaa-0001-0000-0000-000000000001",
    "area_requisitante": "Secretaria de Administração",
    "objeto": "Aquisição de papel A4 75g/m² branco para uso administrativo",
    "justificativa": "Reposição de estoque consumido no exercício anterior. Em 2025 foram consumidos 540 pacotes; projeção 2026 é de 500 pacotes considerando digitalização parcial.",
    "quantidade": 500,
    "unidade_medida": "pacote",
    "valor_estimado": 12500.00,
    "prazo_entrega_dias": 30,
    "destino": "Almoxarifado Central",
    "usar_ia": true
  }' | jq
```

**Resposta esperada:**

```json
{
  "dfd_id": "uuid-...",
  "versao_revisada": {
    "objeto": "Aquisição de 500 (quinhentos) pacotes de papel A4 75g/m²...",
    "nivel_risco": "BAIXO"
  },
  "checklist": [
    {"item": "Identificação do requisitante (art. 12, §1º, I)", "status": "✓", "observacao": "..."},
    ...
  ],
  "perguntas_para_demandante": ["..."],
  "citacoes": [{"fonte": "Lei 14.133/2021, art. 12, §1º", "trecho_relevante": "..."}],
  "parecer_agente": "DFD está em conformidade com o art. 12...",
  "ia_usada": true,
  "tokens_usados": {"input": 450, "output": 1200}
}
```

---

## 5. Conexão via Composio

Se você usa **Composio** com GitHub e Supabase configurados:

```bash
# Conectar repositório
composio push --repo licitai-piloto

# Sincronizar schema com Supabase
composio supabase push --project-ref SEU-REF

# Disparar deploy
composio deploy --target vercel
```

(Comandos variam conforme a configuração do seu Composio. Os scripts `infra/scripts/setup.sh` e `smoke.sh` automatizam o que puder.)

---

## 6. Customizando o LLM

### Opção A — OpenAI (recomendado para piloto)
```bash
LLM_DEFAULT_PROVIDER=openai
OPENAI_API_KEY=sk-......
OPENAI_MODEL=gpt-4o
```

### Opção B — Ollama local (grátis, sem cloud)
```bash
LLM_DEFAULT_PROVIDER=ollama
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=llama3.1:8b
```

Baixar modelo:
```bash
docker exec -it licitai-ollama ollama pull llama3.1:8b
```

### Opção C — Modelo nacional
Adicionar `SabiaProvider` em `packages/agents/llm/provider.py` (Maritaca AI / Sabiá 3).

---

## 7. Roadmap do piloto (4 sprints)

| Sprint | Semanas | Entregas |
|---|---|---|
| ✅ S0 | 0 | Schema, Auth, RLS, Crew-DFD, Frontend base |
| 🔄 S1 | 1-2 | + Pesquisa de Preços + ETP + RAG real (Lei 14.133) |
| ⏳ S2 | 3-4 | + TR + Edital + 3 crews operacionais |
| ⏳ S3 | 5-6 | + Análise Jurídica com IA + Contratos + PNCP |
| ⏳ S4 | 7-8 | + Fiscalização + alertas + ajustes + go-live |

---

## 8. Métricas de sucesso do piloto

| Métrica | Meta |
|---|---|
| Tempo médio de DFD | < 5 min (vs 1 semana) |
| Aceitação da versão da IA sem edição | > 60% |
| Checklist conforme em 1ª tentativa | > 80% |
| NPS dos usuários | > 30 |
| Processos completos até ETP | > 5 no primeiro mês |

---

## 9. Estrutura de testes

```bash
# Validar sintaxe
python -c "import ast; ast.parse(open('apps/api/src/main.py').read())"

# Smoke test
./infra/scripts/smoke.sh

# Testes unitários (quando existirem)
cd apps/api && pytest
```

---

## 10. Documentação adicional

| Documento | Conteúdo |
|---|---|
| [docs/01-composio-verificacao.md](docs/01-composio-verificacao.md) | Relatório da verificação do Composio no ambiente |
| [docs/02-github-setup.md](docs/02-github-setup.md) | Como subir para o GitHub (3 opções) |
| [docs/03-coolify-deploy.md](docs/03-coolify-deploy.md) | Passo a passo de deploy no Coolify |

---

## 11. Próximos passos sugeridos

1. **Subir para o GitHub** — ver [docs/02-github-setup.md](docs/02-github-setup.md)
2. **Deploy no Coolify** — ver [docs/03-coolify-deploy.md](docs/03-coolify-deploy.md)
3. **Rodar o setup** (Passo 1-5 acima) e validar o smoke test
4. **Criar 3-5 DFDs reais** do seu órgão-piloto
5. **Avaliar a qualidade** das versões geradas pela IA
6. **Ajustar o prompt** da Crew-DFD com base no feedback (em `packages/agents/crews/crew_dfd.py`)
7. **Subir a Crew-Pesquisa** (próximo sprint)
8. **Adicionar mais chunks da Lei 14.133** ao RAG (em `supabase/seed/`)

---

> Construído por **Neoh** — Arquiteto de Soluções GovTech + IA.
> Versão: 0.1.0 · Licença: AGPL-3.0

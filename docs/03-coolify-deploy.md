# Deploy do LicitaI no Coolify

> **Coolify** é um PaaS open-source self-hosted (alternativa ao Heroku, Vercel, Netlify). Roda no seu servidor/VPS. Suporta Docker, Docker Compose, e diversos frameworks.

---

## 1. Visão geral da arquitetura no Coolify

```
                          ┌─────────────────────────────────┐
                          │      Seu Servidor / VPS         │
                          │      (Ubuntu 22.04+)            │
                          │                                 │
                          │  ┌──────────────────────────┐   │
                          │  │       Coolify            │   │
                          │  │  (painel web :8000)      │   │
                          │  └──────────┬───────────────┘   │
                          │             │                   │
                          │   ┌─────────┴────────┐          │
                          │   │                  │          │
                          │  ┌▼────────┐   ┌─────▼──────┐  │
                          │  │  API    │   │   Web      │  │
                          │  │  :8000  │   │   :3000    │  │
                          │  │ (FastAPI)│   │ (Next.js)  │  │
                          │  └────┬────┘   └────────────┘  │
                          │       │                        │
                          │       ▼                        │
                          │  ┌──────────┐                  │
                          │  │ Supabase │ ← cloud-hosted   │
                          │  │ (Postgres│   (recomendado)  │
                          │  │ +pgvector)                  │
                          │  └──────────┘                  │
                          └─────────────────────────────────┘
```

**Recomendação:** Supabase fica **fora** do Coolify (é gerenciado). Coolify só roda a **API** e o **Web** do LicitaI. Isso simplifica backup, upgrades e escalabilidade.

---

## 2. Pré-requisitos

### 2.1 Servidor

- **Mínimo:** 2 vCPU, 4 GB RAM, 40 GB SSD
- **Recomendado:** 4 vCPU, 8 GB RAM, 80 GB SSD
- **Sistema:** Ubuntu 22.04 LTS ou Debian 12
- **Porta aberta:** 80, 443, 22 (SSH)
- **Domínio:** apontar DNS para o IP do servidor (opcional, mas recomendado)

Opções de VPS (qualquer um serve):
- Hetzner (€4/mês, melhor custo-benefício na Europa)
- DigitalOcean ($6/mês, droplets em SP/AS)
- Contabo (€4.50/mês)
- Oracle Cloud (free tier: 4 vCPU, 24 GB RAM, **GRÁTIS para sempre**)
- AWS Lightsail ($3.50/mês)

### 2.2 Conta no Supabase

1. https://app.supabase.com → **New project**
2. Escolha região (São Paulo se disponível, ou US East)
3. Defina senha do DB (anote!)
4. Aguarde 2-3 minutos

### 2.3 Conta no GitHub com o repo `licitai-piloto`

Ver `docs/02-github-setup.md`.

### 2.4 Provedor de LLM

- **OpenAI** (paga): pegue API key em https://platform.openai.com
- **Ollama local** (grátis): se Coolify rodar no mesmo servidor, pode usar

---

## 3. Instalação do Coolify

### 3.1 No servidor (Ubuntu 22.04)

```bash
# 1. Conectar via SSH
ssh root@SEU-SERVIDOR

# 2. Atualizar
apt update && apt upgrade -y

# 3. Instalar dependências
apt install -y curl wget git

# 4. Instalar Coolify (script oficial)
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
```

Aguarde ~5 minutos. O script instala Docker, Traefik (proxy reverso) e o painel Coolify.

### 3.2 Acessar o painel

```
http://SEU-IP:8000
```

- Crie sua conta de admin
- Salve o token de API (em **Settings → API Tokens**)

### 3.3 Configurar domínio (opcional, recomendado)

Em **Settings → Server → FQDN**, defina o domínio (ex: `coolify.licitai.gov.br`) e configure o DNS:

```
Tipo A: coolify.licitai.gov.br → SEU-IP
```

Coolify gera certificados Let's Encrypt automaticamente.

---

## 4. Deploy do LicitaI no Coolify

Você tem **3 caminhos** — escolha o melhor para seu caso:

| Caminho | Quando usar | Dificuldade |
|---|---|---|
| **A) Dockerfile único (API + Web)** | Piloto simples, dev | Baixa |
| **B) Docker Compose (2 serviços)** | Produção pequena/média | Média |
| **C) Git + Buildpacks separados** | Produção, escalável | Alta |

**Recomendação:** Comece com **A** no piloto, migre para **B** na V1.

---

### Caminho A — Dockerfile único (recomendado para piloto)

#### A.1 Criar serviço

1. No painel Coolify, **+ New → Application**
2. Selecione **GitHub** como source
3. Conecte sua conta GitHub (OAuth)
4. Selecione o repo `licitai-piloto`
5. Branch: `main`
6. **Build Pack:** Dockerfile
7. **Dockerfile Location:** `apps/api/Dockerfile`
8. **Port:** `8000`
9. **Healthcheck Path:** `/api/v1/health`

#### A.2 Variáveis de ambiente

Em **Environment Variables**, adicione:

```env
ENVIRONMENT=production
LOG_LEVEL=INFO
DEBUG=false

# Supabase
SUPABASE_URL=https://SEU-REF.supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...
SUPABASE_JWT_SECRET=seu-jwt-secret-aqui
SUPABASE_DB_URL=postgresql+asyncpg://postgres:SENHA@db.SEU-REF.supabase.co:5432/postgres

# Segurança
SECRET_KEY=GERE-UM-VALOR-ALEATORIO-DE-64-CHARS
CORS_ORIGINS=["https://licitai-web.exemplo.com.br"]

# LLM
LLM_DEFAULT_PROVIDER=openai
OPENAI_API_KEY=sk-...

# Features
ENABLE_RLS=true
ENABLE_AI=true
AI_REQUIRE_HUMAN_APPROVAL=true
```

Para gerar uma SECRET_KEY forte:
```bash
python3 -c "import secrets; print(secrets.token_urlsafe(64))"
```

#### A.3 Deploy

1. Clique em **Deploy**
2. Coolify faz `git clone` + `docker build` + `docker run`
3. Acompanhe os logs (deve terminar com `Uvicorn running on http://0.0.0.0:8000`)
4. Coolify gera uma URL pública: `https://generate-name-123.coolify.io` ou seu domínio

#### A.4 Validar

```bash
# Health check
curl https://sua-url/api/v1/health/detailed

# Resposta esperada
{
  "status": "ok",
  "app": "LicitaI API - Piloto",
  "version": "0.1.0",
  "db": "ok",
  "llm_provider": "openai",
  "ai_enabled": true
}
```

#### A.5 Para o frontend (em outro serviço)

1. **+ New → Application** (de novo)
2. Mesmo repo, branch `main`
3. **Build Pack:** Dockerfile
4. **Dockerfile Location:** `apps/web/Dockerfile`
5. **Port:** `3000`
6. Variáveis de ambiente:
   ```env
   NEXT_PUBLIC_SUPABASE_URL=https://SEU-REF.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
   NEXT_PUBLIC_API_URL=https://sua-url-da-api/api/v1
   ```
7. Deploy

---

### Caminho B — Docker Compose

#### B.1 Estrutura no Coolify

Coolify suporta **Docker Compose como Service**. Você pode usar o `infra/docker/docker-compose.yml` que já existe (mas precisa adaptá-lo).

#### B.2 Adaptar para Coolify

Crie um arquivo `docker-compose.coolify.yml` na raiz:

```yaml
# LicitaI - Docker Compose para Coolify
# Uso: este arquivo é referenciado pelo Coolify

version: "3.9"

services:
  api:
    build:
      context: .
      dockerfile: apps/api/Dockerfile
    container_name: licitai-api-${COOLIFY_RESOURCE_UUID}
    environment:
      ENVIRONMENT: production
      SUPABASE_URL: ${SUPABASE_URL}
      SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY}
      SUPABASE_SERVICE_ROLE_KEY: ${SUPABASE_SERVICE_ROLE_KEY}
      SUPABASE_JWT_SECRET: ${SUPABASE_JWT_SECRET}
      SUPABASE_DB_URL: ${SUPABASE_DB_URL}
      SECRET_KEY: ${SECRET_KEY}
      CORS_ORIGINS: ${CORS_ORIGINS}
      LLM_DEFAULT_PROVIDER: ${LLM_DEFAULT_PROVIDER:-openai}
      OPENAI_API_KEY: ${OPENAI_API_KEY}
      ENABLE_RLS: "true"
      ENABLE_AI: "true"
    ports:
      - "8000"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/v1/health"]
      interval: 30s
      timeout: 5s
      retries: 3
    restart: unless-stopped

  web:
    build:
      context: .
      dockerfile: apps/web/Dockerfile
    container_name: licitai-web-${COOLIFY_RESOURCE_UUID}
    environment:
      NEXT_PUBLIC_SUPABASE_URL: ${SUPABASE_URL}
      NEXT_PUBLIC_SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY}
      NEXT_PUBLIC_API_URL: ${API_PUBLIC_URL}/api/v1
    ports:
      - "3000"
    depends_on:
      - api
    restart: unless-stopped
```

#### B.3 No Coolify

1. **+ New → Docker Compose**
2. Source: GitHub → `licitai-piloto`
3. Branch: `main`
4. **Compose File:** `docker-compose.coolify.yml`
5. **Domain:** `licitai.exemplo.com.br` (gera SSL automático)
6. **Env vars:** cole as do `.env.example`
7. Deploy

---

### Caminho C — Buildpacks separados (Nixpacks)

Coolify detecta automaticamente o tipo de projeto. Para o LicitaI, porém, é mais fácil usar Dockerfile.

---

## 5. Configuração de DNS e domínio

### 5.1 Subdomínios sugeridos

```
api.licitai.exemplo.com.br    → serviço API (porta 8000)
web.licitai.exemplo.com.br    → serviço Web (porta 3000)
```

### 5.2 Registros DNS

```
Tipo A    api     SEU-IP
Tipo A    web     SEU-IP
```

(Também funciona wildcard: `*.licitai.exemplo.com.br` → SEU-IP)

### 5.3 No Coolify

Em cada serviço, na aba **Domains**:
- Adicione `api.licitai.exemplo.com.br` para a API
- Adicione `web.licitai.exemplo.com.br` para o Web
- Coolify provisiona TLS via Let's Encrypt automaticamente

---

## 6. Configurando o Supabase

### 6.1 Aplicar as migrations

**Opção A — Painel do Supabase (manual):**
1. https://app.supabase.com → seu projeto
2. **SQL Editor → New query**
3. Cole o conteúdo de `supabase/migrations/0001_initial_schema.sql`
4. **Run** (deve terminar sem erros)
5. Nova query com `supabase/seed/0001_seed_piloto.sql`
6. **Run**

**Opção B — Supabase CLI (se tiver no seu host):**
```bash
cd /workspace/licitai-piloto
supabase link --project-ref SEU-REF
supabase db push
```

**Opção C — Via Coolify como job (automatizado):**
Adicione um serviço **One-time Job** que roda o SQL. Coolify executa uma vez e desliga.

### 6.2 Configurar RLS no Supabase

RLS já vem ativo nas migrations. Verificar em:
**Authentication → Policies** → `tenant_isolation` deve aparecer em cada tabela.

### 6.3 Configurar Auth (OIDC Gov.br — V2)

Para o piloto, use email/senha. Para V2, configurar Gov.br:
1. Authentication → Providers → adicione OIDC
2. Issuer: `https://sso.staging.acesso.gov.br`
3. Client ID/Secret: obtido no https://sso.acesso.gov.br

---

## 7. CI/CD — Deploy automático

### 7.1 Webhook do GitHub → Coolify

Em cada serviço Coolify:
- **Webhooks → View Webhook URL** → copie
- Vá no GitHub → repo → Settings → Webhooks → Add
- Cole a URL
- Content type: `application/json`
- Events: `push`
- Coolify vai rebuildar e fazer redeploy a cada push em `main`

### 7.2 GitHub Actions (alternativa)

Já tem `.github/workflows/` (preparado). Crie `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Coolify

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Coolify deploy
        run: |
          curl -X POST "${{ secrets.COOLIFY_WEBHOOK_URL }}" \
            -H "Content-Type: application/json" \
            -d '{"ref":"refs/heads/main"}'
```

---

## 8. Monitoramento

### 8.1 Logs

Coolify mostra logs em tempo real. Para logs persistentes:

- **Settings → Service → Logs** → "Persistent Logs" ON
- Coolify grava em `/data/coolify/logs/`

### 8.2 Alertas

Coolify tem alertas via email e Discord/Slack. Configurar em:
**Team Settings → Notifications**.

### 8.3 Métricas

Coolify expõe métricas via Docker. Para Prometheus/Grafana:
- **New Resource → Service → Docker Image:** `prom/prometheus`
- Adicione scrape config apontando para os containers

---

## 9. Backups

### 9.1 Do Coolify

- **Settings → Backups** → ativar backup automático do servidor
- Destino: S3, Backblaze B2, ou rsync para outro servidor

### 9.2 Do Supabase (fonte de verdade dos dados)

- O Supabase faz backup automático diário
- Plano Pro: PITR (Point-in-Time Recovery) até 7 dias
- **Sempre tenha cópia off-site** (S3 + criptografia)

### 9.3 Dos artefatos

- Objetos do Storage (PDFs, anexos) ficam no Supabase Storage
- Mesma política de backup

---

## 10. Custos estimados

| Item | Custo mensal |
|---|---|
| **VPS Hetzner CPX11** (2 vCPU, 4 GB) | €4 (~R$ 22) |
| **VPS Hetzner CPX21** (4 vCPU, 8 GB) | €8 (~R$ 44) |
| **Supabase Free** | $0 (até 500 MB, 50k rows) |
| **Supabase Pro** | $25 (~R$ 125) |
| **OpenAI API** (piloto) | ~$20-50/mês |
| **Domínio .gov.br** | R$ 40/ano (cobrado uma vez) |
| **Total estimado (piloto)** | **~R$ 200-300/mês** |

**Versão gratuita total:** Hetzner (1 mês grátis) + Supabase Free + Ollama local + domínio só quando for oficial = **R$ 0** no primeiro mês.

---

## 11. Checklist de go-live

Antes de abrir para usuários:

### 11.1 Segurança
- [ ] SECRET_KEY gerada com 64+ chars
- [ ] SUPABASE_JWT_SECRET preenchido (Settings → API → JWT Settings)
- [ ] Todas as env vars preenchidas (sem defaults)
- [ ] RLS ativo e testado (tente acessar dados de outro tenant)
- [ ] HTTPS funcionando em todos os subdomínios
- [ ] CORS restrito ao domínio do web
- [ ] Backups automáticos ativos
- [ ] Logs não expõem secrets

### 11.2 Funcional
- [ ] `/api/v1/health/detailed` retorna `db: ok`
- [ ] Login no Supabase funciona
- [ ] User criado na tabela `users` vinculado ao auth
- [ ] Criar processo via UI funciona
- [ ] Criar DFD via UI funciona
- [ ] DFD com IA retorna checklist + citacoes
- [ ] Audit log tem eventos sendo registrados

### 11.3 Operacional
- [ ] Coolify backup configurado
- [ ] Alertas de downtime configurados
- [ ] Documentação de runbook (já tem em `docs/09-operacao/`)
- [ ] Equipe de plantão definida
- [ ] Canal de suporte aberto

---

## 12. Próximos passos após o piloto

1. **Migrar de Supabase Free para Pro** (quando atingir 80% dos limites)
2. **Adicionar CDN** (Cloudflare) na frente
3. **Configurar WAF** (Cloudflare WAF ou ModSecurity)
4. **Adicionar observabilidade** (Sentry para erros, Grafana Cloud para métricas)
5. **Migrar Ollama para servidor GPU dedicado** (quando volume justificar)
6. **Setup de disaster recovery** (servidor backup em outra região)

---

## 13. Troubleshooting

### "Connection refused" no Supabase
- Verifique `SUPABASE_DB_URL` (formato: `postgresql+asyncpg://postgres:SENHA@db.REF.supabase.co:5432/postgres`)
- Senha do DB: definida na criação do projeto no Supabase

### "401 Unauthorized" em todo endpoint autenticado
- `SUPABASE_JWT_SECRET` ausente ou incorreto (obtenha em Settings → API → JWT Settings)
- Sem ele a API nem inicia; se inicia mas rejeita tokens, o secret está errado

### "RLS violation" mesmo logado
- O `tenant_id` não está sendo setado
- Verifique o `get_db_with_tenant` está sendo chamado em **toda** query

### IA não responde
- Verifique `OPENAI_API_KEY` está válida
- Veja os logs: deve aparecer `LLM call failed: ...`

### CORS error no browser
- `CORS_ORIGINS` deve incluir o domínio exato do web
- Não use `*` em produção

### Build falha no Coolify
- Veja os logs: geralmente falta uma env var
- O Dockerfile usa `python:3.12-slim` — Coolify já tem Docker, OK

---

> **Documento vivo.** Atualize conforme o piloto evolui. Próximo: `docs/04-runbook-producao.md` (quando entrar em produção).

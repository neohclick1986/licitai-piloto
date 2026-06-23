# Subindo o LicitaI Piloto para o GitHub

**3 opções, do mais simples ao mais robusto.** Escolha a que cabe no seu ambiente.

---

## Opção 1 — Usando Composio (a que você planejou)

Pré-requisito: Composio autenticado (ver `docs/01-composio-verificacao.md`).

```bash
# 1. Verificar auth
composio whoami

# 2. Criar repo público no GitHub
composio github create-repo \
  --name licitai-piloto \
  --description "LicitaI - Piloto Pregão Eletrônico (GovTech SaaS)" \
  --private false

# 3. Adicionar remote
cd /workspace/licitai-piloto
composio git remote add origin https://github.com/SEU-USER/licitai-piloto.git

# 4. Push
composio git push -u origin main

# 5. Confirmar
composio github list-repos
```

**Vantagem:** fluxo único, Composio gerencia tudo.
**Desvantagem:** se Composio quebrar (como aconteceu agora), você trava.

---

## Opção 2 — Usando `gh` (GitHub CLI) — **recomendado**

A `gh` CLI é mantida pelo GitHub, é oficial, e funciona offline (cacheia credenciais).

### Passo 1 — Instalar `gh`

```bash
# macOS
brew install gh

# Ubuntu / Debian
sudo apt update && sudo apt install gh

# Fedora / RHEL
sudo dnf install gh

# Windows (scoop)
scoop install gh
```

Verificar:
```bash
gh --version
# gh version 2.65.0 (2024-11-04) ou superior
```

### Passo 2 — Autenticar

```bash
gh auth login
```

Respostas:
- `What account do you want to log into?` → **GitHub.com**
- `What is your preferred protocol for Git operations?` → **HTTPS**
- `Authenticate Git with your GitHub credentials?` → **Yes**
- `How would you like to authenticate GitHub CLI?` → **Login with a web browser**

Vai aparecer um código (ex: `ABC-1234`). Aperte Enter, abra a URL, cole o código, autorize.

Verificar:
```bash
gh auth status
# Logged in to github.com as SEU-USER
```

### Passo 3 — Criar o repositório

```bash
cd /workspace/licitai-piloto

# Cria o repo e faz push de uma vez
gh repo create licitai-piloto \
  --public \
  --description "LicitaI - Piloto Pregão Eletrônico (GovTech SaaS multiagente)" \
  --source=. \
  --remote=origin \
  --push
```

Saída esperada:
```
✓ Created repository SEU-USER/licitai-piloto on GitHub
✓ Added remote https://github.com/SEU-USER/licitai-piloto.git
✓ Pushed commits to https://github.com/SEU-USER/licitai-piloto.git
```

### Passo 4 — Confirmar

```bash
# Ver o repo no navegador
gh repo view --web

# Ou listar os arquivos via CLI
gh repo view SEU-USER/licitai-piloto

# Ver os commits remotos
git log --oneline origin/main
```

---

## Opção 3 — Manual com Personal Access Token (PAT)

Útil quando não dá pra instalar `gh` (containers restritos, air-gap, etc.).

### Passo 1 — Gerar o PAT

1. Acesse https://github.com/settings/tokens
2. **Generate new token → Fine-grained tokens** (recomendado) ou **Classic**
3. Configurações:
   - **Note:** `LicitaI piloto`
   - **Expiration:** 90 dias (ou no expiration, sua escolha)
   - **Repository access:** Public repositories (e/ou só o licitai-piloto)
   - **Permissions:**
     - Contents: Read and Write
     - Metadata: Read-only (default)
4. Clique em **Generate token**
5. **Copie o token** (começa com `ghp_` para classic, `github_pat_` para fine-grained)
   - Você **NÃO** vai vê-lo de novo.

### Passo 2 — Configurar o remote

```bash
cd /workspace/licitai-piloto

# Criar o repo pelo navegador em https://github.com/new
# (não inicialize com README, .gitignore ou license — já temos tudo)

# Adicionar remote com PAT
git remote add origin https://SEU-USER:ghp_SEU_TOKEN@github.com/SEU-USER/licitai-piloto.git
```

⚠️ **ATENÇÃO**: o PAT vai ficar na URL. Para evitar expor em logs:
```bash
# Melhor: usar credential helper
git config --global credential.helper store
# Ou: usar o gh auth (Opção 2) que gerencia isso pra você
```

### Passo 3 — Push

```bash
git push -u origin main
```

### Passo 4 — Limpar (opcional)

```bash
# Remove o PAT do remote e configura para perguntar
git remote set-url origin https://github.com/SEU-USER/licitai-piloto.git

# Próximo push vai pedir credenciais
git push
```

---

## Passo a passo universal (qualquer opção)

### Após o push, faça no GitHub:

1. **Configurar branch protection** (Settings → Branches → Add rule):
   - Branch name pattern: `main`
   - ☑ Require a pull request before merging
   - ☑ Require approvals: 1
   - ☑ Require status checks to pass before merging
   - ☑ Require linear history

2. **Adicionar topics** (About → ⚙ → Topics):
   - `govtech`, `licitacoes`, `ia`, `crewai`, `langgraph`, `supabase`, `fastapi`, `nextjs`, `lei-14133`

3. **Configurar Secrets** (Settings → Secrets and variables → Actions):
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `SUPABASE_DB_URL`
   - `OPENAI_API_KEY`
   - `SECRET_KEY`

4. **Adicionar descrição curta** (About):
   > SaaS GovTech de automação de processos licitatórios. Multiagentes de IA (CrewAI), conforme Lei 14.133/2021, multi-tenant com RLS.

5. **Habilitar GitHub Pages** (opcional, para docs):
   - Settings → Pages → Source: `Deploy from a branch`
   - Branch: `main`, folder: `/docs` (se quiser)

6. **Habilitar Discussions** (opcional, para Q&A):
   - Settings → General → Features → ☑ Discussions

---

## Verificações pós-push

```bash
# 1. Verificar o remote
cd /workspace/licitai-piloto
git remote -v

# 2. Verificar status
git status

# 3. Confirmar que os 6 commits estão lá
git log --oneline origin/main

# 4. Ver a árvore completa
git ls-tree -r --name-only origin/main | head -30
```

Resultado esperado:
```
1ea3d30 chore: bootstrap do projeto (gitignore, env example, README)
72dd13c feat(db): schema inicial Supabase com RLS multi-tenant
a3de4a1 feat(api): backend FastAPI com Clean Architecture
5bf6f83 feat(agents): Crew-DFD funcional + LLM provider plugavel
dff9cd3 feat(web): frontend Next.js 15 (TypeScript + Tailwind)
3b0e32d feat(infra): docker-compose + scripts de setup/smoke
```

---

## Troubleshooting

### `remote: Repository not found`
- O repo não existe OU você não tem acesso
- Crie em https://github.com/new

### `Permission denied (publickey)`
- Você está tentando usar SSH mas não configurou a chave
- Troque para HTTPS: `git remote set-url origin https://github.com/SEU-USER/licitai-piloto.git`

### `Support for password authentication was removed`
- O GitHub removeu autenticação por senha em 2021
- **Use PAT** (Opção 3) ou **gh CLI** (Opção 2)

### `fatal: refusing to merge unrelated histories`
- O remote tem commits que você não tem localmente
- `git pull origin main --rebase` (depois `git push`)

### Push muito lento
- O repo tem LFS ou arquivos grandes
- Configure `.gitattributes` para excluir node_modules e outros
- (Já feito no `.gitignore`)

---

## Próximo passo

Depois do push, vá para `docs/03-coolify-deploy.md` — o guia completo de deploy no Coolify.

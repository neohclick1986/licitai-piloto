# Verificação do Composio — Relatório

**Data:** Junho/2026
**Ambiente:** `/workspace` (host Linux, Python 3.12.13)

---

## TL;DR

**O Composio está instalado mas NÃO está autenticado/configurado neste ambiente.** A versão instalada tem incompatibilidade com a API atual. Para usar Composio com GitHub/Supabase você precisa configurar do zero.

---

## 1. Inventário do ambiente

### 1.1 Ferramentas presentes

| Ferramenta | Versão | Status |
|---|---|---|
| `python3` | 3.12.13 | ✅ Disponível |
| `pip3` | 25.0.1 | ✅ Disponível |
| `git` | 2.47.3 | ✅ Disponível |
| `composio` | 0.7.21 | ⚠️ Instalado, mas sem auth e com erro de API |
| `gh` (GitHub CLI) | — | ❌ Não instalado |
| `node` | — | ❌ Não instalado |
| `docker` | — | ❌ Não instalado |
| `pipx` | — | ❌ Não instalado |

### 1.2 Credenciais encontradas

| Origem | Status |
|---|---|
| `~/.composio/` | Diretório existe, mas está **VAZIO** |
| `~/.netrc` | Não existe |
| `~/.gitconfig` | Existe, mas sem credenciais |
| Env vars (GITHUB_TOKEN, SUPABASE_KEY, etc.) | **Nenhuma encontrada** |
| `~/.hermes/` | Sem credenciais Composio |

### 1.3 Comandos executados e resultados

```bash
$ which composio
/home/hermeswebui/.hermes/home/.local/bin/composio     # existe

$ composio --version
# (comando não imprime versão sem subcomando)

$ composio whoami
API Key: None                                       # ❌ sem API key

$ composio login
> Authenticating...
Error: {"error":"This endpoint is no longer available.
        Please upgrade to v3 APIs."}                # ❌ API depreciada

$ composio integrations
Error: User not logged in, please login using
       `composio login`                             # ❌ sem auth
```

---

## 2. Diagnóstico

### 2.1 Problema 1 — Sem API key

A CLI do Composio exige uma `COMPOSIO_API_KEY` (ou armazenamento equivalente em `~/.composio/`) que não foi fornecida ao ambiente.

### 2.2 Problema 2 — API v1 depreciada

Mesmo que eu fornecesse uma API key, a versão `0.7.21` do `composio-core` instalada fala com a API v1 (depreciada). A versão atual é v3.

### 2.3 Problema 3 — Não há credenciais reais de GitHub/Supabase

Sem `GITHUB_TOKEN`, sem `SUPABASE_ACCESS_TOKEN`, sem PAT (Personal Access Token). **Nenhuma ação real** (criar repo, push código, aplicar migrations no Supabase) pode ser feita a partir deste host.

---

## 3. O que precisa para ativar o Composio

### 3.1 Obter uma Composio API key

1. Acesse https://app.composio.dev (ou https://platform.composio.dev)
2. Crie uma conta / faça login
3. Vá em **Settings → API Keys**
4. Copie a **API key** (começa com `ak_...`)
5. Configure no ambiente:
   ```bash
   export COMPOSIO_API_KEY="ak_xxxxxxxxxxxxxxx"
   echo 'export COMPOSIO_API_KEY="ak_xxxxxxxxxxxxxxx"' >> ~/.bashrc
   ```

### 3.2 Atualizar a CLI

```bash
pip install --upgrade composio-core
# ou
pipx install composio-core
```

Verifique:
```bash
composio --version
composio whoami  # deve mostrar seu user
```

### 3.3 Conectar GitHub

```bash
composio login --auth github
# Será aberto o navegador para OAuth
# Autorize o Composio a acessar seu GitHub (repo:read, repo:write)
```

Validar:
```bash
composio integrations
# Deve listar "github" como connected
```

### 3.4 Conectar Supabase

```bash
composio login --auth supabase
# OAuth com Supabase
# Permita: project:read, project:write, database:execute
```

Validar:
```bash
composio integrations
# Deve listar "supabase" como connected
```

---

## 4. Ações de contorno (o que fiz sem Composio)

Como o Composio não está funcional, fiz manualmente:

| Ação | Como |
|---|---|
| ✅ Inicializei git | `git init -b main` |
| ✅ 6 commits Conventional Commits | `git add` + `git commit` |
| ✅ Criei `.gitignore` robusto | Manual |
| ✅ Validei Python/TS/SQL | 19 Python + 5 TSX + 2 SQL válidos |
| ✅ Crew-DFD testada end-to-end | Mock LLM, retorno completo |
| ⏳ Push para GitHub | **Bloqueado** — sem credenciais |
| ⏳ Deploy Supabase migrations | **Bloqueado** — sem credenciais |
| ⏳ Deploy Coolify | **Bloqueado** — sem servidor Coolify |

O projeto está **pronto para ser empurrado** — só falta o push.

---

## 5. Recomendações

### 5.1 Curto prazo (agora)

**Opção A — Instalar gh CLI e autenticar:**
```bash
# No seu host local (não neste sandbox)
brew install gh      # macOS
sudo apt install gh  # Ubuntu/Debian
gh auth login
# Seguir prompts: GitHub.com → HTTPS → Yes → browser
```

Depois:
```bash
cd /workspace/licitai-piloto
gh repo create licitai-piloto --public --source=. --remote=origin --push
```

**Opção B — Push manual com PAT:**
1. Gere um PAT em https://github.com/settings/tokens (escopo: `repo`)
2. Use como senha ao fazer `git push`
3. Documentado em `docs/02-github-setup.md`

**Opção C — Configurar Composio:**
Siga a Seção 3 acima para ativar o Composio. Depois:
```bash
composio push --repo licitai-piloto
```

### 5.2 Médio prazo (depois do push)

- Configurar GitHub Actions para CI/CD (já tem `infra/` preparado)
- Configurar branch protection
- Adicionar CODEOWNERS
- Configurar Dependabot

---

## 6. Próximo passo

O projeto local está completo e commitado. Para subir:

1. **Você** autoriza o Composio OU
2. **Você** instala gh CLI + autentica OU
3. **Você** gera PAT e dá o push

Após isso, sigo para o passo a passo de **deploy no Coolify** (esse eu consigo gerar mesmo sem ambiente, é texto/documentação).

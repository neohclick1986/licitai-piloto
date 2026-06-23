# Histórico de commits

Este repositório foi criado via [Composio](https://composio.dev) a partir do projeto
local em `/workspace/licitai-piloto`. O histórico de commits tem 12 entradas no
total porque a primeira tentativa de push disparou 3 vezes (a verificação automática
do Composio reportou falha no parsing do JSON, mas os commits tinham sido criados).

## Como limpar o histórico (opcional)

Se você quiser um histórico linear de 8 commits (igual ao git local), siga:

```bash
# Clone o repositório
git clone https://github.com/neohclick1986/licitai-piloto.git
cd licitai-piloto

# Veja os commits
git log --oneline

# Opção 1: squash interativo
git rebase -i HEAD~12
# No editor, troque 'pick' por 'squash' nos commits duplicados

# Opção 2: reset e reescrita
git reset --soft <SHA-DO-PRIMEIRO-COMMIT-DE-BOOTSTRAP>
git commit --amend -m "feat: projeto LicitaI piloto completo

- Schema Supabase com RLS multi-tenant
- Backend FastAPI (Clean Architecture)
- Crew-DFD funcional com LLM plugável (OpenAI/Ollama)
- Frontend Next.js 15
- Infra (docker-compose, scripts)
- Documentação (Composio, GitHub, Coolify)"
git push --force-with-lease
```

## Estrutura do projeto

```
licitai-piloto/
├── supabase/         # Schema SQL + seed
├── apps/
│   ├── api/          # FastAPI
│   └── web/          # Next.js 15
├── packages/
│   └── agents/       # CrewAI + LLM providers
├── infra/            # Docker + scripts
└── docs/             # Documentação
```

Ver [README.md](README.md) para o guia completo.

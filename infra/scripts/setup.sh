#!/bin/bash
# LicitaI Piloto - Setup completo
# Uso: ./infra/scripts/setup.sh

set -e
cd "$(dirname "$0")/../.."

echo "=================================="
echo "LicitaI Piloto - Setup"
echo "=================================="

# 1. Verificar .env
if [ ! -f .env ]; then
    echo "❌ .env não encontrado. Copie .env.example: cp .env.example .env"
    exit 1
fi

source .env

# 2. Verificar Supabase
if [[ "$SUPABASE_URL" == *"SEU-PROJECT-REF"* ]]; then
    echo "❌ Configure SUPABASE_URL no .env"
    exit 1
fi

if [[ -z "$SUPABASE_JWT_SECRET" ]]; then
    echo "❌ SUPABASE_JWT_SECRET ausente no .env"
    echo "   Obtenha em: Supabase → Settings → API → JWT Settings"
    exit 1
fi

# 3. Supabase CLI
if ! command -v supabase &> /dev/null; then
    echo "⚠️  Supabase CLI não encontrada. Instale: https://supabase.com/docs/guides/cli"
    echo "    Continuando sem CLI (você pode aplicar migrations manualmente)"
    SKIP_CLI=true
fi

# 4. Aplicar migrations
if [ -z "$SKIP_CLI" ]; then
    echo ""
    echo "📦 Aplicando migrations no Supabase..."
    supabase db push --db-url "$SUPABASE_DB_URL" || {
        echo "❌ Falha nas migrations. Verifique a connection string."
        exit 1
    }

    echo ""
    echo "🌱 Aplicando seed..."
    PGPASSWORD=$(echo $SUPABASE_DB_URL | sed -E 's|.*://[^:]+:([^@]+)@.*|\1|') \
    psql "$SUPABASE_DB_URL" -f supabase/seed/0001_seed_piloto.sql || {
        echo "⚠️  psql não disponível. Aplique o seed manualmente no SQL Editor do Supabase"
    }
else
    echo ""
    echo "📝 Aplique manualmente no Supabase SQL Editor:"
    echo "   1. supabase/migrations/0001_initial_schema.sql"
    echo "   2. supabase/seed/0001_seed_piloto.sql"
fi

# 5. Setup Python
echo ""
echo "🐍 Configurando ambiente Python..."
cd apps/api
python3 -m venv .venv 2>/dev/null || true
source .venv/bin/activate 2>/dev/null || true
pip install -q -r requirements.txt
cd ../..

# 6. Setup Node
echo ""
echo "📦 Configurando frontend..."
if command -v npm &> /dev/null; then
    cd apps/web
    npm install --silent
    cd ../..
else
    echo "⚠️  Node/npm não encontrado. Instale Node 20+ e rode 'npm install' em apps/web"
fi

echo ""
echo "=================================="
echo "✅ Setup concluído!"
echo "=================================="
echo ""
echo "Próximos passos:"
echo "1. Iniciar API:    cd apps/api && uvicorn src.main:app --reload --port 8000"
echo "2. Iniciar Web:    cd apps/web && npm run dev"
echo "3. Testar:         curl http://localhost:8000/api/v1/health"
echo "4. Criar usuário no Supabase Auth e adicionar à tabela 'users'"

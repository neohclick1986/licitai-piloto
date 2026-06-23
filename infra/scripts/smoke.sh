#!/bin/bash
# LicitaI Piloto - Smoke tests
# Uso: ./infra/scripts/smoke.sh

set -e
cd "$(dirname "$0")/../.."

API=${API_URL:-http://localhost:8000/api/v1}
echo "Testando: $API"
echo ""

# 1. Health
echo "1. Health check"
HEALTH=$(curl -s "$API/health/detailed" || echo "FAIL")
echo "   $HEALTH"
if [[ "$HEALTH" != *'"status":"ok"'* ]]; then
    echo "   ❌ API não está respondendo corretamente"
    exit 1
fi
echo "   ✓"
echo ""

# 2. Auth required
echo "2. Endpoint protegido exige auth"
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API/processos/")
if [ "$CODE" != "401" ]; then
    echo "   ⚠️  Esperado 401, obtido $CODE"
fi
echo "   ✓ (HTTP $CODE sem token)"
echo ""

# 3. Para testar com auth, crie um usuário e adicione à tabela 'users'
cat <<'EOF'
3. Testes com autenticação:
   a) Crie um usuário no Supabase Auth
   b) Adicione à tabela users:
      INSERT INTO users (id, tenant_id, nome, email, role)
      VALUES ('UUID-DO-AUTH-USERS', '11111111-1111-1111-1111-111111111111', 'Seu Nome', 'seu@email.com', 'ADMIN_TENANT');
   c) Faça login e pegue o token:
      curl -X POST 'https://SEU-REF.supabase.co/auth/v1/token?grant_type=password' \
        -H 'apikey: ANON_KEY' -H 'Content-Type: application/json' \
        -d '{"email":"seu@email.com","password":"senha"}'
   d) Use o access_token:
      TOKEN="..."
      curl -H "Authorization: Bearer $TOKEN" $API/processos/

4. Testar criação de DFD com IA:
   TOKEN="..."
   curl -X POST $API/dfd/ \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "processo_id": "aaaaaaaa-0001-0000-0000-000000000001",
       "area_requisitante": "Secretaria de Administração",
       "objeto": "Aquisição de papel A4 75g/m² branco para uso administrativo",
       "justificativa": "Reposição de estoque consumido no exercício anterior. Em 2025 foram consumidos 540 pacotes; projeção 2026 é de 500 pacotes.",
       "quantidade": 500,
       "unidade_medida": "pacote",
       "valor_estimado": 12500.00,
       "prazo_entrega_dias": 30,
       "destino": "Almoxarifado Central - Av. Alberto Andaló, 3030",
       "usar_ia": true
     }'
EOF

echo ""
echo "✅ Smoke test inicial OK (health + RLS)"

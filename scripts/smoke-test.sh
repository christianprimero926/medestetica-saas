#!/usr/bin/env bash
# Smoke test del MVP: valida flujos criticos sin navegador.
# Uso:
#   bash scripts/smoke-test.sh
#   BASE_URL=https://tu-tunel.trycloudflare.com bash scripts/smoke-test.sh
# Requiere: stack corriendo y datos demo sembrados (tenant bella-beauty).
set -u
BASE_URL="${BASE_URL:-http://localhost:3000}"
API="$BASE_URL/api"
PASS=0; FAIL=0
ok(){ echo "  OK   $1"; PASS=$((PASS+1)); }
ko(){ echo "  FAIL $1 (got: $2)"; FAIL=$((FAIL+1)); }
code(){ curl -s -o /dev/null -w "%{http_code}" "$@"; }

echo "== Smoke test contra $BASE_URL =="

# 1. Login admin
LOGIN=$(curl -s -X POST "$API/auth/login" -H 'Content-Type: application/json' \
  -d '{"email":"admin@bellabeauty.demo","password":"Demo1234!","tenantSlug":"bella-beauty","staffOnly":true}')
TOKEN=$(echo "$LOGIN" | sed -n 's/.*"accessToken":"\([^"]*\)".*/\1/p')
TENANT=$(echo "$LOGIN" | sed -n 's/.*"tenantId":"\([^"]*\)".*/\1/p')
[ -n "$TOKEN" ] && ok "login admin" || ko "login admin" "$LOGIN"

# 2. Credenciales malas -> no 2xx
c=$(code -X POST "$API/auth/login" -H 'Content-Type: application/json' -d '{"email":"admin@bellabeauty.demo","password":"mala","tenantSlug":"bella-beauty"}')
[ "$c" = "401" ] || [ "$c" = "400" ] && ok "login invalido rechazado ($c)" || ko "login invalido" "$c"

# 3. Lectura autenticada
c=$(code "$API/inventory" -H "Authorization: Bearer $TOKEN")
[ "$c" = "200" ] && ok "inventario autenticado" || ko "inventario autenticado" "$c"

# 4. Sin token -> 401
c=$(code "$API/inventory")
[ "$c" = "401" ] && ok "sin token -> 401" || ko "sin token" "$c"

# 5. IDOR: leer otro tenant -> 403
c=$(code "$API/leads/tenant/cffffffffffffffffffffffff" -H "Authorization: Bearer $TOKEN")
[ "$c" = "403" ] && ok "IDOR cross-tenant -> 403" || ko "IDOR" "$c"

# 6. Portal publico
c=$(code "$BASE_URL/c/bella-beauty")
[ "$c" = "200" ] && ok "portal publico" || ko "portal publico" "$c"

# 7. Rate limit en lead publico (esperar algun 429 en 8 intentos)
seen429=0
for i in $(seq 1 8); do
  c=$(code -X POST "$API/leads/public/bella-beauty" -H 'Content-Type: application/json' -d "{\"firstName\":\"Smoke$i\",\"phone\":\"3001110$i\"}")
  [ "$c" = "429" ] && seen429=1
done
[ "$seen429" = "1" ] && ok "rate limit -> 429" || ko "rate limit" "sin 429 en 8 intentos"

echo "== Resultado: $PASS OK, $FAIL FAIL =="
[ "$FAIL" = "0" ]

#!/usr/bin/env bash
# Post-deploy auth smoke (run against staging API base URL).
# Usage:
#   API_BASE=https://bedtime-api.lullvale.com ADMIN_USER=admin ADMIN_PASS=... ./scripts/smoke_auth.sh
set -euo pipefail
API_BASE="${API_BASE:-http://127.0.0.1:8000}"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASS="${ADMIN_PASS:?set ADMIN_PASS}"

echo "== health =="
curl -fsS "$API_BASE/health" | head -c 200
echo

echo "== openapi should be 404 outside docs =="
code=$(curl -sS -o /dev/null -w "%{http_code}" "$API_BASE/openapi.json" || true)
echo "openapi=$code"

echo "== anonymous delete account =="
code=$(curl -sS -o /dev/null -w "%{http_code}" -X DELETE "$API_BASE/v1/account" || true)
echo "delete_account=$code"

echo "== dev-login (expect 403 when ENV≠dev) =="
code=$(curl -sS -o /dev/null -w "%{http_code}" -X POST "$API_BASE/v1/auth/dev-login" \
  -H 'Content-Type: application/json' \
  -d '{"display_name":"Dev","preferred_language":"zh"}' || true)
echo "dev_login=$code"

echo "== admin login + create invite =="
tok=$(curl -fsS -X POST "$API_BASE/admin/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$ADMIN_USER\",\"password\":\"$ADMIN_PASS\"}" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
inv=$(curl -fsS -X POST "$API_BASE/admin/invites" \
  -H "Authorization: Bearer $tok" \
  -H 'Content-Type: application/json' \
  -d '{"count":1,"note":"smoke","expires_in_days":7}')
code=$(echo "$inv" | python3 -c "import sys,json; print(json.load(sys.stdin)['items'][0]['code'])")
echo "invite=$code"

phone="139$(date +%s | tail -c 9)"
echo "== register + refresh + logout =="
pair=$(curl -fsS -X POST "$API_BASE/v1/auth/register" \
  -H 'Content-Type: application/json' \
  -d "{\"invite_code\":\"$code\",\"phone\":\"$phone\",\"password\":\"smoke-pass-1\",\"display_name\":\"Smoke\"}")
access=$(echo "$pair" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
refresh=$(echo "$pair" | python3 -c "import sys,json; print(json.load(sys.stdin)['refresh_token'])")
curl -fsS "$API_BASE/v1/account/me" -H "Authorization: Bearer $access" >/dev/null
pair2=$(curl -fsS -X POST "$API_BASE/v1/auth/refresh" \
  -H 'Content-Type: application/json' \
  -d "{\"refresh_token\":\"$refresh\"}")
refresh2=$(echo "$pair2" | python3 -c "import sys,json; print(json.load(sys.stdin)['refresh_token'])")
curl -fsS -X POST "$API_BASE/v1/auth/logout" \
  -H 'Content-Type: application/json' \
  -d "{\"refresh_token\":\"$refresh2\"}" >/dev/null
echo "smoke_auth_ok phone=$phone"

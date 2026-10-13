#!/usr/bin/env bash
# Cron-friendly retention purge. Requires RETENTION_ADMIN_TOKEN and PUBLIC_API_BASE_URL
# (or API_BASE_URL) in the environment, or in apps/api/.env next to this repo checkout.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/../.env}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

BASE="${PUBLIC_API_BASE_URL:-${API_BASE_URL:-http://127.0.0.1:8000}}"
BASE="${BASE%/}"
TOKEN="${RETENTION_ADMIN_TOKEN:-}"

if [[ -z "$TOKEN" ]]; then
  echo "RETENTION_ADMIN_TOKEN is empty" >&2
  exit 1
fi

curl -fsS -X POST \
  -H "X-Retention-Admin-Token: ${TOKEN}" \
  "${BASE}/v1/account/retention/run"
echo

#!/usr/bin/env bash
# One-shot DR dump for the *legacy* Linode host (lullvale01) that co-hosted
# Bandage + Bedtime. Not used on Alibaba HK (lullvale-hk).
#
# Run *on* lullvale01 as root (or: scp this script there and execute).
# Produces /root/backups/lullvale01-<UTC>/ with gzipped SQL + SHA256SUMS.
# Bandage dump is also uploaded via service/scripts/backup-db-to-r2.sh when present.
set -euo pipefail

TS="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
REMOTE_DIR="${REMOTE_DIR:-/root/backups/lullvale01-${TS}}"
mkdir -p "$REMOTE_DIR"
echo "Remote backup dir: $REMOTE_DIR"

{
  echo "hostname=$(hostname)"
  echo "utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "=== docker ps ==="
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
  echo "=== volumes ==="
  docker volume ls
  echo "=== crontab ==="
  crontab -l 2>/dev/null || echo '(empty)'
  echo "=== df ==="
  df -h /
} >"$REMOTE_DIR/server-meta.txt"

# --- Bandage ---
echo "Dumping Bandage DB..."
BANDAGE_COMPOSE="/srv/bandage/service/docker-compose.api-prod.yml"
if [[ ! -f "$BANDAGE_COMPOSE" ]]; then
  echo "ERROR: missing $BANDAGE_COMPOSE (this script is for legacy lullvale01 only)" >&2
  exit 1
fi
# Prefer live container env over hard-coded passwords.
BANDAGE_USER="$(docker exec bandage-backend-db-1 printenv MARIADB_USER 2>/dev/null || echo dev)"
BANDAGE_PASS="$(docker exec bandage-backend-db-1 printenv MARIADB_PASSWORD 2>/dev/null || true)"
BANDAGE_DB="$(docker exec bandage-backend-db-1 printenv MARIADB_DATABASE 2>/dev/null || echo bandage)"
if [[ -z "$BANDAGE_PASS" ]]; then
  echo "ERROR: could not read MARIADB_PASSWORD from bandage-backend-db-1" >&2
  exit 1
fi
BANDAGE_OUT="$REMOTE_DIR/bandage-${BANDAGE_DB}-${TS}.sql.gz"
docker compose -p bandage-backend -f "$BANDAGE_COMPOSE" exec -T \
  -e "MYSQL_PWD=${BANDAGE_PASS}" db \
  mariadb-dump -u "$BANDAGE_USER" --single-transaction --routines --events "$BANDAGE_DB" \
  | gzip -9 >"$BANDAGE_OUT"
ls -lh "$BANDAGE_OUT"
echo "bandage_db=${BANDAGE_DB}" >>"$REMOTE_DIR/server-meta.txt"

if [[ -x /srv/bandage/service/scripts/backup-db-to-r2.sh ]]; then
  echo "Uploading Bandage dump to R2 via official script..."
  (cd /srv/bandage/service && ./scripts/backup-db-to-r2.sh) | tee -a "$REMOTE_DIR/server-meta.txt"
else
  echo "WARN: backup-db-to-r2.sh missing — local gzip only" | tee -a "$REMOTE_DIR/server-meta.txt"
fi

# --- Bedtime ---
# Prefer MYSQL_PASSWORD + app user "bedtime" (compose overrides DATABASE_URL at runtime).
echo "Dumping Bedtime DB..."
BEDTIME_ENV=/srv/bedtime/apps/api/.env
if [[ ! -f "$BEDTIME_ENV" ]]; then
  echo "ERROR: missing $BEDTIME_ENV" >&2
  exit 1
fi
BEDTIME_USER=bedtime
BEDTIME_DB=bedtime
BEDTIME_PASS="$(grep -E '^MYSQL_PASSWORD=' "$BEDTIME_ENV" | head -1 | cut -d= -f2- | tr -d '"' | tr -d "'")"
if [[ -z "$BEDTIME_PASS" ]]; then
  echo "ERROR: MYSQL_PASSWORD missing in $BEDTIME_ENV" >&2
  exit 1
fi

BEDTIME_OUT="$REMOTE_DIR/bedtime-${BEDTIME_DB}-${TS}.sql.gz"
docker exec -e "MYSQL_PWD=${BEDTIME_PASS}" bedtime-mariadb-1 \
  mariadb-dump -u "$BEDTIME_USER" --single-transaction --routines --events "$BEDTIME_DB" \
  | gzip -9 >"$BEDTIME_OUT"
ls -lh "$BEDTIME_OUT"
echo "bedtime_db=${BEDTIME_DB}" >>"$REMOTE_DIR/server-meta.txt"

(
  cd "$REMOTE_DIR"
  if command -v sha256sum >/dev/null; then
    sha256sum *.sql.gz >SHA256SUMS
  else
    shasum -a 256 *.sql.gz >SHA256SUMS
  fi
  cat SHA256SUMS
)

echo "REMOTE_DIR=$REMOTE_DIR"
ls -lh "$REMOTE_DIR"
echo "$REMOTE_DIR" > /tmp/lullvale01-last-backup-dir.txt

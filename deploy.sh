#!/usr/bin/env bash
# Deploy bedtime API staging to the VPS (Bandage-style: git on server + scp secrets).
# Secrets stay local: apps/api/.env.staging (gitignored) → remote apps/api/.env
#
# Usage (from repo root):
#   cp apps/api/.env.staging.example apps/api/.env.staging   # once; fill secrets
#   ./deploy.sh              # git sync, scp .env, compose up
#   ./deploy.sh env          # only scp .env.staging
#   ./deploy.sh code         # only git pull + compose (reuse remote .env)
#
# Env overrides:
#   DEPLOY_SSH=root@lullvale01
#   REMOTE_REPO_ROOT=/srv/bedtime
#   SSH_KEY=$HOME/.ssh/id_lullvale
#   GIT_REPO_URL=git@github.com:yeahkyo/bedtime.git
#   GIT_BRANCH=main

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_ENV="${ROOT}/apps/api/.env.staging"
COMPOSE_FILE="docker-compose.staging.yml"
COMPOSE_PROJECT="${COMPOSE_PROJECT:-bedtime}"

DEPLOY_SSH="${DEPLOY_SSH:-root@lullvale01}"
REMOTE_REPO_ROOT="${REMOTE_REPO_ROOT:-/srv/bedtime}"
# Prefer lullvale deploy key (Bandage host); fall back to ed25519/rsa.
if [[ -z "${SSH_KEY:-}" ]]; then
	if [[ -f "$HOME/.ssh/id_lullvale" ]]; then
		SSH_KEY="$HOME/.ssh/id_lullvale"
	elif [[ -f "$HOME/.ssh/id_ed25519" ]]; then
		SSH_KEY="$HOME/.ssh/id_ed25519"
	else
		SSH_KEY="$HOME/.ssh/id_rsa"
	fi
fi
GIT_BRANCH="${GIT_BRANCH:-main}"
if [[ -z "${GIT_REPO_URL:-}" ]]; then
	GIT_REPO_URL="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
fi
GIT_REPO_URL="${GIT_REPO_URL:-git@github.com:yeahkyo/bedtime.git}"

SSH=(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new)
SCP=(scp -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new)

usage() {
	cat <<EOF
Usage: $(basename "$0") [all|env|code]

  all   (default) git sync, scp .env.staging, docker compose up --build
  env   only scp apps/api/.env.staging → ${REMOTE_REPO_ROOT}/apps/api/.env
  code  git sync + compose (does not overwrite remote .env)

Requires local file: apps/api/.env.staging (see .env.staging.example).
SSH key: ${SSH_KEY}
EOF
	exit 1
}

need_local_env() {
	if [[ ! -f "$LOCAL_ENV" ]]; then
		echo "Missing $LOCAL_ENV" >&2
		echo "  cp apps/api/.env.staging.example apps/api/.env.staging" >&2
		echo "  # then fill secrets locally — never commit this file" >&2
		exit 1
	fi
}

scp_env() {
	need_local_env
	echo "🔐 scp .env.staging → ${DEPLOY_SSH}:${REMOTE_REPO_ROOT}/apps/api/.env"
	"${SSH[@]}" "$DEPLOY_SSH" "mkdir -p '${REMOTE_REPO_ROOT}/apps/api' && test -d '${REMOTE_REPO_ROOT}/.git'"
	"${SCP[@]}" "$LOCAL_ENV" "${DEPLOY_SSH}:${REMOTE_REPO_ROOT}/apps/api/.env"
	"${SSH[@]}" "$DEPLOY_SSH" "chmod 600 '${REMOTE_REPO_ROOT}/apps/api/.env'"
}

remote_git_sync() {
	echo "📦 git sync on ${DEPLOY_SSH}:${REMOTE_REPO_ROOT} ← ${GIT_REPO_URL}"
	"${SSH[@]}" "$DEPLOY_SSH" bash -s <<EOF
set -euo pipefail
GIT_REPO_URL=$(printf '%q' "$GIT_REPO_URL")
GIT_BRANCH=$(printf '%q' "$GIT_BRANCH")
REMOTE_REPO_ROOT=$(printf '%q' "$REMOTE_REPO_ROOT")
if [[ ! -d "\$REMOTE_REPO_ROOT/.git" ]]; then
  if [[ -e "\$REMOTE_REPO_ROOT" ]] && [[ -n "\$(ls -A "\$REMOTE_REPO_ROOT" 2>/dev/null || true)" ]]; then
    echo "❌ \$REMOTE_REPO_ROOT exists but is not a git repo (and not empty)." >&2
    echo "   Move/remove it, then re-run ./deploy.sh" >&2
    exit 1
  fi
  mkdir -p "\$(dirname "\$REMOTE_REPO_ROOT")"
  git clone --filter=blob:none --single-branch --branch "\$GIT_BRANCH" \\
    "\$GIT_REPO_URL" "\$REMOTE_REPO_ROOT"
else
  cd "\$REMOTE_REPO_ROOT"
  git fetch origin "\$GIT_BRANCH" --prune --no-tags
  git checkout "\$GIT_BRANCH"
  git reset --hard "origin/\$GIT_BRANCH"
fi
EOF
}

remote_compose_up() {
	echo "🚀 docker compose -p ${COMPOSE_PROJECT} up -d --build"
	"${SSH[@]}" "$DEPLOY_SSH" bash -s <<EOF
set -euo pipefail
cd $(printf '%q' "$REMOTE_REPO_ROOT")
test -f apps/api/.env || { echo "missing apps/api/.env — run: ./deploy.sh env" >&2; exit 1; }
export DOCKER_BUILDKIT=1
docker compose -p $(printf '%q' "$COMPOSE_PROJECT") \\
  -f $(printf '%q' "$COMPOSE_FILE") \\
  --env-file apps/api/.env \\
  up -d --build
docker compose -p $(printf '%q' "$COMPOSE_PROJECT") -f $(printf '%q' "$COMPOSE_FILE") ps
EOF
}

TARGET="${1:-all}"
case "$TARGET" in
	-h|--help) usage ;;
	all)
		# Clone/pull first so scp lands inside the repo (never before first clone).
		remote_git_sync
		scp_env
		remote_compose_up
		;;
	env)
		scp_env
		;;
	code)
		remote_git_sync
		remote_compose_up
		;;
	*) usage ;;
esac

echo "✅ done"

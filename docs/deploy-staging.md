# Staging / online App testing deploy

Same edge pattern as Bandage / Featee: **no reverse proxy on the VPS**.  
Clients hit **Cloudflare** (orange-cloud + Universal SSL); origin speaks **HTTP** on a published port.

```text
App (HTTPS) → Cloudflare edge → Origin VPS :8080 → Docker api (uvicorn :8000)
App legal links → Cloudflare → Origin VPS :8082 → Lullvale web (nginx /legal/*)
Media put/get → Cloudflare R2 (S3 API + presigned URLs)
```

Default API host port is **8080** so this stack can share the Bandage VPS (Bandage API already uses **:80**).  
Set Cloudflare **Origin Rule**: hostname `bedtime-api.*` → origin port **8080**.  
Legal / product site: `huhu.lullvale.com` → origin port **8082** (sibling repo [`../Lullvale`](../../Lullvale)).  
(Dedicated VPS with free :80: set `API_HOST_PORT=80` in `.env.staging`.)

## Secrets: local `.env.staging` + scp (no SSH editing)

Do **not** hand-edit env on the server. Keep secrets on your laptop:

```bash
cp apps/api/.env.staging.example apps/api/.env.staging
# edit apps/api/.env.staging locally — gitignored
./deploy.sh          # scp → /srv/bedtime/apps/api/.env, git pull, compose up
./deploy.sh env      # only refresh remote .env
./deploy.sh code     # code + compose only (keep remote .env)
# Legal / marketing sites (Featee + studio + Huhu):
cd ../Lullvale && ./deploy.sh
```

| Local (gitignored) | Remote |
|--------------------|--------|
| `apps/api/.env.staging` | `/srv/bedtime/apps/api/.env` |

Template: [`apps/api/.env.staging.example`](../apps/api/.env.staging.example) (committed).  
Deploy script: [`deploy.sh`](../deploy.sh) (same idea as Bandage syncing `prod.env`).

Override SSH target: `DEPLOY_SSH=root@lullvale01 REMOTE_REPO_ROOT=/srv/bedtime ./deploy.sh`

## Auth decision (current)

| Phase | Auth | Notes |
|-------|------|--------|
| **Staging / closed beta (now)** | `ENV=staging` + `DEV_AUTH_BYPASS=0` + `EXPOSE_API_DOCS=0` | Invite code register + phone/password login. Access JWT (~60m) + opaque refresh (7d, rotate). `dev-login` **disabled**. `DELETE /v1/account` disabled outside `dev`. Admin UI: generate invites; disable users. |
| **Local engineering** | `ENV=dev` | `POST /v1/auth/dev-login` still available for engineers only. |
| **Store-ready later** | Apple Sign-In with **JWKS verify** | Not implemented yet; phone/password + invite remains. |

**Do not** set `DEV_AUTH_BYPASS=1` on a publicly reachable host.

## Checklist

1. Fill local `apps/api/.env.staging` (DB passwords, JWT, R2, Ark/Fish, `RETENTION_ADMIN_TOKEN`, `ADMIN_BOOTSTRAP_PASSWORD`, `PUBLIC_API_BASE_URL`).
2. Private R2 bucket; leave `S3_PUBLIC_BASE_URL` empty.
3. Cloudflare DNS: `bedtime-api.lullvale.com` → VPS IP, **Proxied**, SSL **Full**.
4. Cloudflare **Origin Rule**: that hostname → **destination port 8080** (skip if you use `API_HOST_PORT=80` alone on the box).
5. Firewall: allow **8080** (and **22**); do not publish MariaDB/Redis.
6. `./deploy.sh` (API **:8080** + Admin UI **:8083**)
7. Admin UI: open `http://<VPS_IP>:8083` (or a Cloudflare hostname with Origin Rule → **8083**).  
   SPA uses same-origin `/admin/*`; nginx proxies to the `api` container — leave `ADMIN_UI_API_BASE` empty.
8. Legal site: deploy sibling [`../Lullvale`](../../Lullvale); DNS `huhu.lullvale.com` → VPS, Proxied; Origin Rule → **8082**.  
   Smoke: `curl -sI https://huhu.lullvale.com/legal/privacy/en.html` → **200**.
9. App: `flutter run --dart-define=APP_ENV=staging`  
   Config: [`apps/mobile/assets/config/staging.json`](../apps/mobile/assets/config/staging.json) (`api_base_url`, `legal_host`, feature flags).  
   Umeng U-APM: put AppKeys in `staging.json` or gitignored `staging.local.json` (see `*.local.json.example`). Empty keys → APM skipped. Upload symbol/dSYM in the Umeng console for readable stacks.  
   Local/CI: default `APP_ENV=dev` (LAN API, empty Umeng keys).
10. Retention cron on the VPS (see below).

## Fill these in `.env.staging` before first deploy

| Variable | Required |
|----------|----------|
| `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD` | yes |
| `JWT_SECRET`, `RETENTION_ADMIN_TOKEN` | yes |
| `S3_ENDPOINT_URL`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_BUCKET` | yes |
| `ARK_API_KEY` | yes (stories) |
| `FISH_AUDIO_API_KEY` | yes (default speech; Volc paused) |
| `FISH_AUDIO_DEFAULT_VOICE_ID` | yes for system TTS voice |
| `ADMIN_BOOTSTRAP_PASSWORD` | yes for Admin UI / when ENV≠dev |
| `PUBLIC_API_BASE_URL` | yes (`https://bedtime-api.lullvale.com`) |
| `API_HOST_PORT` | optional (default **8080** in compose) |
| `ADMIN_UI_PORT` | optional (default **8083**) |

## Port conflicts (same VPS as Bandage)

| Host port | Owner |
|-----------|--------|
| 80 | Bandage API — **do not reuse** |
| 8081 | Bandage admin |
| **8082** | Lullvale web (Featee / studio / Huhu) |
| **8080** | Bedtime staging API (default) |
| **8083** | Bedtime admin UI |
| 3307 / 6390 | Bandage DB/Redis published — bedtime staging does **not** publish DB/Redis |

Use a separate Compose project (`-p bedtime` via `deploy.sh`).

## Cloudflare (edge)

| Hostname | Origin port | Service |
|----------|-------------|---------|
| `bedtime-api.lullvale.com` | **8080** | bedtime `api` |
| `huhu.lullvale.com` | **8082** | Lullvale `web` (shared with Featee / studio) |

| Setting | Value |
|---------|--------|
| Proxy | Orange cloud |
| SSL/TLS | **Full** |
| On-box Caddy/nginx | Not required (compose publishes ports; CF Origin Rules by Host) |

## Object storage (R2)

```bash
STORAGE_BACKEND=s3
S3_ENDPOINT_URL=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
S3_ACCESS_KEY=...
S3_SECRET_KEY=...
S3_BUCKET=bedtime
S3_REGION=auto
S3_PUBLIC_BASE_URL=
```

## Retention cron

On the VPS, hit origin directly (port **8080**):

```bash
# cron env:
PUBLIC_API_BASE_URL=http://127.0.0.1:8080
RETENTION_ADMIN_TOKEN=...   # same as .env

15 3 * * * /srv/bedtime/apps/api/scripts/run_retention.sh >> /var/log/bedtime-retention.log 2>&1
```

```bash
curl -fsS -X POST -H "X-Retention-Admin-Token: $RETENTION_ADMIN_TOKEN" \
  http://127.0.0.1:8080/v1/account/retention/run
```

## Smoke test

1. `curl -sS https://bedtime-api.lullvale.com/health`  
2. `curl -sI https://huhu.lullvale.com/legal/privacy/en.html` → **200**  
3. App with `APP_ENV=staging` (HTTPS API from config)
4. Create child → story → play (R2). Soft series / voice clone are off by default (`FEATURE_SOFT_SERIES` / `FEATURE_VOICE_CLONE`).  
5. Retention curl above  

## Before public prod

- [ ] `ENV=staging|prod`, `DEV_AUTH_BYPASS=0`, `EXPOSE_API_DOCS=0`, strong `JWT_SECRET`  
- [ ] Admin `:8083` not bare on the public internet  
- [ ] Apple JWKS + Flutter Sign in with Apple (optional next)  
- [ ] Strong DB passwords  
---

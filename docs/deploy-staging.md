# Staging / online App testing deploy

**Current origin:** Alibaba Cloud Hong Kong lightweight (`Host lullvale-hk` in `~/.ssh/config`).  
**Edge:** Cloudflare DNS **only** (grey cloud) — clients hit the origin directly.  
**TLS:** Let’s Encrypt on the host (nginx `:443`), reverse-proxied to Docker publish ports.

```text
App (HTTPS) → origin nginx :443 → Docker api :8080 (uvicorn :8000)
App legal / marketing → origin nginx :443 → Lullvale web :8082
Media put/get → Cloudflare R2 (S3 API + presigned URLs)
```

Host nginx configs (on the VPS, not in this repo): `/etc/nginx/conf.d/bedtime-api.conf`, `lullvale-web.conf`, `lullvale-edge.conf`.  
Compose still publishes **8080** (API) / **8082** (web) / **8083** (admin) on localhost for nginx upstreams and retention curl.

Optional legacy path: orange-cloud + Origin Rules to those ports (slower from mainland China). Prefer grey cloud + origin TLS for staging.

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

Default SSH: `root@lullvale-hk` (see `~/.ssh/config`; key `~/.ssh/id_lullvale`).  
Override old Linode: `DEPLOY_SSH=root@lullvale01 REMOTE_REPO_ROOT=/srv/bedtime ./deploy.sh`

**Firewall (both layers):**

1. Aliyun console → 轻量 → 防火墙: **22, 80, 443** (and **8080/8082/8083** if you still probe those ports directly).
2. On-box `firewalld`: `http`, `https`, and the compose ports as needed (`firewall-cmd --list-all`).

Do not publish MariaDB/Redis.

## Auth decision (current)

| Phase | Auth | Notes |
|-------|------|--------|
| **Staging / closed beta (now)** | Prefer `ENV=staging` + `DEV_AUTH_BYPASS=0` + `EXPOSE_API_DOCS=0` | Invite code register + phone/password login. Access JWT (~60m) + opaque refresh (7d, rotate). `dev-login` **disabled** when `ENV≠dev`. `DELETE /v1/account` disabled outside `dev`. Admin UI: generate invites; disable users. |
| **Local engineering** | `ENV=dev` | `POST /v1/auth/dev-login` still available for engineers only. |
| **Store-ready later** | Apple Sign-In with **JWKS verify** | Not implemented yet; phone/password + invite remains. |

**Do not** set `DEV_AUTH_BYPASS=1` on a publicly reachable host.  
If staging `.env` still has `ENV=dev` for App Review / `dev-login`, keep the hostname off the open internet or behind access control.

## Checklist

1. Fill local `apps/api/.env.staging` (DB passwords, JWT, R2, Ark/Fish, `RETENTION_ADMIN_TOKEN`, `ADMIN_BOOTSTRAP_PASSWORD`, `PUBLIC_API_BASE_URL`).
2. Private R2 bucket; leave `S3_PUBLIC_BASE_URL` empty.
3. Cloudflare DNS (**DNS only** / grey cloud): `bedtime-api`, `huhu`, `featee`, `www` → origin A record (same IP as `lullvale-hk`).
4. Origin TLS: certbot/nginx on the VPS for those hostnames (HTTP-01 needs **:80** open). Renewals via certbot timer.
5. `./deploy.sh` (API **:8080** + Admin UI **:8083**).
6. Admin UI: prefer SSH tunnel or a private hostname — **do not** grey-cloud `:8083` onto the public internet without extra auth.
7. Legal / marketing: deploy sibling [`../Lullvale`](../../Lullvale).  
   Smoke: `curl -sI https://huhu.lullvale.com/legal/privacy/en.html` → **200**.
8. App: `flutter run --dart-define=APP_ENV=staging`  
   Config: [`apps/mobile/assets/config/staging.json`](../apps/mobile/assets/config/staging.json).  
   LAN API for `APP_ENV=dev`: use gitignored `dev.local.json` (not committed `dev.json`).  
   Umeng: `staging.json` or `staging.local.json`.
9. Retention cron on the VPS (see below).

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

## Ports (dedicated HK box)

| Host port | Owner |
|-----------|--------|
| **80 / 443** | Host nginx (TLS + Host routing) |
| **8080** | Bedtime API (upstream) |
| **8082** | Lullvale web (Featee / studio / Huhu) |
| **8083** | Bedtime admin UI (keep private) |

Compose project: `-p bedtime` via `deploy.sh`. Bandage remains on the old Linode if still running — not co-located on HK.

## Cloudflare

| Hostname | Mode | Notes |
|----------|------|--------|
| `bedtime-api.lullvale.com` | DNS only | Origin nginx → `:8080` |
| `huhu` / `featee` / `www` | DNS only | Origin nginx → `:8082` |

Media stays on **R2** (unchanged). DNS-only exposes the origin IP; acceptable for closed staging.

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

On the VPS, hit the API upstream (port **8080**), not the public hostname:

```bash
# /etc/bedtime-retention.env (mode 600), sourced by cron:
PUBLIC_API_BASE_URL=http://127.0.0.1:8080
RETENTION_ADMIN_TOKEN=...   # same as .env
```

```cron
15 3 * * * root set -a; source /etc/bedtime-retention.env; set +a; /srv/bedtime/apps/api/scripts/run_retention.sh >> /var/log/bedtime-retention.log 2>&1
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

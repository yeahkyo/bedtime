# Lullvale Bedtime (Flutter)

## API base URL

```bash
# Simulator / local Docker API
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000

# Physical device on LAN
flutter run --dart-define=API_BASE_URL=http://<电脑局域网IP>:8000

# Staging / online via Cloudflare (HTTPS — iOS ATS)
flutter run --dart-define=API_BASE_URL=https://bedtime-api.lullvale.com
```

## Navigation

- **故事** — library (newest first) + CTA to push create-story
- **我的** — profile card + 音色管理 / 角色管理

## Auth (current)

Boot uses `POST /v1/auth/dev-login`. That only works when the API has `ENV=dev` (independent of `DEV_AUTH_BYPASS`). Staging should keep `DEV_AUTH_BYPASS=0` and `EXPOSE_API_DOCS=0`. Edge/TLS: Cloudflare orange-cloud → origin **:8080** (Origin Rule; Bandage keeps `:80`). See [docs/deploy-staging.md](../../docs/deploy-staging.md).

Apple Sign-In is not wired in this app yet.

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

Boot restores access/refresh from secure storage; refreshes session on launch. Staging uses **invite register** + **phone/password login** (`ENV=staging`, no `dev-login`). Local `ENV=dev` still allows engineer `dev-login` on the API, but the App no longer auto-calls it.

Edge/TLS: Cloudflare orange-cloud → origin **:8080**. See [docs/deploy-staging.md](../../docs/deploy-staging.md).

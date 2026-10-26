# Lullvale Bedtime (Flutter)

## Environments (`assets/config/`)

| File | Use |
|------|-----|
| `dev.json` | Local API (`127.0.0.1:8000`), Umeng keys empty (APM skipped) |
| `staging.json` | Online API host, fill Umeng keys (or use `staging.local.json`) |
| `production.json` | Store / prod host + keys (ready for later) |

Select env with a single define (default `dev`):

```bash
flutter run
flutter run --dart-define=APP_ENV=staging
flutter run --dart-define=APP_ENV=production
```

Optional **gitignored** overlays (copy from `*.local.json.example`):

```bash
# Physical device → Mac LAN IP
cp assets/config/dev.local.json.example assets/config/dev.local.json
# edit api_base_url

# Keep Umeng keys out of git
cp assets/config/staging.local.json.example assets/config/staging.local.json
# edit umeng_*_app_key
```

After changing any config JSON, do a full restart (not just hot reload).

## Navigation

- **故事** — library (newest first) + CTA to push create-story
- **我的** — profile card + 音色管理 / 角色管理

## Auth (current)

Boot restores access/refresh from secure storage; refreshes session on launch. Staging uses **invite register** + **phone/password login** (`ENV=staging`, no `dev-login`). Local `ENV=dev` still allows engineer `dev-login` on the API, but the App no longer auto-calls it.

Edge/TLS: Cloudflare orange-cloud → origin **:8080**. See [docs/deploy-staging.md](../../docs/deploy-staging.md).

## Splash

Native + Flutter branded splash (Bandage-style): `flutter_native_splash` handoff → animated `SplashScreen` → fade into auth/home.

```bash
# After changing assets/branding/splash_logo.png (384×384):
bash tool/regenerate_native_splash.sh
```

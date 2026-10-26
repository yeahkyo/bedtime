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

## App name (iOS)

| Where | Source | Value |
|-------|--------|--------|
| Home screen / SpringBoard | `CFBundleDisplayName` in `Info.plist` | `呼呼 · 枕边故事` |
| Xcode Archive / `.app` product | `PRODUCT_NAME` (Runner target) | `Huhu` |
| Xcode target / scheme | Flutter default | still named `Runner` (normal) |

Do **not** rename the Xcode target away from `Runner` unless you also update Flutter tooling paths.

## TestFlight

1. App Store Connect: create app with bundle id `com.lullvale.huhu`, add Internal/External testers.
2. Apple Developer: App ID has **Background Modes → Audio**; Team `JUHB8C2VT8` matches Xcode.
3. Bump `pubspec.yaml` `version` build number before each upload (`1.0.0+N` — `+N` must increase).
4. Build with **staging** (or production) baked in — plain Xcode Archive without `--dart-define` defaults to `dev` API:

```bash
cd apps/mobile
bash tool/build_testflight.sh          # APP_ENV=staging
# bash tool/build_testflight.sh production
```

5. Organizer → Distribute App → App Store Connect, or upload `build/ios/ipa/*.ipa`.
6. Export compliance: `ITSAppUsesNonExemptEncryption=false` is set (HTTPS-only). Confirm if you add non-standard crypto later.
7. TestFlight checklist for this product:
   - Invite-code register + phone login against staging API works on device
   - Microphone prompt copy OK when voice clone is enabled
   - Background audio continues with screen locked
   - Legal links open (`legal_host` in config)
   - No `dev-login` / localhost API in the build

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

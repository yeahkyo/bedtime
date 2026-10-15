# Agent notes

- Product: Lullvale Bedtime (Flutter `apps/mobile` + FastAPI `apps/api` + Vue admin `apps/admin`)
- Providers: [docs/providers.md](docs/providers.md) — story/speech knobs + Fish Audio default speech
- Review baseline: [docs/code-review.md](docs/code-review.md)
- Staging / online: [docs/deploy-staging.md](docs/deploy-staging.md) (Cloudflare edge → `:8080`, R2; Bandage-style; admin `:8083`)
- Cursor rules: `.cursor/rules/` (`code-review-baseline`, `api-python`, `flutter-mobile`)
- Prefer baseline fixes over large refactors unless explicitly requested
---

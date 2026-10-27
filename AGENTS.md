# Agent notes

- Product: Lullvale Bedtime (Flutter `apps/mobile` + FastAPI `apps/api` + Vue admin `apps/admin`)
- Providers: [docs/providers.md](docs/providers.md) — story/speech knobs, LLM 模型/路由 (`llm_models` + `llm_routing_rules`), Fish Audio default speech
- Review baseline: [docs/code-review.md](docs/code-review.md)
- Staging / online: [docs/deploy-staging.md](docs/deploy-staging.md) (Cloudflare → API `:8080` / admin `:8083`; R2; Bandage-style)
- Legal / marketing static: sibling [`../Lullvale`](../Lullvale) (`huhu.lullvale.com` on `:8082` — landing + `/preview/` + `/legal/`)
- Cursor rules: `.cursor/rules/` (`code-review-baseline`, `api-python`, `flutter-mobile`)
- Prefer baseline fixes over large refactors unless explicitly requested
---

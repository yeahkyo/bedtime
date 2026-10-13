# Code review checklist (baseline)

Use with Cursor rules under `.cursor/rules/`. Depth: **baseline** (security, authz, errors, clear bugs). Not required: large refactors, Alembic migration project, shared package, full CI.

## PR checklist

- [ ] Non-dev config cannot ship with default `JWT_SECRET` or `DEV_AUTH_BYPASS=1`
- [ ] New/changed routes enforce `user_id` ownership (or admin gate)
- [ ] Quota charged only after ownership / request validation
- [ ] Failures expose stable messages; no stack traces / raw exceptions to clients
- [ ] Story never `ready` without stored audio
- [ ] Flutter: `mounted` after async; media dispose/stop; tabs do not kill in-flight generate
- [ ] Security / quota / status-machine changes include pytest

## P0

| Item | Expectation |
|------|-------------|
| JWT / bypass | Production rejects unsafe defaults at startup |
| Apple login | JWKS verify, or disabled outside `dev` |
| `/media` | Not anonymously mounted outside local `dev` + `local` storage |
| CORS | Explicit origins in non-dev; no `*` + credentials |
| Retention run | Admin token (any env) or `dev` authenticated user — not arbitrary non-dev clients |
| Storage | Non-dev must use `STORAGE_BACKEND=s3` (no anonymous `/media`) |

## P1

| Item | Expectation |
|------|-------------|
| Story quota order | Child/voice/series checks before increment |
| Job / stream errors | `failed` + safe `error_message`; stream TTS failures fix status |
| Retention purge | Deletes audio objects (eager load audio) |
| Clone failure | Deletes ephemeral raw upload |
| Mobile 401 / history | Clear token; play/continue only when ready |

## Intentionally deferred

- Apple JWKS full verify, Redis atomic quota, job reaper/refund
- Splitting `story_prompt.py` / large screens, Alembic, `packages/shared`, GitHub CI / ruff rollout
---

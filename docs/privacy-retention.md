# Data retention (implementation map)

| Data | Where | Default TTL | Code |
|------|-------|-------------|------|
| Clone raw audio | ephemeral R2/local then delete | immediate + ≤24h sweeper | `POST /v1/voices/clone` (phase-1 gated by `FEATURE_VOICE_CLONE`), `purge_expired_raw_voices` |
| `voice_id` | MariaDB `voices` | until user delete / account delete | `DELETE /v1/voices/{id}`, `DELETE /v1/account` |
| Story text + audio | MariaDB + object storage | `STORY_RETENTION_MONTHS` (24) | `story.expires_at`, `purge_expired_stories` |
| Quota counters | Redis | ~40 days rolling | `services/quota.py` |
| Product analytics events | MariaDB `analytics_events` | `ANALYTICS_RETENTION_DAYS` (180) | `POST /v1/analytics/events`, `purge_expired_analytics_events` |
| Memory photos | Phase 2 — local-first | cloud extract window only | schema hooks on `stories.source` |
| Umeng U-APM (crash/perf) | Umeng (third-party) | per Umeng policy | Flutter `umeng_apm_sdk` + `umeng_common_sdk`; AppKeys in `assets/config/{env}.json` (or `*.local.json`) |

Cascade delete: `cascade_delete_user` removes DB rows (including `analytics_events`), object keys, and vendor clone voices.

Purge trigger: `POST /v1/account/retention/run` — header `X-Retention-Admin-Token` matching `RETENTION_ADMIN_TOKEN` (any env); or in `ENV=dev` an authenticated user. Production should cron this, not expose it to app clients. Response includes `purged_analytics_events`.

Cron helper: [`apps/api/scripts/run_retention.sh`](../apps/api/scripts/run_retention.sh) (see [deploy-staging.md](deploy-staging.md)).

User-facing disclosure: sibling Lullvale privacy HTML under `public/huhu/legal/privacy/`.

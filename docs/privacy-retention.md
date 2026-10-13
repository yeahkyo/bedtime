# Data retention (implementation map)

| Data | Where | Default TTL | Code |
|------|-------|-------------|------|
| Clone raw audio | ephemeral R2/local then delete | immediate + ≤24h sweeper | `POST /v1/voices/clone`, `purge_expired_raw_voices` |
| `voice_id` | MariaDB `voices` | until user delete / account delete | `DELETE /v1/voices/{id}`, `DELETE /v1/account` |
| Story text + audio | MariaDB + object storage | `STORY_RETENTION_MONTHS` (24) | `story.expires_at`, `purge_expired_stories` |
| Quota counters | Redis | ~40 days rolling | `services/quota.py` |
| Memory photos | Phase 2 — local-first | cloud extract window only | schema hooks on `stories.source` |

Cascade delete: `cascade_delete_user` removes DB rows, object keys, and vendor clone voices.

Purge trigger: `POST /v1/account/retention/run` — header `X-Retention-Admin-Token` matching `RETENTION_ADMIN_TOKEN` (any env); or in `ENV=dev` an authenticated user. Production should cron this, not expose it to app clients.

Cron helper: [`apps/api/scripts/run_retention.sh`](../apps/api/scripts/run_retention.sh) (see [deploy-staging.md](deploy-staging.md)).

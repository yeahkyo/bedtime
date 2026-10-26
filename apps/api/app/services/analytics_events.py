"""Product analytics event whitelist and helpers."""

from __future__ import annotations

import json
from typing import Any

ALLOWED_EVENT_NAMES: frozenset[str] = frozenset(
    {
        "app_open",
        "register_success",
        "login_success",
        "create_open",
        "generate_tap",
        "story_ready",
        "story_failed",
        "player_open",
        "playback_complete",
        "quota_hit",
    }
)

# Caps for ingest safety (trial-scale).
MAX_EVENTS_PER_REQUEST = 50
MAX_PROPS_JSON_BYTES = 2048


def normalize_idempotency_key(raw: str | None) -> str | None:
    if raw is None:
        return None
    key = raw.strip()
    if not key:
        return None
    return key[:64]


def serialize_props(props: dict[str, Any] | None) -> str | None:
    if not props:
        return None
    raw = json.dumps(props, ensure_ascii=False, separators=(",", ":"))
    encoded = raw.encode("utf-8")
    if len(encoded) <= MAX_PROPS_JSON_BYTES:
        return raw
    return encoded[:MAX_PROPS_JSON_BYTES].decode("utf-8", errors="ignore")

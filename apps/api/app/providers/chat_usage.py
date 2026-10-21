"""Normalize OpenAI-compatible chat usage + content for story metrics."""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any

# Preferred display order for admin metrics / prompts stages.
STAGE_ORDER = (
    "series_outline",
    "episode_plan",
    "draft",
    "tts",
    "storage",
)


@dataclass
class ChatOutcome:
    content: str
    prompt_tokens: int | None = None
    completion_tokens: int | None = None
    total_tokens: int | None = None
    reasoning_tokens: int | None = None

    def usage_dict(self) -> dict[str, int]:
        out: dict[str, int] = {}
        if self.prompt_tokens is not None:
            out["prompt_tokens"] = int(self.prompt_tokens)
        if self.completion_tokens is not None:
            out["completion_tokens"] = int(self.completion_tokens)
        if self.total_tokens is not None:
            out["total_tokens"] = int(self.total_tokens)
        if self.reasoning_tokens is not None:
            out["reasoning_tokens"] = int(self.reasoning_tokens)
        return out


def _as_int(val: Any) -> int | None:
    if val is None:
        return None
    try:
        return int(val)
    except (TypeError, ValueError):
        return None


def parse_chat_usage(data: dict[str, Any] | None) -> dict[str, int | None]:
    """Extract token counts from a chat.completions JSON body."""
    if not isinstance(data, dict):
        return {
            "prompt_tokens": None,
            "completion_tokens": None,
            "total_tokens": None,
            "reasoning_tokens": None,
        }
    usage = data.get("usage") if isinstance(data.get("usage"), dict) else {}
    prompt = _as_int(usage.get("prompt_tokens"))
    completion = _as_int(usage.get("completion_tokens"))
    total = _as_int(usage.get("total_tokens"))
    reasoning = None
    details = usage.get("completion_tokens_details")
    if isinstance(details, dict):
        reasoning = _as_int(details.get("reasoning_tokens"))
    if reasoning is None:
        reasoning = _as_int(usage.get("reasoning_tokens"))
    return {
        "prompt_tokens": prompt,
        "completion_tokens": completion,
        "total_tokens": total,
        "reasoning_tokens": reasoning,
    }


def outcome_from_response(data: dict[str, Any], content: str) -> ChatOutcome:
    u = parse_chat_usage(data)
    return ChatOutcome(content=content, **u)


def coerce_chat_outcome(raw: str | ChatOutcome) -> ChatOutcome:
    if isinstance(raw, ChatOutcome):
        return raw
    return ChatOutcome(content=raw or "")


def sum_token_field(stages: list[dict[str, Any]], key: str) -> int | None:
    vals = [int(s[key]) for s in stages if isinstance(s.get(key), int)]
    if not vals:
        return None
    return sum(vals)


def metrics_payload(
    *,
    stages: list[dict[str, Any]],
    pipeline_ms: int | None = None,
) -> dict[str, Any]:
    out: dict[str, Any] = {"stages": stages}
    if pipeline_ms is not None:
        out["pipeline_ms"] = int(pipeline_ms)
    for key in ("prompt_tokens", "completion_tokens", "total_tokens", "reasoning_tokens"):
        s = sum_token_field(stages, key)
        if s is not None:
            out[key] = s
    return out


def merge_job_metrics(
    llm_metrics: dict[str, Any] | None,
    *,
    llm_ms: int | None = None,
    tts_ms: int | None = None,
    storage_ms: int | None = None,
    total_ms: int | None = None,
) -> dict[str, Any]:
    out = dict(llm_metrics or {})
    if llm_ms is not None:
        out["llm_ms"] = int(llm_ms)
    if tts_ms is not None:
        out["tts_ms"] = int(tts_ms)
    if storage_ms is not None:
        out["storage_ms"] = int(storage_ms)
    if total_ms is not None:
        out["total_ms"] = int(total_ms)
    return out


def parse_metrics_json(raw: str | None) -> dict[str, Any]:
    if not (raw or "").strip():
        return {}
    try:
        loaded = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    return loaded if isinstance(loaded, dict) else {}


def _stage_name(row: Any) -> str:
    if not isinstance(row, dict):
        return ""
    return str(row.get("stage") or "").strip()


def _stage_keep_score(row: dict[str, Any]) -> int:
    """Prefer real LLM timings over resume skip placeholders."""
    if row.get("skipped"):
        return 0
    return 1


def merge_stage_rows(
    prior: list[Any] | None,
    newer: list[Any] | None,
) -> list[dict[str, Any]]:
    """Merge stage metric/prompt rows by stage name; later wins unless it is a skip."""
    by_name: dict[str, dict[str, Any]] = {}
    seen: list[str] = []
    for row in list(prior or []) + list(newer or []):
        name = _stage_name(row)
        if not name or not isinstance(row, dict):
            continue
        prev = by_name.get(name)
        if prev is None:
            by_name[name] = dict(row)
            seen.append(name)
            continue
        # Keep richer prior when newer is only a resume skip marker.
        if _stage_keep_score(row) < _stage_keep_score(prev):
            continue
        by_name[name] = dict(row)

    order_index = {name: i for i, name in enumerate(STAGE_ORDER)}
    unknown_base = len(STAGE_ORDER)

    def sort_key(name: str) -> tuple[int, int]:
        if name in order_index:
            return (order_index[name], 0)
        return (unknown_base, seen.index(name) if name in seen else 0)

    return [by_name[n] for n in sorted(by_name.keys(), key=sort_key)]


def _as_nonneg_int(val: Any) -> int | None:
    n = _as_int(val)
    if n is None or n < 0:
        return None
    return n


def llm_ms_from_metrics(metrics: dict[str, Any] | None) -> int | None:
    """Wall LLM time: prefer stored llm_ms, else sum non-tts stage ms."""
    if not isinstance(metrics, dict):
        return None
    stored = _as_nonneg_int(metrics.get("llm_ms"))
    if stored is not None:
        return stored
    stages = metrics.get("stages")
    if not isinstance(stages, list):
        return None
    total = 0
    found = False
    for row in stages:
        if not isinstance(row, dict):
            continue
        if _stage_name(row) in ("tts", "storage"):
            continue
        if row.get("skipped"):
            continue
        ms = _as_nonneg_int(row.get("ms"))
        if ms is None:
            continue
        total += ms
        found = True
    return total if found else None


def merge_metrics_dicts(
    prior: dict[str, Any] | None,
    newer: dict[str, Any] | None,
    *,
    llm_ms: int | None = None,
    tts_ms: int | None = None,
    storage_ms: int | None = None,
    total_ms: int | None = None,
) -> dict[str, Any]:
    """
    Merge metrics across attempts (e.g. plan on first try, draft on retry).

    Stages are keyed by name. Token totals are recomputed from merged stages.
    pipeline_ms / llm_ms accumulate when both sides have values.
    """
    p = prior if isinstance(prior, dict) else {}
    n = newer if isinstance(newer, dict) else {}
    stages = merge_stage_rows(p.get("stages"), n.get("stages"))
    pipeline_parts = [
        x
        for x in (_as_nonneg_int(p.get("pipeline_ms")), _as_nonneg_int(n.get("pipeline_ms")))
        if x is not None
    ]
    pipeline_ms = sum(pipeline_parts) if pipeline_parts else None
    out = metrics_payload(stages=stages, pipeline_ms=pipeline_ms)
    for key in ("tts_skipped",):
        if key in n:
            out[key] = n[key]
        elif key in p:
            out[key] = p[key]

    if llm_ms is not None:
        # Caller passed this-attempt wall clock; keep prior attempt time.
        llm_ms = (llm_ms_from_metrics(p) or 0) + int(llm_ms)
    else:
        prior_llm = llm_ms_from_metrics(p)
        # Prefer stage sum for newer when top-level llm_ms absent (pipeline payload).
        newer_without_llm = {k: v for k, v in n.items() if k != "llm_ms"}
        newer_llm = _as_nonneg_int(n.get("llm_ms"))
        if newer_llm is None:
            newer_llm = llm_ms_from_metrics(newer_without_llm)
        if prior_llm is not None or newer_llm is not None:
            llm_ms = (prior_llm or 0) + (newer_llm or 0)
    if tts_ms is None:
        tts_ms = _as_nonneg_int(n.get("tts_ms"))
        if tts_ms is None:
            tts_ms = _as_nonneg_int(p.get("tts_ms"))
    if storage_ms is None:
        storage_ms = _as_nonneg_int(n.get("storage_ms"))
        if storage_ms is None:
            storage_ms = _as_nonneg_int(p.get("storage_ms"))
    if total_ms is None:
        total_ms = _as_nonneg_int(n.get("total_ms"))
        if total_ms is None:
            total_ms = _as_nonneg_int(p.get("total_ms"))

    return merge_job_metrics(
        out,
        llm_ms=llm_ms,
        tts_ms=tts_ms,
        storage_ms=storage_ms,
        total_ms=total_ms,
    )


def metrics_as_jsonable(metrics: dict[str, Any]) -> dict[str, Any]:
    """Ensure nested values are JSON-serializable primitives."""
    try:
        return json.loads(json.dumps(metrics, default=str))
    except Exception:
        return {
            k: v
            for k, v in metrics.items()
            if isinstance(v, (str, int, float, list, dict, bool, type(None)))
        }

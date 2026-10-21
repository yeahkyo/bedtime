"""Ad-hoc OpenAI-compatible chat for agent provider overrides."""

from __future__ import annotations

import logging

import httpx

from app.core.config import get_settings
from app.providers.chat_usage import ChatOutcome, outcome_from_response
from app.services.llm_agents import resolve_temperature
from app.services.provider_settings import (
    resolve_story_model,
    resolve_story_provider_name,
)

logger = logging.getLogger(__name__)


async def chat_with_provider(
    *,
    provider: str,
    model: str | None,
    system: str,
    user: str,
    max_tokens: int,
    timeout: float,
    stage: str = "chat",
    thinking: bool | None = None,
    reasoning_effort: str | None = None,
    temperature: float | None = None,
) -> ChatOutcome:
    """Chat via named provider; model falls back to runtime override then env."""
    settings = get_settings()
    name = (provider or "").strip().lower() or await resolve_story_provider_name()
    chosen_model = (model or "").strip() or await resolve_story_model(name)

    if name == "doubao":
        if not settings.ark_api_key:
            raise RuntimeError("ARK_API_KEY not configured")
        base = settings.ark_base_url.rstrip("/")
        key = settings.ark_api_key
    elif name == "deepseek":
        if not settings.deepseek_api_key:
            raise RuntimeError("DEEPSEEK_API_KEY not configured")
        base = settings.deepseek_base_url.rstrip("/")
        key = settings.deepseek_api_key
    elif name == "openai":
        if not settings.openai_api_key:
            raise RuntimeError("OPENAI_API_KEY not configured")
        base = "https://api.openai.com/v1"
        key = settings.openai_api_key
    else:
        raise ValueError(f"unsupported agent provider: {name}")

    headers = {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }
    payload: dict = {
        "model": chosen_model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "temperature": resolve_temperature(temperature),
        "max_tokens": max_tokens,
    }
    if name == "deepseek":
        from app.providers.deepseek_budget import (
            effort_for_stage,
            normalize_effort,
            total_max_tokens,
        )

        thinking_on = (
            bool(settings.deepseek_thinking) if thinking is None else bool(thinking)
        )
        if reasoning_effort is not None:
            effort = normalize_effort(reasoning_effort)
        else:
            effort = effort_for_stage(
                stage, settings_effort=settings.deepseek_reasoning_effort
            )
        payload["thinking"] = {"type": "enabled" if thinking_on else "disabled"}
        # max_tokens arg is content budget; add CoT reserve when thinking.
        payload["max_tokens"] = total_max_tokens(
            max_tokens, thinking_on=thinking_on, effort=effort
        )
        if thinking_on:
            payload["reasoning_effort"] = effort
        payload["response_format"] = {"type": "json_object"}
    elif name == "openai":
        payload["response_format"] = {"type": "json_object"}

    async with httpx.AsyncClient(timeout=timeout) as client:
        resp = await client.post(
            f"{base}/chat/completions", headers=headers, json=payload
        )
        resp.raise_for_status()
        data = resp.json()
    try:
        content = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise RuntimeError(f"unexpected chat response for {stage}") from exc
    if not isinstance(content, str) or not content.strip():
        raise RuntimeError(f"empty chat content for {stage}")
    return outcome_from_response(data, content)

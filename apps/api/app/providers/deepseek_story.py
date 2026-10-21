import logging
from collections.abc import AsyncIterator

import httpx

from app.core.config import get_settings
from app.providers.base import StoryProvider, StoryRequest, StoryResult
from app.providers.chat_usage import ChatOutcome, outcome_from_response
from app.providers.deepseek_budget import (
    DeepSeekTruncatedError,
    effort_for_stage,
    normalize_effort,
    total_max_tokens,
)
from app.providers.story_pipeline import run_story_pipeline

logger = logging.getLogger(__name__)


def _effective_max_tokens(
    requested: int, *, thinking_on: bool, effort: str = "low"
) -> int:
    """Back-compat: content budget + CoT reserve when thinking is on."""
    return total_max_tokens(requested, thinking_on=thinking_on, effort=effort)


class DeepSeekStoryProvider(StoryProvider):
    """DeepSeek chat completions — OpenAI-compatible API."""

    async def generate(
        self, request: StoryRequest, on_progress=None, on_plan=None
    ) -> StoryResult:
        settings = get_settings()
        if not settings.deepseek_api_key:
            raise RuntimeError("DEEPSEEK_API_KEY is not set")
        base = (settings.deepseek_base_url or "https://api.deepseek.com").rstrip("/")
        settings_thinking = bool(settings.deepseek_thinking)
        settings_effort = normalize_effort(settings.deepseek_reasoning_effort)

        async def chat(
            system: str,
            user: str,
            *,
            max_tokens: int,
            timeout: float,
            stage: str = "chat",
            model: str | None = None,
            thinking: bool | None = None,
            reasoning_effort: str | None = None,
            temperature: float | None = None,
            **_kwargs,
        ) -> ChatOutcome:
            # max_tokens here is *content* budget (visible JSON), not API total.
            from app.services.llm_agents import resolve_temperature
            from app.services.provider_settings import resolve_story_model

            thinking_on = settings_thinking if thinking is None else bool(thinking)
            if reasoning_effort is not None:
                effort = normalize_effort(reasoning_effort)
            else:
                effort = effort_for_stage(stage, settings_effort=settings_effort)
            effective_max = total_max_tokens(
                max_tokens, thinking_on=thinking_on, effort=effort
            )
            chosen = (model or "").strip() or await resolve_story_model("deepseek")
            body: dict = {
                "model": chosen,
                "response_format": {"type": "json_object"},
                "thinking": {"type": "enabled" if thinking_on else "disabled"},
                "messages": [
                    {"role": "system", "content": system},
                    {"role": "user", "content": user},
                ],
                "max_tokens": effective_max,
                "temperature": resolve_temperature(temperature),
            }
            if thinking_on:
                body["reasoning_effort"] = effort
            try:
                async with httpx.AsyncClient(timeout=timeout) as client:
                    resp = await client.post(
                        f"{base}/chat/completions",
                        headers={
                            "Authorization": f"Bearer {settings.deepseek_api_key}",
                            "Content-Type": "application/json",
                        },
                        json=body,
                    )
            except httpx.TimeoutException as exc:
                raise RuntimeError(
                    f"DeepSeek {stage} timed out after {int(timeout)}s "
                    f"(duration_minutes={request.duration_minutes})."
                ) from exc
            if resp.status_code >= 400:
                raise RuntimeError(
                    f"DeepSeek {stage} failed {resp.status_code}: {resp.text[:800]}"
                )
            data = resp.json()
            choice = data["choices"][0]
            message = choice.get("message") or {}
            content = message.get("content") or ""
            reasoning = message.get("reasoning_content") or ""
            finish = choice.get("finish_reason")
            reasoning_chars = len(str(reasoning))
            content_chars = len(str(content))
            logger.info(
                "deepseek_chat stage=%s thinking=%s effort=%s "
                "content_budget=%s max_tokens=%s reasoning_chars=%s content_chars=%s finish=%s",
                stage,
                thinking_on,
                effort if thinking_on else "-",
                max_tokens,
                effective_max,
                reasoning_chars,
                content_chars,
                finish,
            )
            if not str(content).strip():
                raise DeepSeekTruncatedError(
                    f"DeepSeek {stage} returned empty content (finish_reason={finish})",
                    stage=stage,
                    finish_reason=finish,
                    reasoning_chars=reasoning_chars,
                    content_chars=content_chars,
                    max_tokens=effective_max,
                    effort=effort if thinking_on else None,
                )
            if finish == "length" and "{" in content and content.rstrip()[-1:] != "}":
                raise DeepSeekTruncatedError(
                    f"DeepSeek {stage} truncated (finish_reason=length, "
                    f"max_tokens={effective_max}). preview={content[:200]!r}",
                    stage=stage,
                    finish_reason=finish,
                    reasoning_chars=reasoning_chars,
                    content_chars=content_chars,
                    max_tokens=effective_max,
                    effort=effort if thinking_on else None,
                )
            return outcome_from_response(data, content)

        return await run_story_pipeline(
            request,
            chat=chat,
            on_progress=on_progress,
            on_plan=on_plan,
            default_provider="deepseek",
        )

    async def generate_stream(self, request: StoryRequest) -> AsyncIterator[str]:
        result = await self.generate(request)
        buf = ""
        for ch in result.body:
            buf += ch
            if ch in "。！？.!?\n" and buf.strip():
                yield buf
                buf = ""
        if buf.strip():
            yield buf

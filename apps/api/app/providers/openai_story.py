from collections.abc import AsyncIterator

import httpx

from app.core.config import get_settings
from app.providers.base import StoryProvider, StoryRequest, StoryResult
from app.providers.chat_usage import ChatOutcome, outcome_from_response
from app.providers.story_pipeline import run_story_pipeline


class OpenAIStoryProvider(StoryProvider):
    async def generate(
        self, request: StoryRequest, on_progress=None, on_plan=None
    ) -> StoryResult:
        settings = get_settings()
        if not settings.openai_api_key:
            raise RuntimeError("OPENAI_API_KEY is not set")

        async def chat(
            system: str,
            user: str,
            *,
            max_tokens: int,
            timeout: float,
            stage: str = "chat",
            model: str | None = None,
            temperature: float | None = None,
            **_kwargs,
        ) -> ChatOutcome:
            from app.services.llm_agents import resolve_temperature
            from app.services.provider_settings import resolve_story_model

            chosen = (model or "").strip() or await resolve_story_model("openai")
            try:
                async with httpx.AsyncClient(timeout=timeout) as client:
                    resp = await client.post(
                        "https://api.openai.com/v1/chat/completions",
                        headers={"Authorization": f"Bearer {settings.openai_api_key}"},
                        json={
                            "model": chosen,
                            "response_format": {"type": "json_object"},
                            "messages": [
                                {"role": "system", "content": system},
                                {"role": "user", "content": user},
                            ],
                            "max_tokens": max_tokens,
                            "temperature": resolve_temperature(temperature),
                        },
                    )
            except httpx.TimeoutException as exc:
                raise RuntimeError(
                    f"OpenAI {stage} timed out after {int(timeout)}s "
                    f"(duration_minutes={request.duration_minutes})."
                ) from exc
            if resp.status_code >= 400:
                raise RuntimeError(
                    f"OpenAI {stage} failed {resp.status_code}: {resp.text[:800]}"
                )
            data = resp.json()
            choice = data["choices"][0]
            content = (choice.get("message") or {}).get("content") or ""
            finish = choice.get("finish_reason")
            if not str(content).strip():
                raise RuntimeError(
                    f"OpenAI {stage} returned empty content (finish_reason={finish})"
                )
            if finish == "length" and "{" in content and content.rstrip()[-1:] != "}":
                raise RuntimeError(
                    f"OpenAI {stage} truncated (finish_reason=length, "
                    f"max_tokens={max_tokens}). preview={content[:200]!r}"
                )
            return outcome_from_response(data, content)

        return await run_story_pipeline(
            request,
            chat=chat,
            on_progress=on_progress,
            on_plan=on_plan,
            default_provider="openai",
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

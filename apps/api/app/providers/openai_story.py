from collections.abc import AsyncIterator

import httpx

from app.core.config import get_settings
from app.providers.base import StoryProvider, StoryRequest, StoryResult
from app.providers.story_pipeline import run_story_pipeline


class OpenAIStoryProvider(StoryProvider):
    async def generate(self, request: StoryRequest, on_progress=None) -> StoryResult:
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
        ) -> str:
            try:
                async with httpx.AsyncClient(timeout=timeout) as client:
                    resp = await client.post(
                        "https://api.openai.com/v1/chat/completions",
                        headers={"Authorization": f"Bearer {settings.openai_api_key}"},
                        json={
                            "model": settings.openai_model,
                            "response_format": {"type": "json_object"},
                            "messages": [
                                {"role": "system", "content": system},
                                {"role": "user", "content": user},
                            ],
                            "max_tokens": max_tokens,
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
            choice = resp.json()["choices"][0]
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
            return content

        return await run_story_pipeline(request, chat=chat, on_progress=on_progress)

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

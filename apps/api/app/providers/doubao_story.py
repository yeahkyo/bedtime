from collections.abc import AsyncIterator

import httpx

from app.core.config import get_settings
from app.providers.base import StoryProvider, StoryRequest, StoryResult
from app.providers.chat_usage import ChatOutcome, outcome_from_response
from app.providers.story_pipeline import run_story_pipeline


class DoubaoStoryProvider(StoryProvider):
    """Volcengine Ark (豆包) chat completions — OpenAI-compatible."""

    async def generate(
        self, request: StoryRequest, on_progress=None, on_plan=None
    ) -> StoryResult:
        settings = get_settings()
        if not settings.ark_api_key:
            raise RuntimeError("ARK_API_KEY is not set")

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

            chosen = (model or "").strip() or await resolve_story_model("doubao")
            try:
                async with httpx.AsyncClient(timeout=timeout) as client:
                    resp = await client.post(
                        f"{settings.ark_base_url.rstrip('/')}/chat/completions",
                        headers={
                            "Authorization": f"Bearer {settings.ark_api_key}",
                            "Content-Type": "application/json",
                        },
                        json={
                            "model": chosen,
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
                    f"Ark {stage} timed out after {int(timeout)}s "
                    f"(duration_minutes={request.duration_minutes})."
                ) from exc
            if resp.status_code >= 400:
                raise RuntimeError(
                    f"Ark {stage} failed {resp.status_code}: {resp.text[:800]}"
                )
            data = resp.json()
            choice = data["choices"][0]
            message = choice.get("message") or {}
            content = message.get("content") or ""
            finish = choice.get("finish_reason")
            if not str(content).strip():
                raise RuntimeError(
                    f"Ark {stage} returned empty content (finish_reason={finish})"
                )
            if finish == "length":
                # Caller may still parse; tag via suffix comment is awkward — raise if
                # truncated mid-output by appending a marker the parser will surface.
                # Prefer explicit error when clearly cut off (no closing brace).
                if "{" in content and content.rstrip()[-1:] != "}":
                    raise RuntimeError(
                        f"Ark {stage} truncated (finish_reason=length, "
                        f"max_tokens={max_tokens}). preview={content[:200]!r}"
                    )
            return outcome_from_response(data, content)

        return await run_story_pipeline(
            request,
            chat=chat,
            on_progress=on_progress,
            on_plan=on_plan,
            default_provider="doubao",
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

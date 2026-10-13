import asyncio
from collections.abc import AsyncIterator

from app.providers.base import (
    StoryProvider,
    StoryRequest,
    StoryResult,
    TtsProvider,
    VoiceCloneProvider,
    VoiceSettings,
)

# Minimal valid-ish silent-ish MPEG frame padding for local playback tests.
_MOCK_MP3 = (
    b"\xff\xfb\x90\x00" + b"\x00" * 256
)


class MockStoryProvider(StoryProvider):
    async def generate(self, request: StoryRequest, on_progress=None) -> StoryResult:
        if on_progress:
            await on_progress("episode_plan")
        await asyncio.sleep(0.05)
        if on_progress:
            await on_progress("draft")
        if request.language.startswith("zh"):
            title = f"{request.child_nickname}与{request.theme or '月光'}的夜晚"
            body = (
                f"从前，有个叫{request.child_nickname}的小朋友。"
                f"今晚，{request.child_nickname}轻轻走进一个安静的故事。"
                f"主题是「{request.theme or '温柔的冒险'}」。"
                "星星眨着眼，风像妈妈的手一样轻。"
                f"{request.child_nickname}帮小兔子找到了回家的路，大家安心地笑了。"
                "月亮低低地说：晚安。世界慢慢变软，呼吸也变慢。"
                "故事讲完了。明天如果愿意，还可以再听一点点。"
            )
            hook = "明天，湖对面的灯或许会亮一下。"
        else:
            title = f"{request.child_nickname} and the {request.theme or 'Moonlight'}"
            body = (
                f"Once, a child named {request.child_nickname} stepped into a quiet night. "
                f"The theme was “{request.theme or 'a gentle adventure'}”. "
                "Stars blinked softly, and the wind felt like a hug. "
                f"{request.child_nickname} helped a small rabbit find the way home. "
                "Everyone felt safe. The moon whispered good night. "
                "Breaths grew slower. The story ended gently. "
                "Tomorrow, if you like, another soft page may wait."
            )
            hook = "Tomorrow, a lantern across the lake might glow once."
        if request.recap:
            body = f"{request.recap}\n\n{body}"
        outline = None
        series_title = None
        ep_no = request.episode_no if request.soft_series_mode else None
        if request.need_series_outline or (request.soft_series_mode and not request.series_outline):
            n = max(2, min(8, int(request.episode_count or 4)))
            outline = {
                "title": title + "·系列",
                "throughline": "轻轻回家",
                "cast_spine": [request.child_nickname],
                "threads": [{"id": "t1", "what": "一盏小灯", "payoff_episode": n}],
                "episodes": [
                    {
                        "episode_no": i,
                        "focus_id": "tiny_brave",
                        "focus_how": "试一下",
                        "premise": f"第{i}夜的小事",
                        "soft_promise": "今晚有一点点好奇",
                        "plants": [],
                        "payoffs": [],
                        "sleep_note": "安心睡",
                    }
                    for i in range(1, n + 1)
                ],
            }
            series_title = outline["title"]
            ep_no = 1
        return StoryResult(
            title=title,
            body=body,
            soft_hook=hook if request.soft_series_mode else None,
            series_outline=outline,
            series_title=series_title,
            episode_no=ep_no,
        )

    async def generate_stream(self, request: StoryRequest) -> AsyncIterator[str]:
        result = await self.generate(request)
        chunk_size = 24
        for i in range(0, len(result.body), chunk_size):
            await asyncio.sleep(0.02)
            yield result.body[i : i + chunk_size]


class MockTtsProvider(TtsProvider):
    async def synthesize(
        self,
        text: str,
        voice_id: str,
        settings: VoiceSettings,
        *,
        speech_rate_delta: int = 0,
        loudness_rate: int = 0,
        ssml: str | None = None,
    ) -> bytes:
        await asyncio.sleep(0.05)
        # Repeat a tiny payload so players have something to buffer.
        n = len(ssml or text)
        return _MOCK_MP3 * max(8, min(40, n // 20))

    async def synthesize_stream(
        self,
        text: str,
        voice_id: str,
        settings: VoiceSettings,
        *,
        speech_rate_delta: int = 0,
        loudness_rate: int = 0,
        ssml: str | None = None,
    ) -> AsyncIterator[bytes]:
        data = await self.synthesize(
            text,
            voice_id,
            settings,
            speech_rate_delta=speech_rate_delta,
            loudness_rate=loudness_rate,
            ssml=ssml,
        )
        step = 512
        for i in range(0, len(data), step):
            await asyncio.sleep(0.01)
            yield data[i : i + step]


class MockVoiceCloneProvider(VoiceCloneProvider):
    async def clone(self, name: str, audio_bytes: bytes, filename: str, language: str) -> str:
        await asyncio.sleep(0.05)
        return f"mock_voice_{abs(hash(name + filename)) % 10_000_000}"

    async def delete(self, provider_voice_id: str) -> None:
        await asyncio.sleep(0.01)

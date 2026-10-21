from collections.abc import AsyncIterator

import httpx

from app.core.config import get_settings
from app.providers.base import TtsProvider, VoiceCloneProvider, VoiceSettings


class ElevenLabsTtsProvider(TtsProvider):
    async def synthesize(
        self,
        text: str,
        voice_id: str,
        settings: VoiceSettings,
        *,
        speech_rate_delta: int = 0,
        loudness_rate: int = 0,
        ssml: str | None = None,
        model: str | None = None,
    ) -> bytes:
        cfg = get_settings()
        if not cfg.elevenlabs_api_key:
            raise RuntimeError("ELEVENLABS_API_KEY is not set")
        from app.services.provider_settings import resolve_speech_model

        # ElevenLabs has no Volc SSML; use plain text (caller already punctuates).
        _ = ssml
        # Map Volc-style rate delta (~-50..100) onto ElevenLabs speed lightly.
        speed = max(0.7, min(1.2, settings.speed + speech_rate_delta / 200.0))
        model_id = (model or "").strip() or await resolve_speech_model("elevenlabs")
        url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
        async with httpx.AsyncClient(timeout=180) as client:
            resp = await client.post(
                url,
                headers={
                    "xi-api-key": cfg.elevenlabs_api_key,
                    "Accept": "audio/mpeg",
                    "Content-Type": "application/json",
                },
                json={
                    "text": text,
                    "model_id": model_id or cfg.elevenlabs_model_id,
                    "voice_settings": {
                        "stability": settings.stability,
                        "similarity_boost": settings.similarity_boost,
                        "style": settings.style,
                        "speed": speed,
                    },
                },
            )
            resp.raise_for_status()
            return resp.content

    async def synthesize_stream(
        self,
        text: str,
        voice_id: str,
        settings: VoiceSettings,
        *,
        speech_rate_delta: int = 0,
        loudness_rate: int = 0,
        ssml: str | None = None,
        model: str | None = None,
    ) -> AsyncIterator[bytes]:
        cfg = get_settings()
        if not cfg.elevenlabs_api_key:
            raise RuntimeError("ELEVENLABS_API_KEY is not set")
        from app.services.provider_settings import resolve_speech_model

        _ = ssml
        speed = max(0.7, min(1.2, settings.speed + speech_rate_delta / 200.0))
        model_id = (model or "").strip() or await resolve_speech_model("elevenlabs")
        url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}/stream"
        async with httpx.AsyncClient(timeout=180) as client:
            async with client.stream(
                "POST",
                url,
                headers={
                    "xi-api-key": cfg.elevenlabs_api_key,
                    "Accept": "audio/mpeg",
                    "Content-Type": "application/json",
                },
                json={
                    "text": text,
                    "model_id": model_id or cfg.elevenlabs_model_id,
                    "voice_settings": {
                        "stability": settings.stability,
                        "similarity_boost": settings.similarity_boost,
                        "style": settings.style,
                        "speed": speed,
                    },
                },
            ) as resp:
                resp.raise_for_status()
                async for chunk in resp.aiter_bytes():
                    if chunk:
                        yield chunk


class ElevenLabsVoiceCloneProvider(VoiceCloneProvider):
    async def clone(self, name: str, audio_bytes: bytes, filename: str, language: str) -> str:
        cfg = get_settings()
        if not cfg.elevenlabs_api_key:
            raise RuntimeError("ELEVENLABS_API_KEY is not set")
        async with httpx.AsyncClient(timeout=180) as client:
            resp = await client.post(
                "https://api.elevenlabs.io/v1/voices/add",
                headers={"xi-api-key": cfg.elevenlabs_api_key},
                data={"name": name, "description": f"Lullvale parent voice ({language})"},
                files={"files": (filename, audio_bytes, "audio/mpeg")},
            )
            resp.raise_for_status()
            return resp.json()["voice_id"]

    async def delete(self, provider_voice_id: str) -> None:
        cfg = get_settings()
        if not cfg.elevenlabs_api_key:
            return
        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.delete(
                f"https://api.elevenlabs.io/v1/voices/{provider_voice_id}",
                headers={"xi-api-key": cfg.elevenlabs_api_key},
            )
            if resp.status_code not in (200, 204, 404):
                resp.raise_for_status()

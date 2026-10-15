"""Fish Audio TTS + persistent voice clone (httpx)."""

from __future__ import annotations

import asyncio
import logging
import time
from collections.abc import AsyncIterator

import httpx

from app.core.config import get_settings
from app.providers.base import TtsProvider, VoiceCloneProvider, VoiceSettings

logger = logging.getLogger(__name__)


class FishAudioTtsProvider(TtsProvider):
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
        chunks: list[bytes] = []
        async for chunk in self.synthesize_stream(
            text,
            voice_id,
            settings,
            speech_rate_delta=speech_rate_delta,
            loudness_rate=loudness_rate,
            ssml=ssml,
        ):
            chunks.append(chunk)
        return b"".join(chunks)

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
        _ = ssml  # Fish has no Volc-style SSML; caller uses punctuated plain text.
        cfg = get_settings()
        if not cfg.fish_audio_api_key:
            raise RuntimeError("FISH_AUDIO_API_KEY is not set")
        speed = max(0.5, min(2.0, settings.speed + speech_rate_delta / 200.0))
        volume = float(max(-20, min(20, loudness_rate / 5.0)))
        base = (cfg.fish_audio_base_url or "https://api.fish.audio").rstrip("/")
        headers = {
            "Authorization": f"Bearer {cfg.fish_audio_api_key}",
            "Content-Type": "application/json",
            "model": cfg.fish_audio_tts_model or "s2-pro",
        }
        payload = {
            "text": text,
            "reference_id": voice_id,
            "format": "mp3",
            "mp3_bitrate": 128,
            "normalize": True,
            "latency": "normal",
            "prosody": {
                "speed": speed,
                "volume": volume,
                "normalize_loudness": True,
            },
        }
        async with httpx.AsyncClient(timeout=180) as client:
            async with client.stream(
                "POST",
                f"{base}/v1/tts",
                headers=headers,
                json=payload,
            ) as resp:
                if resp.status_code >= 400:
                    body = (await resp.aread())[:800]
                    raise RuntimeError(
                        f"Fish Audio TTS failed {resp.status_code}: {body!r}"
                    )
                async for chunk in resp.aiter_bytes():
                    if chunk:
                        yield chunk


class FishAudioVoiceCloneProvider(VoiceCloneProvider):
    async def clone(self, name: str, audio_bytes: bytes, filename: str, language: str) -> str:
        cfg = get_settings()
        if not cfg.fish_audio_api_key:
            raise RuntimeError("FISH_AUDIO_API_KEY is not set")
        base = (cfg.fish_audio_base_url or "https://api.fish.audio").rstrip("/")
        headers = {"Authorization": f"Bearer {cfg.fish_audio_api_key}"}
        async with httpx.AsyncClient(timeout=180) as client:
            resp = await client.post(
                f"{base}/model",
                headers=headers,
                data={
                    "type": "tts",
                    "title": name,
                    "description": f"Lullvale parent voice ({language})",
                    "visibility": "private",
                    "train_mode": "fast",
                    "enhance_audio_quality": "true",
                },
                files={"voices": (filename or "sample.wav", audio_bytes, "application/octet-stream")},
            )
            if resp.status_code >= 400:
                raise RuntimeError(
                    f"Fish Audio clone failed {resp.status_code}: {resp.text[:800]}"
                )
            data = resp.json()
            voice_id = data.get("_id") or data.get("id")
            if not voice_id:
                raise RuntimeError("Fish Audio clone returned no model id")
            state = (data.get("state") or "").lower()
            if state in ("", "trained"):
                return str(voice_id)
            # Poll until trained (fast mode is usually immediate).
            deadline = time.monotonic() + 300
            while time.monotonic() < deadline:
                await asyncio.sleep(2)
                poll = await client.get(f"{base}/model/{voice_id}", headers=headers)
                if poll.status_code >= 400:
                    raise RuntimeError(
                        f"Fish Audio clone poll failed {poll.status_code}: {poll.text[:400]}"
                    )
                info = poll.json()
                state = (info.get("state") or "").lower()
                if state == "trained":
                    return str(voice_id)
                if state == "failed":
                    raise RuntimeError(f"Fish Audio voice {voice_id} training failed")
            raise TimeoutError(f"Fish Audio voice {voice_id} not ready (state={state})")

    async def delete(self, provider_voice_id: str) -> None:
        cfg = get_settings()
        if not cfg.fish_audio_api_key or not provider_voice_id:
            return
        base = (cfg.fish_audio_base_url or "https://api.fish.audio").rstrip("/")
        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.delete(
                f"{base}/model/{provider_voice_id}",
                headers={"Authorization": f"Bearer {cfg.fish_audio_api_key}"},
            )
            if resp.status_code not in (200, 204, 404):
                logger.warning(
                    "Fish Audio delete voice %s → %s %s",
                    provider_voice_id,
                    resp.status_code,
                    resp.text[:200],
                )

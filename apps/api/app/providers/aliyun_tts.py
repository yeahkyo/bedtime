"""Aliyun Model Studio (DashScope) CosyVoice TTS + voice enrollment (httpx)."""

from __future__ import annotations

import base64
import json
import logging
import re
from collections.abc import AsyncIterator
from typing import Any

import httpx

from app.core.config import get_settings
from app.providers.base import TtsProvider, VoiceCloneProvider, VoiceSettings

logger = logging.getLogger(__name__)


def _api_key() -> str:
    cfg = get_settings()
    key = (cfg.aliyun_dashscope_api_key or cfg.dashscope_api_key or "").strip()
    if not key:
        raise RuntimeError("ALIYUN_DASHSCOPE_API_KEY (or DASHSCOPE_API_KEY) is not set")
    return key


def _workspace_base() -> str:
    """https://{workspace}.{region}.maas.aliyuncs.com/api/v1 or legacy dashscope host."""
    cfg = get_settings()
    override = (cfg.aliyun_tts_base_url or "").strip().rstrip("/")
    if override:
        # Allow full TTS endpoint or api/v1 root.
        if override.endswith("/SpeechSynthesizer"):
            return override.rsplit("/services/", 1)[0]
        if "/services/" in override:
            return override.split("/services/", 1)[0]
        return override
    ws = (cfg.aliyun_tts_workspace_id or "").strip()
    if ws:
        region = (cfg.aliyun_tts_region or "cn-beijing").strip()
        return f"https://{ws}.{region}.maas.aliyuncs.com/api/v1"
    # Legacy shared DashScope host (still works for some accounts).
    return "https://dashscope.aliyuncs.com/api/v1"


def _tts_url() -> str:
    return f"{_workspace_base()}/services/audio/tts/SpeechSynthesizer"


def _customization_url() -> str:
    return f"{_workspace_base()}/services/audio/tts/customization"


def _auth_headers(*, sse: bool = False) -> dict[str, str]:
    headers = {
        "Authorization": f"Bearer {_api_key()}",
        "Content-Type": "application/json",
    }
    if sse:
        headers["X-DashScope-SSE"] = "enable"
    return headers


def _map_rate(settings: VoiceSettings, speech_rate_delta: int) -> float:
    return max(0.5, min(2.0, float(settings.speed) + speech_rate_delta / 200.0))


def _map_volume(loudness_rate: int) -> int:
    return int(max(0, min(100, 50 + loudness_rate)))


def _safe_prefix(name: str) -> str:
    slug = re.sub(r"[^a-zA-Z0-9]", "", name or "")[:10]
    if not slug:
        slug = "voice"
    if slug[0].isdigit():
        slug = "v" + slug[:9]
    return slug.lower()


def _parse_sse_json_events(buffer: str) -> tuple[list[dict[str, Any]], str]:
    """Split SSE text into JSON objects; return (events, remainder)."""
    events: list[dict[str, Any]] = []
    parts = re.split(r"\n\n+", buffer)
    if not buffer.endswith("\n\n") and not buffer.endswith("\r\n\r\n"):
        remainder = parts[-1] if parts else ""
        chunks = parts[:-1]
    else:
        remainder = ""
        chunks = parts
    for chunk in chunks:
        data_lines: list[str] = []
        for line in chunk.splitlines():
            if line.startswith("data:"):
                data_lines.append(line[5:].lstrip())
        if not data_lines:
            continue
        raw = "\n".join(data_lines).strip()
        if not raw or raw == "[DONE]":
            continue
        try:
            obj = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if isinstance(obj, dict):
            events.append(obj)
    return events, remainder


def _audio_b64_from_event(obj: dict[str, Any]) -> str | None:
    output = obj.get("output")
    if not isinstance(output, dict):
        return None
    audio = output.get("audio")
    if isinstance(audio, dict):
        data = audio.get("data")
        if isinstance(data, str) and data.strip():
            return data.strip()
    # Some frames nest differently.
    data = output.get("data")
    if isinstance(data, str) and data.strip():
        return data.strip()
    return None


class AliyunTtsProvider(TtsProvider):
    """CosyVoice non-realtime HTTP (SSE stream preferred; URL download fallback)."""

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
        chunks: list[bytes] = []
        async for chunk in self.synthesize_stream(
            text,
            voice_id,
            settings,
            speech_rate_delta=speech_rate_delta,
            loudness_rate=loudness_rate,
            ssml=ssml,
            model=model,
        ):
            chunks.append(chunk)
        audio = b"".join(chunks)
        if audio:
            return audio
        # Fallback: non-streaming URL response.
        return await self._synthesize_via_url(
            text,
            voice_id,
            settings,
            speech_rate_delta=speech_rate_delta,
            loudness_rate=loudness_rate,
            ssml=ssml,
            model=model,
        )

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
        from app.services.provider_settings import resolve_speech_model

        resolved = (model or "").strip() or await resolve_speech_model("aliyun")
        resolved = resolved or "cosyvoice-v3-flash"
        body_text = ssml if ssml else text
        payload: dict[str, Any] = {
            "model": resolved,
            "input": {
                "text": body_text,
                "voice": voice_id,
                "format": "mp3",
                "sample_rate": 24000,
                "rate": _map_rate(settings, speech_rate_delta),
                "volume": _map_volume(loudness_rate),
            },
        }
        if ssml:
            payload["input"]["enable_ssml"] = True

        got_audio = False
        async with httpx.AsyncClient(timeout=180) as client:
            async with client.stream(
                "POST",
                _tts_url(),
                headers=_auth_headers(sse=True),
                json=payload,
            ) as resp:
                if resp.status_code >= 400:
                    err = (await resp.aread())[:800]
                    raise RuntimeError(f"Aliyun TTS failed {resp.status_code}: {err!r}")
                buf = ""
                async for piece in resp.aiter_text():
                    buf += piece
                    events, buf = _parse_sse_json_events(buf)
                    for obj in events:
                        code = obj.get("code")
                        if code not in (None, "", "Success", "success", 200):
                            msg = obj.get("message") or obj.get("code")
                            # Keep reading; some informational frames include codes.
                            if obj.get("output") is None and msg:
                                raise RuntimeError(f"Aliyun TTS error: {msg}")
                        b64 = _audio_b64_from_event(obj)
                        if b64:
                            got_audio = True
                            yield base64.b64decode(b64)
                if buf.strip():
                    events, _ = _parse_sse_json_events(buf + "\n\n")
                    for obj in events:
                        b64 = _audio_b64_from_event(obj)
                        if b64:
                            got_audio = True
                            yield base64.b64decode(b64)

        if not got_audio:
            # Non-SSE JSON body may have been returned despite header.
            audio = await self._synthesize_via_url(
                text,
                voice_id,
                settings,
                speech_rate_delta=speech_rate_delta,
                loudness_rate=loudness_rate,
                ssml=ssml,
                model=model,
            )
            if audio:
                yield audio

    async def _synthesize_via_url(
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
        from app.services.provider_settings import resolve_speech_model

        resolved = (model or "").strip() or await resolve_speech_model("aliyun")
        resolved = resolved or "cosyvoice-v3-flash"
        body_text = ssml if ssml else text
        payload: dict[str, Any] = {
            "model": resolved,
            "input": {
                "text": body_text,
                "voice": voice_id,
                "format": "mp3",
                "sample_rate": 24000,
                "rate": _map_rate(settings, speech_rate_delta),
                "volume": _map_volume(loudness_rate),
            },
        }
        if ssml:
            payload["input"]["enable_ssml"] = True

        async with httpx.AsyncClient(timeout=180) as client:
            resp = await client.post(
                _tts_url(),
                headers=_auth_headers(sse=False),
                json=payload,
            )
            if resp.status_code >= 400:
                raise RuntimeError(
                    f"Aliyun TTS failed {resp.status_code}: {resp.text[:800]}"
                )
            data = resp.json()
            output = data.get("output") if isinstance(data, dict) else None
            audio = output.get("audio") if isinstance(output, dict) else None
            url = audio.get("url") if isinstance(audio, dict) else None
            if not url:
                raise RuntimeError(f"Aliyun TTS returned no audio url: {data!r}"[:500])
            audio_resp = await client.get(str(url), timeout=120)
            if audio_resp.status_code >= 400:
                raise RuntimeError(
                    f"Aliyun TTS download failed {audio_resp.status_code}"
                )
            return audio_resp.content


class AliyunVoiceCloneProvider(VoiceCloneProvider):
    """Voice enrollment requires a publicly fetchable sample URL."""

    async def clone(self, name: str, audio_bytes: bytes, filename: str, language: str) -> str:
        from app.services.provider_settings import resolve_speech_model
        from app.services.storage import storage_service

        cfg = get_settings()
        _ = _api_key()  # fail fast
        target_model = (await resolve_speech_model("aliyun")) or (
            cfg.aliyun_tts_model or "cosyvoice-v3-flash"
        )
        ext = (filename.rsplit(".", 1)[-1] if "." in filename else "wav").lower()
        if ext not in ("wav", "mp3", "m4a", "aac", "ogg"):
            ext = "wav"
        content_type = {
            "wav": "audio/wav",
            "mp3": "audio/mpeg",
            "m4a": "audio/mp4",
            "aac": "audio/aac",
            "ogg": "audio/ogg",
        }.get(ext, "audio/wav")

        key = storage_service.new_key(f"ephemeral/aliyun-clone", f".{ext}")
        await storage_service.put_bytes(key, audio_bytes, content_type)
        try:
            url = await storage_service.presigned_url(key, expires=3600)
            if url.startswith("/"):
                raise RuntimeError(
                    "Aliyun voice clone needs a public audio URL; "
                    "use STORAGE_BACKEND=s3 with S3_PUBLIC_BASE_URL (or reachable presign)"
                )
            # Prefer absolute public base when relative path was somehow returned.
            if not url.startswith("http"):
                raise RuntimeError(f"Aliyun clone sample URL is not absolute: {url!r}")

            lang = "en" if (language or "").lower().startswith("en") else "zh"
            payload = {
                "model": "voice-enrollment",
                "input": {
                    "action": "create_voice",
                    "target_model": target_model,
                    "prefix": _safe_prefix(name),
                    "url": url,
                    "language_hints": [lang],
                },
            }
            async with httpx.AsyncClient(timeout=180) as client:
                resp = await client.post(
                    _customization_url(),
                    headers=_auth_headers(),
                    json=payload,
                )
                if resp.status_code >= 400:
                    raise RuntimeError(
                        f"Aliyun clone failed {resp.status_code}: {resp.text[:800]}"
                    )
                data = resp.json()
                output = data.get("output") if isinstance(data, dict) else None
                voice_id = output.get("voice_id") if isinstance(output, dict) else None
                if not voice_id:
                    raise RuntimeError(f"Aliyun clone returned no voice_id: {data!r}"[:500])
                return str(voice_id)
        finally:
            try:
                await storage_service.delete(key)
            except Exception:
                logger.warning("aliyun clone cleanup failed key=%s", key, exc_info=True)

    async def delete(self, provider_voice_id: str) -> None:
        if not provider_voice_id:
            return
        try:
            _api_key()
        except RuntimeError:
            return
        payload = {
            "model": "voice-enrollment",
            "input": {
                "action": "delete_voice",
                "voice_id": provider_voice_id,
            },
        }
        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.post(
                _customization_url(),
                headers=_auth_headers(),
                json=payload,
            )
            if resp.status_code not in (200, 204, 404):
                logger.warning(
                    "Aliyun delete voice %s → %s %s",
                    provider_voice_id,
                    resp.status_code,
                    resp.text[:200],
                )

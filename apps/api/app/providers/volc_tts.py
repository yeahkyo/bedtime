import base64
import json
import re
import uuid
from collections.abc import AsyncIterator

import httpx

from app.core.config import get_settings
from app.providers.base import TtsProvider, VoiceCloneProvider, VoiceSettings


class VolcTtsProvider(TtsProvider):
    """豆包语音合成 / 复刻音色合成（openspeech V3 unidirectional HTTP）。"""

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
        cfg = get_settings()
        api_key = cfg.volc_speech_api_key or cfg.ark_api_key
        if not api_key:
            raise RuntimeError("VOLC_SPEECH_API_KEY or ARK_API_KEY is not set")

        is_clone = voice_id.startswith("S_") or voice_id.startswith("custom_")
        resource = cfg.volc_icl_resource_id if is_clone else cfg.volc_tts_resource_id
        # Map ~0.7–1.15 product speeds to Volc speech_rate (-50..100 roughly; 0=default)
        speech_rate = int(max(-50, min(100, (settings.speed - 1.0) * 100 + speech_rate_delta)))
        loud = int(max(-50, min(100, loudness_rate)))

        headers = {
            "X-Api-Key": api_key,
            "X-Api-Resource-Id": resource,
            "X-Api-Request-Id": str(uuid.uuid4()),
            "Content-Type": "application/json",
            "Connection": "keep-alive",
        }
        audio_params: dict = {
            "format": "mp3",
            "sample_rate": 24000,
            "speech_rate": speech_rate,
        }
        if loud != 0:
            audio_params["loudness_rate"] = loud
        req_params: dict = {
            "speaker": voice_id,
            "audio_params": audio_params,
        }
        # SSML takes priority when provided (system voices / non-2.0 resources).
        if ssml:
            req_params["ssml"] = ssml
        else:
            req_params["text"] = text
        # ICL 2.0 cloned speakers need model_type=4 inside additions (JSON string).
        if is_clone and "icl-2" in resource:
            req_params["additions"] = json.dumps({"model_type": 4})
        payload = {"req_params": req_params}

        async with httpx.AsyncClient(timeout=180) as client:
            async with client.stream(
                "POST",
                "https://openspeech.bytedance.com/api/v3/tts/unidirectional",
                headers=headers,
                json=payload,
            ) as resp:
                resp.raise_for_status()
                async for line in resp.aiter_lines():
                    if not line:
                        continue
                    try:
                        obj = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    code = obj.get("code")
                    data = obj.get("data")
                    if code == 0 and data:
                        yield base64.b64decode(data)
                        continue
                    if code in (20000000, 20000001):
                        break
                    if isinstance(code, int) and code not in (0, 20000000, 20000001) and code != 0:
                        # Ignore subtitle-only frames (data null, low codes); raise real errors
                        msg = str(obj.get("message") or "")
                        if code >= 30000000 or "error" in msg.lower() or "fail" in msg.lower():
                            raise RuntimeError(f"Volc TTS error {code}: {msg or obj}")


class VolcVoiceCloneProvider(VoiceCloneProvider):
    async def clone(self, name: str, audio_bytes: bytes, filename: str, language: str) -> str:
        cfg = get_settings()
        api_key = cfg.volc_speech_api_key or cfg.ark_api_key
        if not api_key:
            raise RuntimeError("VOLC_SPEECH_API_KEY or ARK_API_KEY is not set")

        lang = 1 if language.lower().startswith("en") else 0
        ext = (filename.rsplit(".", 1)[-1] if "." in filename else "wav").lower()
        if ext == "m4a":
            fmt = "m4a"
        elif ext in ("mp3", "wav", "ogg", "aac", "pcm"):
            fmt = ext
        else:
            fmt = "wav"

        custom_id = _safe_custom_speaker_id(name)
        body = {
            "speaker_id": "custom_speaker_id",
            "custom_speaker_id": custom_id,
            "audio": {
                "data": base64.b64encode(audio_bytes).decode(),
                "format": fmt,
            },
            "language": lang,
            # Keep as object (official examples); some SDKs stringify — both accepted.
            "extra_params": {
                "enable_audio_denoise": True,
            },
        }
        headers = {
            "Content-Type": "application/json",
            "X-Api-Key": api_key,
            "X-Api-Resource-Id": cfg.volc_icl_resource_id,
            "X-Api-Request-Id": str(uuid.uuid4()),
        }
        async with httpx.AsyncClient(timeout=180) as client:
            resp = await client.post(
                "https://openspeech.bytedance.com/api/v3/tts/voice_clone",
                headers=headers,
                json=body,
            )
            if resp.status_code >= 400:
                raise RuntimeError(f"Volc clone failed {resp.status_code}: {resp.text[:500]}")
            data = resp.json()
            status = data.get("status")
            # Postpaid custom ids often echo custom_speaker_id; prepaid returns S_*.
            speaker = data.get("speaker_id") or custom_id
            if speaker == "custom_speaker_id":
                speaker = custom_id
            if status not in (2, 4, None):
                # 1 = training — still return id; synthesis may work when Active
                if status == 1:
                    return speaker
                raise RuntimeError(f"Volc clone status={status}: {data}")
            return speaker

    async def delete(self, provider_voice_id: str) -> None:
        # Console/API delete varies by account plan; best-effort no-op for MVP.
        return None


def _safe_custom_speaker_id(name: str) -> str:
    slug = re.sub(r"[^a-zA-Z0-9_-]", "", name) or "voice"
    slug = slug.strip("-_")
    if not slug or not slug[0].isalpha():
        slug = "voice" + slug
    base = f"custom_{slug}_{uuid.uuid4().hex[:8]}"
    if len(base) < 8:
        base = (base + "xxxxxxxx")[:8]
    return base[:256]

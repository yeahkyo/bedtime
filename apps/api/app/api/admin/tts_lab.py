"""Admin TTS lab: paste body, pick voice + prosody mode, prepare and/or synthesize."""

from __future__ import annotations

import base64
import logging

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import require_admin
from app.models.voice import Voice
from app.providers.factory import get_tts_provider
from app.services.narration_prosody import (
    normalize_prosody_mode,
    prepare_narration,
    synthesize_with_prosody,
)
from app.services.provider_settings import resolve_speech_model
from app.services.errors import safe_error_message
from app.services.voice_settings import clamp_speed, resolve_voice_settings

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/tts-lab", tags=["admin-tts-lab"])

_TEXT_MAX = 20_000
_PROSODY_CHOICES = ("auto", "fish_break", "punct", "none")


class TtsLabPrepareIn(BaseModel):
    text: str = Field(..., min_length=1, max_length=_TEXT_MAX)
    voice_id: int | None = None
    provider: str | None = None
    provider_voice_id: str | None = None
    speech_model: str | None = None
    prosody: str = "auto"


class TtsLabPrepareOut(BaseModel):
    display: str
    speak_text: str
    ssml: str | None
    used_ssml: bool
    prosody_mode: str
    provider: str | None
    model: str | None
    voice_id: int | None = None
    voice_name: str | None = None


class TtsLabSynthesizeIn(TtsLabPrepareIn):
    speed: float | None = Field(default=None, ge=0.5, le=2.0)


class TtsLabSynthesizeOut(TtsLabPrepareOut):
    audio_base64: str
    audio_content_type: str = "audio/mpeg"
    audio_bytes: int


async def _resolve_voice_context(
    db: AsyncSession,
    *,
    voice_id: int | None,
    provider: str | None,
    provider_voice_id: str | None,
    speech_model: str | None,
) -> tuple[str, str, str | None, int | None, str | None]:
    """Return (provider, provider_voice_id, speech_model, catalog_id, voice_name)."""
    catalog_id: int | None = None
    voice_name: str | None = None
    if voice_id is not None:
        voice = await db.get(Voice, voice_id)
        if voice is None:
            raise HTTPException(status_code=404, detail="Voice not found")
        catalog_id = voice.id
        voice_name = voice.name
        name = (provider or voice.provider or "").strip().lower()
        ref = (provider_voice_id or voice.provider_voice_id or "").strip()
        model = (speech_model if speech_model is not None else voice.speech_model) or None
        model = (model or "").strip() or None
    else:
        name = (provider or "").strip().lower()
        ref = (provider_voice_id or "").strip()
        model = (speech_model or "").strip() or None
    if not name:
        raise HTTPException(status_code=400, detail="provider or voice_id is required")
    if not ref:
        raise HTTPException(status_code=400, detail="provider_voice_id is required")
    return name, ref, model, catalog_id, voice_name


@router.post("/prepare", response_model=TtsLabPrepareOut)
async def tts_lab_prepare(
    body: TtsLabPrepareIn,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> TtsLabPrepareOut:
    text = (body.text or "").strip()
    if not text:
        raise HTTPException(status_code=400, detail="text is required")
    raw_mode = (body.prosody or "auto").strip().lower().replace("-", "_")
    if raw_mode not in _PROSODY_CHOICES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid prosody; expected one of {', '.join(_PROSODY_CHOICES)}",
        )
    mode = normalize_prosody_mode(raw_mode)

    name, ref, model, catalog_id, voice_name = await _resolve_voice_context(
        db,
        voice_id=body.voice_id,
        provider=body.provider,
        provider_voice_id=body.provider_voice_id,
        speech_model=body.speech_model,
    )
    resolved_model = await resolve_speech_model(name, voice_model=model)
    prepared = prepare_narration(
        text,
        voice_id=ref,
        speech_provider=name,
        prosody_mode=mode,
    )
    used_ssml = bool(prepared.ssml)
    return TtsLabPrepareOut(
        display=prepared.display or "",
        speak_text=prepared.speak_text or "",
        ssml=prepared.ssml if used_ssml else None,
        used_ssml=used_ssml,
        prosody_mode=prepared.prosody_mode,
        provider=name,
        model=resolved_model or model,
        voice_id=catalog_id,
        voice_name=voice_name,
    )


@router.post("/synthesize", response_model=TtsLabSynthesizeOut)
async def tts_lab_synthesize(
    body: TtsLabSynthesizeIn,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> TtsLabSynthesizeOut:
    text = (body.text or "").strip()
    if not text:
        raise HTTPException(status_code=400, detail="text is required")
    mode = normalize_prosody_mode(body.prosody)
    raw_mode = (body.prosody or "auto").strip().lower().replace("-", "_")
    if raw_mode and raw_mode not in _PROSODY_CHOICES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid prosody; expected one of {', '.join(_PROSODY_CHOICES)}",
        )

    name, ref, model, catalog_id, voice_name = await _resolve_voice_context(
        db,
        voice_id=body.voice_id,
        provider=body.provider,
        provider_voice_id=body.provider_voice_id,
        speech_model=body.speech_model,
    )
    resolved_model = await resolve_speech_model(name, voice_model=model)
    vs = resolve_voice_settings(speed=clamp_speed(body.speed if body.speed is not None else 1.0))
    tts = get_tts_provider(name)
    try:
        synth = await synthesize_with_prosody(
            tts,
            text,
            ref,
            vs,
            speech_provider=name,
            model=resolved_model or model,
            prosody_mode=mode,
        )
    except Exception as exc:
        logger.exception("tts-lab synthesize failed provider=%s voice=%s", name, ref)
        raise HTTPException(
            status_code=502,
            detail=safe_error_message(exc, fallback="TTS lab synthesize failed"),
        ) from exc
    if not synth.audio:
        raise HTTPException(status_code=502, detail="TTS returned empty audio")

    return TtsLabSynthesizeOut(
        display=synth.display or "",
        speak_text=synth.speak_text or "",
        ssml=synth.ssml if synth.used_ssml else None,
        used_ssml=synth.used_ssml,
        prosody_mode=synth.prosody_mode,
        provider=name,
        model=resolved_model or model,
        voice_id=catalog_id,
        voice_name=voice_name,
        audio_base64=base64.b64encode(synth.audio).decode("ascii"),
        audio_bytes=len(synth.audio),
    )

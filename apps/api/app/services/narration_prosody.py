"""Bedtime narration prosody: segment body → provider-specific pauses (SSML / Fish / punct)."""

from __future__ import annotations

import html
import logging
import re
from dataclasses import dataclass
from typing import Literal

from app.core.config import get_settings
from app.providers.base import TtsProvider, VoiceSettings

logger = logging.getLogger(__name__)

PauseKind = Literal["short", "think", "long"]

# Legacy LLM / heuristic markers still stripped from display + input.
MARKER_RE = re.compile(
    r"\[(pause:(?:short|think|long)|slow|soft|warm)\]",
    re.IGNORECASE,
)
# Fish S2 pause tags — never show in display if they leaked into body.
FISH_BREAK_RE = re.compile(
    r"\[(?:long-)?break\]|\[(?:short|long)\s+pause\]",
    re.IGNORECASE,
)

PAUSE_MS: dict[PauseKind, int] = {
    "short": 150,
    "think": 500,
    "long": 1200,
}

PAUSE_PUNCT: dict[PauseKind, str] = {
    "short": "……",
    "think": "……\n\n",
    "long": "……\n\n",
}

FISH_PAUSE: dict[PauseKind, str] = {
    "short": "[break]",
    "think": "[long-break]",
    "long": "[long-break]",
}

_ALIYUN_PROVIDERS = frozenset({"aliyun", "dashscope", "cosyvoice"})


@dataclass
class PreparedNarration:
    display: str
    speak_text: str
    ssml: str | None
    speech_rate_delta: int = 0
    loudness_rate: int = 0


@dataclass(frozen=True)
class _Seg:
    """One sentence plus the pause to emit after it (None = none)."""

    text: str
    after: PauseKind | None


def strip_performance_markers(text: str) -> str:
    cleaned = MARKER_RE.sub("", text or "")
    cleaned = FISH_BREAK_RE.sub("", cleaned)
    cleaned = re.sub(r"[ \t]{2,}", " ", cleaned)
    cleaned = re.sub(r" *\n *", "\n", cleaned)
    cleaned = re.sub(r"\n{3,}", "\n\n", cleaned)
    return cleaned.strip()


def _split_paragraphs(body: str) -> list[str]:
    return [p.strip() for p in re.split(r"\n\s*\n", body or "") if p.strip()]


def _split_sentences(para: str) -> list[str]:
    parts = re.findall(r"[^。！？!?]+[。！？!?]?", para, flags=re.S)
    return [p.strip() for p in parts if p.strip()]


def _content_len(sent: str) -> int:
    """Rough glyph count without trailing sentence punctuation."""
    return len(re.sub(r"[。！？!?\s]+$", "", sent or ""))


def build_pause_segments(body: str) -> list[_Seg]:
    """
    Paragraph/sentence segmentation with bedtime pause plan:
    - short after non-final sentences in a paragraph
    - think between paragraphs
    - long after the final sentence
    Skip short pause after very short utterances (≤2 chars).
    """
    display = strip_performance_markers(body)
    paragraphs = _split_paragraphs(display)
    if not paragraphs:
        return []

    segs: list[_Seg] = []
    for pi, para in enumerate(paragraphs):
        sentences = _split_sentences(para)
        if not sentences:
            continue
        last_para = pi == len(paragraphs) - 1
        for si, sent in enumerate(sentences):
            last_sent = si == len(sentences) - 1
            after: PauseKind | None
            if last_para and last_sent:
                after = "long"
            elif last_sent:
                after = "think"
            elif _content_len(sent) <= 2:
                after = None
            else:
                after = "short"
            segs.append(_Seg(text=sent, after=after))
    return segs


def render_ssml_breaks(segs: list[_Seg]) -> str:
    parts: list[str] = ["<speak>"]
    for seg in segs:
        parts.append(html.escape(seg.text, quote=False))
        if seg.after:
            ms = PAUSE_MS[seg.after]
            parts.append(f'<break time="{ms}ms"/>')
    parts.append("</speak>")
    return "".join(parts)


def render_fish_breaks(segs: list[_Seg]) -> str:
    parts: list[str] = []
    for i, seg in enumerate(segs):
        parts.append(seg.text)
        if not seg.after:
            continue
        parts.append(FISH_PAUSE[seg.after])
        # Keep paragraph readability for models that treat newlines as breath.
        if seg.after in ("think", "long") and i < len(segs) - 1:
            parts.append("\n\n")
    return "".join(parts).strip()


def render_punct_breaths(segs: list[_Seg]) -> str:
    parts: list[str] = []
    for seg in segs:
        parts.append(seg.text)
        if seg.after:
            parts.append(PAUSE_PUNCT[seg.after])
    spoken = "".join(parts)
    spoken = re.sub(r"[ \t]{2,}", " ", spoken)
    spoken = re.sub(r"\n{3,}", "\n\n", spoken)
    return spoken.strip()


def plain_text_from_segments(segs: list[_Seg]) -> str:
    """Display / plain speak without pause syntax; restore paragraph gaps."""
    if not segs:
        return ""
    # Rebuild paragraphs: think/long after a seg means next seg starts a new para.
    paras: list[list[str]] = [[]]
    for seg in segs:
        paras[-1].append(seg.text)
        if seg.after in ("think", "long"):
            paras.append([])
    while paras and not paras[-1]:
        paras.pop()
    return "\n\n".join("".join(p) for p in paras if p).strip()


def is_clone_voice(voice_id: str) -> bool:
    return voice_id.startswith("S_") or voice_id.startswith("custom_")


def normalize_speech_provider(speech_provider: str | None) -> str:
    return (speech_provider or "").strip().lower()


def voice_supports_ssml(
    voice_id: str,
    *,
    speech_provider: str | None = None,
) -> bool:
    """
    Aliyun CosyVoice: prefer SSML breaks (provider sets enable_ssml).
    Volc: system voices only when resource/flag allows (not seed-tts-2.0 / icl by default).
    Fish / ElevenLabs / mock → False (Fish uses bracket breaks instead).
    """
    provider = normalize_speech_provider(speech_provider)
    if provider in _ALIYUN_PROVIDERS:
        return True

    if provider and provider != "volc":
        return False
    if is_clone_voice(voice_id):
        return False
    cfg = get_settings()
    if cfg.volc_tts_enable_ssml:
        return True
    resource = (cfg.volc_tts_resource_id or "").lower()
    if "2.0" in resource or "icl" in resource:
        return False
    return provider == "volc" or not provider


def prepare_narration(
    body: str,
    *,
    voice_id: str = "",
    speech_provider: str | None = None,
) -> PreparedNarration:
    """Clean display + provider-specific speak_text / ssml with sentence/paragraph pauses."""
    display = strip_performance_markers(body)
    segs = build_pause_segments(display)
    if not segs:
        return PreparedNarration(display="", speak_text="", ssml=None)

    plain = plain_text_from_segments(segs) or display
    provider = normalize_speech_provider(speech_provider)

    ssml: str | None = None
    speak: str

    if provider in _ALIYUN_PROVIDERS or (
        voice_id and voice_supports_ssml(voice_id, speech_provider=speech_provider)
    ):
        ssml = render_ssml_breaks(segs)
        speak = plain
    elif provider in ("fishaudio", "fish"):
        speak = render_fish_breaks(segs)
    else:
        # Volc without SSML, elevenlabs, mock, unknown → punctuation breaths.
        speak = render_punct_breaths(segs)

    return PreparedNarration(
        display=display,
        speak_text=speak or plain,
        ssml=ssml,
        speech_rate_delta=0,
        loudness_rate=0,
    )


async def synthesize_with_prosody(
    tts: TtsProvider,
    text: str,
    voice_id: str,
    settings: VoiceSettings,
    *,
    speech_provider: str | None = None,
    model: str | None = None,
) -> tuple[bytes, str]:
    """
    Single TTS call with provider pauses (SSML / Fish brackets / punct).
    Returns (audio_mp3, display_body without control tags).
    """
    prepared = prepare_narration(
        text, voice_id=voice_id, speech_provider=speech_provider
    )
    display = prepared.display or strip_performance_markers(text)

    if prepared.ssml:
        try:
            audio = await tts.synthesize(
                prepared.speak_text or display,
                voice_id,
                settings,
                speech_rate_delta=prepared.speech_rate_delta,
                loudness_rate=prepared.loudness_rate,
                ssml=prepared.ssml,
                model=model,
            )
            return audio, display
        except Exception as exc:
            logger.warning("SSML synthesize failed, falling back to plain: %s", exc)

    # Plain fallback: prefer punct breaths if SSML path failed but we only had SSML.
    speak = prepared.speak_text or display or text
    if prepared.ssml:
        segs = build_pause_segments(display)
        if segs:
            speak = render_punct_breaths(segs)

    audio = await tts.synthesize(
        speak,
        voice_id,
        settings,
        speech_rate_delta=prepared.speech_rate_delta,
        loudness_rate=prepared.loudness_rate,
        model=model,
    )
    return audio, display

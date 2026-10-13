"""Bedtime narration prosody via LLM markers → TTS SSML / punctuation (no local audio mix)."""

from __future__ import annotations

import html
import logging
import re
from dataclasses import dataclass

from app.core.config import get_settings
from app.providers.base import TtsProvider, VoiceSettings

logger = logging.getLogger(__name__)

MARKER_RE = re.compile(
    r"\[(pause:(?:short|think|long)|slow|soft|warm)\]",
    re.IGNORECASE,
)

PAUSE_MS = {
    "short": 400,
    "think": 900,
    "long": 1200,
}

# Punctuation breaths when SSML is unavailable (clone / TTS 2.0).
PAUSE_PUNCT = {
    "short": "……",
    "think": "……\n\n",
    "long": "……\n\n",
}


@dataclass
class PreparedNarration:
    display: str
    speak_text: str
    ssml: str | None
    speech_rate_delta: int = 0
    loudness_rate: int = 0


def strip_performance_markers(text: str) -> str:
    cleaned = MARKER_RE.sub("", text or "")
    cleaned = re.sub(r"[ \t]{2,}", " ", cleaned)
    cleaned = re.sub(r" *\n *", "\n", cleaned)
    cleaned = re.sub(r"\n{3,}", "\n\n", cleaned)
    return cleaned.strip()


def apply_performance_heuristics(text: str) -> str:
    """Insert sparse markers when the model didn't. Trust existing markers if present."""
    raw = (text or "").strip()
    if not raw:
        return raw
    if MARKER_RE.search(raw):
        if raw.count("[") > 16:
            return _sparse_fallback(
                [p.strip() for p in re.split(r"\n\s*\n", strip_performance_markers(raw)) if p.strip()]
            )
        return raw

    body = strip_performance_markers(raw)
    paragraphs = [p.strip() for p in re.split(r"\n\s*\n", body) if p.strip()]
    if not paragraphs:
        return body

    out_paras: list[str] = []
    for pi, para in enumerate(paragraphs):
        sentences = _split_sentences(para)
        built: list[str] = []
        for si, sent in enumerate(sentences):
            prefix = ""
            if re.match(r"^(可是|后来|这下|于是|忽然|最后|然后)", sent):
                prefix += "[pause:short]"
            if re.search(r"(轻轻|慢慢|悄悄|闭上|睡着|眼皮|晚安|梦里|呼吸)", sent):
                prefix += "[soft][slow]"
            if pi == 0 and si == len(sentences) - 1 and len(paragraphs) > 1:
                built.append(f"{prefix}{sent}[pause:think]")
            elif pi == len(paragraphs) - 1 and si == len(sentences) - 1:
                built.append(f"{prefix or '[soft][slow]'}{sent}[pause:long]")
            else:
                built.append(f"{prefix}{sent}")
        joined = "".join(built)
        if pi < len(paragraphs) - 1 and "[pause:" not in joined[-24:]:
            joined += "[pause:short]"
        out_paras.append(joined)

    marked = "\n\n".join(out_paras)
    if marked.count("[") > 14:
        return _sparse_fallback(paragraphs)
    return marked


def _sparse_fallback(paragraphs: list[str]) -> str:
    out: list[str] = []
    for i, p in enumerate(paragraphs):
        if i == 0 and len(paragraphs) > 1:
            out.append(p.rstrip() + "[pause:think]")
        elif i == len(paragraphs) - 1:
            out.append("[soft][slow]" + p.rstrip() + "[pause:long]")
        else:
            out.append(p.rstrip() + "[pause:short]")
    return "\n\n".join(out)


def _split_sentences(para: str) -> list[str]:
    parts = re.findall(r"[^。！？!?]+[。！？!?]?", para, flags=re.S)
    return [p.strip() for p in parts if p.strip()]


def is_clone_voice(voice_id: str) -> bool:
    return voice_id.startswith("S_") or voice_id.startswith("custom_")


def voice_supports_ssml(voice_id: str) -> bool:
    """
    Volc docs: seed-tts-2.0 / seed-icl-2.0 currently do not take SSML.
    Enable with VOLC_TTS_ENABLE_SSML=1 for system voices when the resource supports it.
    """
    if is_clone_voice(voice_id):
        return False
    cfg = get_settings()
    if cfg.volc_tts_enable_ssml:
        return True
    resource = (cfg.volc_tts_resource_id or "").lower()
    if "2.0" in resource or "icl" in resource:
        return False
    return True


def _style_deltas(marked: str) -> tuple[int, int]:
    """
    Global rate/loudness nudges for plain TTS.

    Do NOT apply whole-utterance slow here: user speed_tier already sets speech_rate,
    and stacking [slow]→-18 made bedtime stories drag. Local soft/slow belongs in
    SSML <prosody> when enabled; otherwise markers only affect punctuation pauses.
    """
    _ = marked
    return 0, 0


def markers_to_punctuated_text(marked: str) -> str:
    """Map performance markers to spoken punctuation / line breaks (plain TTS)."""
    text = marked or ""
    pos = 0
    out: list[str] = []
    for m in MARKER_RE.finditer(text):
        out.append(text[pos : m.start()])
        tag = m.group(1).lower()
        pos = m.end()
        if tag.startswith("pause:"):
            kind = tag.split(":", 1)[1]
            prev = out[-1] if out else ""
            prev_r = prev.rstrip()
            if kind in ("think", "long"):
                # Soften a hard stop into a lingering breath the TTS usually holds longer.
                if prev_r.endswith(("。", "！", "？", ".", "!", "?")):
                    out[-1] = prev_r[:-1] + "……\n\n"
                elif prev_r.endswith(("…", "……")):
                    out.append("\n\n")
                else:
                    out.append(PAUSE_PUNCT[kind])
            else:  # short
                if not prev_r or prev_r.endswith(("。", "！", "？", ".", "!", "?", "…", "……")):
                    # Already have a breath (or paragraph gap); don't stack another ellipsis.
                    if not prev.endswith("\n"):
                        out.append("\n")
                else:
                    out.append(PAUSE_PUNCT["short"])
        # slow/soft/warm → omitted in plain text (handled via audio_params deltas)
    out.append(text[pos:])
    spoken = "".join(out)
    spoken = re.sub(r"[ \t]{2,}", " ", spoken)
    spoken = re.sub(r"\n{3,}", "\n\n", spoken)
    return spoken.strip()


def markers_to_ssml(marked: str) -> str:
    """Map markers to Volc-style SSML (<break> + optional <prosody>)."""
    text = marked or ""
    pos = 0
    parts: list[str] = ["<speak>"]
    open_prosody: str | None = None

    def close_prosody() -> None:
        nonlocal open_prosody
        if open_prosody:
            parts.append("</prosody>")
            open_prosody = None

    def open_style(rate: bool, soft: bool, warm: bool) -> None:
        nonlocal open_prosody
        close_prosody()
        attrs: list[str] = []
        if rate or warm:
            attrs.append('rate="slow"')
        if soft or warm:
            attrs.append('volume="soft"')
        if attrs:
            open_prosody = " ".join(attrs)
            parts.append(f"<prosody {open_prosody}>")

    pending_slow = False
    pending_soft = False
    pending_warm = False

    for m in MARKER_RE.finditer(text):
        chunk = text[pos : m.start()]
        if chunk:
            if pending_slow or pending_soft or pending_warm:
                open_style(pending_slow, pending_soft, pending_warm)
                pending_slow = pending_soft = pending_warm = False
            parts.append(html.escape(chunk, quote=False))
        tag = m.group(1).lower()
        pos = m.end()
        if tag.startswith("pause:"):
            close_prosody()
            kind = tag.split(":", 1)[1]
            ms = PAUSE_MS.get(kind, PAUSE_MS["short"])
            parts.append(f'<break time="{ms}ms"/>')
        elif tag == "slow":
            pending_slow = True
        elif tag == "soft":
            pending_soft = True
        elif tag == "warm":
            pending_warm = True

    tail = text[pos:]
    if tail:
        if pending_slow or pending_soft or pending_warm:
            open_style(pending_slow, pending_soft, pending_warm)
        parts.append(html.escape(tail, quote=False))
    close_prosody()
    parts.append("</speak>")
    return "".join(parts)


def prepare_narration(body: str, *, voice_id: str = "") -> PreparedNarration:
    """Build display text + TTS payload (SSML when supported, else punctuated plain)."""
    marked = apply_performance_heuristics(body)
    display = strip_performance_markers(marked)
    rate, loud = _style_deltas(marked)
    speak = markers_to_punctuated_text(marked) or display
    ssml = None
    if voice_id and voice_supports_ssml(voice_id):
        ssml = markers_to_ssml(marked)
        # Mid-phrase prosody is in SSML; keep mild global nudge only if styles present.
    return PreparedNarration(
        display=display,
        speak_text=speak,
        ssml=ssml,
        speech_rate_delta=rate,
        loudness_rate=loud,
    )


async def synthesize_with_prosody(
    tts: TtsProvider,
    text: str,
    voice_id: str,
    settings: VoiceSettings,
) -> tuple[bytes, str]:
    """
    Single TTS call with SSML breaks (system, non-2.0) or punctuation breaths.
    Returns (audio_mp3, display_body without markers).
    """
    prepared = prepare_narration(text, voice_id=voice_id)
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
            )
            return audio, display
        except Exception as exc:
            logger.warning("SSML synthesize failed, falling back to plain: %s", exc)

    audio = await tts.synthesize(
        prepared.speak_text or display or text,
        voice_id,
        settings,
        speech_rate_delta=prepared.speech_rate_delta,
        loudness_rate=prepared.loudness_rate,
    )
    return audio, display

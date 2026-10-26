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
# auto = pick by speech_provider; others force a render path (admin TTS lab).
ProsodyMode = Literal["auto", "fish_break", "punct", "none"]

# Legacy LLM / heuristic markers still stripped from display + input.
MARKER_RE = re.compile(
    r"\[(pause:(?:short|think|long)|slow|soft|warm)\]",
    re.IGNORECASE,
)
# Fish S2 pause tags — never show in display if they leaked into body.
FISH_BREAK_RE = re.compile(
    r"\[(?:long-)?break\]|"
    r"\[(?:short|long)\s+pause\]|"
    r"\[pause\]",
    re.IGNORECASE,
)

# Collapse 。…… / 。！ / ？。 etc. so we don't emit orphan punct segments + stacked pauses.
_MULTI_TERMINATOR_RE = re.compile(r"([。！？!?])[。！？!?…⋯.]+")
# Closing quotes / brackets that belong after 。！？ (Chinese dialogue: 。” / ！”).
_TRAILING_CLOSER_CLASS = "”’』」\"'）)》"
_PUNCT_ONLY_RE = re.compile(rf"^[。！？!?…⋯.\s　{_TRAILING_CLOSER_CLASS}]+$")
# One sentence: body + optional terminator + optional trailing closers.
_SENTENCE_RE = re.compile(
    rf"[^。！？!?]+[。！？!?]?(?:[{_TRAILING_CLOSER_CLASS}])*",
    re.S,
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

# Fish S2 bracket pause cues (sentence / paragraph).
FISH_PAUSE: dict[PauseKind, str] = {
    "short": "[break]",
    "think": "[long-break]",
    "long": "[long-break]",
}

_ALIYUN_PROVIDERS = frozenset({"aliyun", "dashscope", "cosyvoice"})
_FISH_PROVIDERS = frozenset({"fishaudio", "fish"})

# CosyVoice often misreads these (e.g. —— → "mashen") or treats them as spoken names.
_ZERO_WIDTH_RE = re.compile(r"[\u200b\u200c\u200d\ufeff\u2060]")
_DASH_PAUSE_RE = re.compile(r"(?:——|──|—|–|―)+")
_DECORATIVE_RE = re.compile(r"[~～·•●★☆※→←⇒]+")
_EMOJI_RE = re.compile(
    "["
    "\U0001F300-\U0001FAFF"
    "\U00002700-\U000027BF"
    "\U0001F1E0-\U0001F1FF"
    "]+",
)
_ASCII_ELLIPSIS_RE = re.compile(r"\.{3,}")
# Keep parenthetical content; turn brackets into comma breaths (open-source CosyVoice
# strips （）【】 entirely — we keep words and preserve a pause).
_PAREN_RE = re.compile(r"[（(]([^）)]*)[）)]")
_BRACKET_RE = re.compile(r"[【\[]([^】\]]*)[】\]]")
_MULTI_COMMA_RE = re.compile(r"[，,]{2,}")
_COMMA_BEFORE_END_RE = re.compile(r"，+([。！？!?…])")
_COMMA_AFTER_OPEN_QUOTE_RE = re.compile(r"([“\"'])，+")


def sanitize_for_cosyvoice(text: str) -> str:
    """
    Speak-only cleanup for Aliyun CosyVoice.

    Replace misread symbols with Chinese commas so the model still breathes;
    strip zero-width / emoji junk. Display body should stay unsanitized.
    """
    s = text or ""
    if not s:
        return ""
    s = _ZERO_WIDTH_RE.sub("", s)
    s = s.replace("\xa0", " ")
    # Em dash / box-drawing runs → comma pause (not silence-delete).
    s = _DASH_PAUSE_RE.sub("，", s)
    s = _ASCII_ELLIPSIS_RE.sub("……", s)
    s = _DECORATIVE_RE.sub("，", s)
    s = _EMOJI_RE.sub("", s)
    # ASCII punctuation CosyVoice may name aloud in Chinese prose.
    s = s.replace("&", "，")
    s = s.replace("@", "，")
    s = s.replace("#", "，")
    s = s.replace("*", "，")
    s = s.replace("/", "，")
    s = s.replace("\\", "，")
    s = _PAREN_RE.sub(r"，\1，", s)
    s = _BRACKET_RE.sub(r"，\1，", s)
    # Mid-CJK ASCII period → Chinese full stop (avoid reading 「点」).
    s = re.sub(r"(?<=[\u4e00-\u9fff])\.(?=[\u4e00-\u9fff])", "。", s)
    s = _MULTI_COMMA_RE.sub("，", s)
    s = _COMMA_BEFORE_END_RE.sub(r"\1", s)
    s = _COMMA_AFTER_OPEN_QUOTE_RE.sub(r"\1", s)
    s = re.sub(r"(^|\n)[，,]+", r"\1", s)
    s = re.sub(r"[，,]+($|\n)", r"\1", s)
    s = re.sub(r"[ \t]{2,}", " ", s)
    s = re.sub(r"\n{3,}", "\n\n", s)
    return s.strip()


@dataclass
class PreparedNarration:
    display: str
    speak_text: str
    ssml: str | None
    speech_rate_delta: int = 0
    loudness_rate: int = 0
    prosody_mode: str = "auto"


@dataclass
class SynthesizeWithProsodyResult:
    """Audio plus the exact TTS payload used (admin lab / debugging)."""

    audio: bytes
    display: str
    speak_text: str
    ssml: str | None
    used_ssml: bool
    prosody_mode: str = "auto"


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
    """
    Split on 。！？!? after collapsing stacked terminators / ellipsis.

    Trailing closers (。” / ！”) stay on the same sentence so Fish does not get
    `。[break]”[long-break]` (quote sandwiched between two pause tags).

    Without collapse, `说完了。……` becomes two segs → stacked pauses / fillers.
    """
    cleaned = _MULTI_TERMINATOR_RE.sub(r"\1", para or "")
    parts = _SENTENCE_RE.findall(cleaned)
    out: list[str] = []
    for raw in parts:
        sent = raw.strip()
        if not sent or _PUNCT_ONLY_RE.match(sent):
            continue
        out.append(sent)
    return out


def _content_len(sent: str) -> int:
    """Rough glyph count without trailing sentence punctuation / closers."""
    return len(re.sub(rf"[。！？!?\s{_TRAILING_CLOSER_CLASS}]+$", "", sent or ""))


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
    """
    Inject Fish `[break]` / `[long-break]` between sentences.

    No extra blank lines after tags: paragraph gaps are already encoded by
    think/long pause kind; stacking `\\n\\n` on top encouraged filler sounds.
    """
    parts: list[str] = []
    last_was_pause = False
    for seg in segs:
        text = seg.text or ""
        if text:
            parts.append(text)
            last_was_pause = False
        if not seg.after:
            continue
        # Never emit two pause tags back-to-back (punct-only segs / empty text).
        if last_was_pause:
            # Keep the stronger pause (think/long over short).
            if seg.after in ("think", "long") and parts:
                prev = parts[-1]
                if prev == FISH_PAUSE["short"]:
                    parts[-1] = FISH_PAUSE[seg.after]
            continue
        parts.append(FISH_PAUSE[seg.after])
        last_was_pause = True
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


def normalize_prosody_mode(mode: str | None) -> ProsodyMode:
    raw = (mode or "auto").strip().lower().replace("-", "_")
    # fish_pause was a short-lived A/B; treat as fish_break.
    if raw == "fish_pause":
        return "fish_break"
    if raw in ("auto", "fish_break", "punct", "none"):
        return raw  # type: ignore[return-value]
    return "auto"


def voice_supports_ssml(
    voice_id: str,
    *,
    speech_provider: str | None = None,
) -> bool:
    """
    Aliyun CosyVoice: prefer SSML breaks (provider sets enable_ssml).
    Volc: system voices only when resource/flag allows (not seed-tts-2.0 / icl by default).
    Fish / ElevenLabs / mock → False (Fish uses bracket pauses instead).
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
    prosody_mode: str | None = None,
) -> PreparedNarration:
    """Clean display + provider-specific speak_text / ssml with sentence/paragraph pauses."""
    display = strip_performance_markers(body)
    mode = normalize_prosody_mode(prosody_mode)
    provider = normalize_speech_provider(speech_provider)

    # CosyVoice: sanitize speak source (keep display with original —— etc.).
    speak_source = display
    if provider in _ALIYUN_PROVIDERS:
        speak_source = sanitize_for_cosyvoice(display)

    segs = build_pause_segments(speak_source)
    if not segs:
        return PreparedNarration(
            display=display if display else "",
            speak_text="",
            ssml=None,
            prosody_mode=mode,
        )

    plain = plain_text_from_segments(segs) or speak_source

    ssml: str | None = None
    speak: str

    if mode == "none":
        speak = plain
    elif mode == "punct":
        speak = render_punct_breaths(segs)
    elif mode == "fish_break":
        speak = render_fish_breaks(segs)
    elif provider in _ALIYUN_PROVIDERS or (
        voice_id and voice_supports_ssml(voice_id, speech_provider=speech_provider)
    ):
        ssml = render_ssml_breaks(segs)
        speak = plain
    elif provider in _FISH_PROVIDERS:
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
        prosody_mode=mode,
    )


async def synthesize_with_prosody(
    tts: TtsProvider,
    text: str,
    voice_id: str,
    settings: VoiceSettings,
    *,
    speech_provider: str | None = None,
    model: str | None = None,
    prosody_mode: str | None = None,
) -> SynthesizeWithProsodyResult:
    """
    Single TTS call with provider pauses (SSML / Fish brackets / punct).
    Returns audio, display body, and the exact speak_text / ssml sent to TTS.
    """
    prepared = prepare_narration(
        text,
        voice_id=voice_id,
        speech_provider=speech_provider,
        prosody_mode=prosody_mode,
    )
    display = prepared.display or strip_performance_markers(text)
    mode = prepared.prosody_mode

    if prepared.ssml:
        speak = prepared.speak_text or display
        try:
            audio = await tts.synthesize(
                speak,
                voice_id,
                settings,
                speech_rate_delta=prepared.speech_rate_delta,
                loudness_rate=prepared.loudness_rate,
                ssml=prepared.ssml,
                model=model,
            )
            return SynthesizeWithProsodyResult(
                audio=audio,
                display=display,
                speak_text=speak,
                ssml=prepared.ssml,
                used_ssml=True,
                prosody_mode=mode,
            )
        except Exception as exc:
            logger.warning("SSML synthesize failed, falling back to plain: %s", exc)

    # Plain fallback: prefer punct breaths if SSML path failed but we only had SSML.
    speak = prepared.speak_text or display or text
    if prepared.ssml:
        # Must reuse CosyVoice sanitization — rebuilding from raw display would
        # reintroduce —— and other misread symbols on the fallback path.
        fallback_src = display
        if normalize_speech_provider(speech_provider) in _ALIYUN_PROVIDERS:
            fallback_src = sanitize_for_cosyvoice(display)
        segs = build_pause_segments(fallback_src)
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
    return SynthesizeWithProsodyResult(
        audio=audio,
        display=display,
        speak_text=speak,
        ssml=None,
        used_ssml=False,
        prosody_mode=mode,
    )

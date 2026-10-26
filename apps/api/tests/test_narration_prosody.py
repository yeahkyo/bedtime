"""Unit tests for bedtime narration prosody (provider pauses, no local mix)."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.providers.base import VoiceSettings
from app.services.narration_prosody import (
    build_pause_segments,
    prepare_narration,
    render_fish_breaks,
    render_punct_breaths,
    render_ssml_breaks,
    sanitize_for_cosyvoice,
    strip_performance_markers,
    synthesize_with_prosody,
    voice_supports_ssml,
)

MULTI = (
    "今晚月亮亮亮的。小猫抬起爪子。\n\n"
    "可是球滚远了。后来它又捡回来。\n\n"
    "它轻轻闭上眼睛。慢慢睡着了。"
)


def test_strip_performance_markers():
    raw = "轻轻地。[pause:short]他慢慢睡着了。[soft][slow]晚安。[break]"
    assert strip_performance_markers(raw) == "轻轻地。他慢慢睡着了。晚安。"


def test_pause_segments_sentence_and_paragraph():
    segs = build_pause_segments(MULTI)
    assert len(segs) >= 5
    kinds = [s.after for s in segs]
    assert "short" in kinds
    assert "think" in kinds
    assert kinds[-1] == "long"


def test_prepare_fish_uses_bracket_breaks():
    prepared = prepare_narration(
        MULTI, voice_id="ref_x", speech_provider="fishaudio"
    )
    assert "[" not in prepared.display
    assert "[break]" in prepared.speak_text
    assert "[long-break]" in prepared.speak_text
    assert "[pause]" not in prepared.speak_text
    assert "[long pause]" not in prepared.speak_text
    assert "\n\n" not in prepared.speak_text
    assert prepared.ssml is None
    assert prepared.speech_rate_delta == 0
    assert prepared.loudness_rate == 0


def test_prepare_fish_break_mode_force():
    prepared = prepare_narration(
        MULTI, speech_provider="elevenlabs", prosody_mode="fish_break"
    )
    assert "[break]" in prepared.speak_text
    assert "[long-break]" in prepared.speak_text


def test_normalize_fish_pause_alias_to_break():
    prepared = prepare_narration(
        MULTI, speech_provider="fishaudio", prosody_mode="fish_pause"
    )
    assert prepared.prosody_mode == "fish_break"
    assert "[break]" in prepared.speak_text


def test_collapse_double_terminator_avoids_stacked_pauses():
    # Previously: "说完了。" + "……" → [break] then [long-break] back-to-back.
    segs = build_pause_segments("说完了。……\n\n下一句很长。")
    texts = [s.text for s in segs]
    assert texts == ["说完了。", "下一句很长。"]
    fish = render_fish_breaks(segs)
    assert "[break][long-break]" not in fish
    assert "[long-break]" in fish
    assert fish.index("[long-break]") < fish.index("下一句")


def test_closing_quote_stays_with_dialogue_sentence():
    """Avoid 。[break]”[long-break] when a paragraph ends on dialogue."""
    body = "小猫说：“今晚月亮真亮。”\n\n然后它睡着了。"
    segs = build_pause_segments(body)
    assert segs[0].text == "小猫说：“今晚月亮真亮。”"
    assert segs[0].after == "think"
    assert not any(s.text == "”" for s in segs)
    fish = render_fish_breaks(segs)
    assert "[break]”" not in fish
    assert "。”[long-break]" in fish
    assert fish.index("”") < fish.index("[long-break]")


def test_closing_quote_mid_paragraph_before_attribution():
    segs = build_pause_segments("“晚安。”他说。")
    assert segs[0].text == "“晚安。”"
    assert segs[0].after == "short"
    assert segs[1].text == "他说。"
    fish = render_fish_breaks(segs)
    assert "。”[break]他说。" in fish


def test_prepare_aliyun_uses_ssml_breaks():
    prepared = prepare_narration(
        MULTI, voice_id="longanyang", speech_provider="aliyun"
    )
    assert prepared.ssml is not None
    assert prepared.ssml.startswith("<speak>")
    assert 'break time="150ms"' in prepared.ssml
    assert 'break time="500ms"' in prepared.ssml
    assert 'break time="1200ms"' in prepared.ssml
    assert "[break]" not in (prepared.speak_text or "")
    assert "月亮" in prepared.display


def test_sanitize_for_cosyvoice_dash_becomes_comma_pause():
    assert "——" not in sanitize_for_cosyvoice("希望——前面有灯。")
    assert "希望，前面有灯。" == sanitize_for_cosyvoice("希望——前面有灯。")
    assert "，" in sanitize_for_cosyvoice("夜深了—月亮升起来。")
    cleaned = sanitize_for_cosyvoice("轻轻地（小声）说。")
    assert "（" not in cleaned and "小声" in cleaned
    assert "，" in cleaned


def test_prepare_aliyun_keeps_display_dash_sanitizes_speak():
    body = "小猫看见希望——前面有灯。\n\n它安心睡了。"
    prepared = prepare_narration(body, speech_provider="aliyun")
    assert "——" in prepared.display
    assert "——" not in prepared.speak_text
    assert "希望，前面" in prepared.speak_text
    assert prepared.ssml is not None
    assert "——" not in prepared.ssml
    assert "希望，前面" in prepared.ssml
    # Sentence/paragraph SSML breaks still present.
    assert 'break time="' in prepared.ssml


def test_prepare_fish_does_not_rewrite_em_dash():
    body = "希望——前面有灯。"
    prepared = prepare_narration(body, speech_provider="fishaudio")
    assert "——" in prepared.display
    assert "——" in prepared.speak_text


def test_prepare_cosyvoice_alias_ssml():
    prepared = prepare_narration("一句。两句。", speech_provider="cosyvoice")
    assert prepared.ssml and "<break" in prepared.ssml


def test_voice_supports_ssml_aliyun_and_not_fish():
    assert voice_supports_ssml("longanyang", speech_provider="aliyun") is True
    assert voice_supports_ssml("any", speech_provider="dashscope") is True
    assert voice_supports_ssml("zh_female_vv", speech_provider="fishaudio") is False
    assert voice_supports_ssml("zh_female_vv", speech_provider="elevenlabs") is False


def test_volc_clone_no_ssml():
    assert voice_supports_ssml("custom_abc", speech_provider="volc") is False
    assert voice_supports_ssml("S_123", speech_provider="volc") is False


def test_volc_ssml_when_flag_enabled():
    with patch("app.services.narration_prosody.get_settings") as gs:
        gs.return_value.volc_tts_enable_ssml = True
        gs.return_value.volc_tts_resource_id = "seed-tts-1.0"
        assert voice_supports_ssml("zh_female_vv", speech_provider="volc") is True
        prepared = prepare_narration(
            "开头。结尾。", voice_id="zh_female_vv", speech_provider="volc"
        )
        assert prepared.ssml and "break time=" in prepared.ssml


def test_punct_fallback_for_elevenlabs():
    prepared = prepare_narration(MULTI, speech_provider="elevenlabs")
    assert prepared.ssml is None
    assert "……" in prepared.speak_text
    assert "[break]" not in prepared.speak_text


def test_render_helpers():
    segs = build_pause_segments("第一句很长。第二句也很长。\n\n第三段收束。")
    ssml = render_ssml_breaks(segs)
    assert "<speak>" in ssml and "第一句很长。" in ssml
    fish = render_fish_breaks(segs)
    assert "[break]" in fish and "[long-break]" in fish
    punct = render_punct_breaths(segs)
    assert "……" in punct


def test_prepare_strips_legacy_markers_from_display():
    body = "开头一句。[pause:think]\n\n中间。[pause:short]\n\n结尾。[pause:long]"
    prepared = prepare_narration(body, speech_provider="fishaudio")
    assert prepared.display == "开头一句。\n\n中间。\n\n结尾。"
    assert "[pause:" not in prepared.display


def test_prepare_empty():
    prepared = prepare_narration("")
    assert prepared.display == ""
    assert prepared.speak_text == ""
    assert prepared.ssml is None


def test_skip_short_utterance_pause():
    segs = build_pause_segments("啊。然后月亮出来了。")
    # "啊。" is ≤2 content chars → no short after it
    assert segs[0].text.startswith("啊")
    assert segs[0].after is None
    assert segs[-1].after == "long"


@pytest.mark.asyncio
async def test_synthesize_fish_returns_speak_text():
    tts = MagicMock()
    tts.synthesize = AsyncMock(return_value=b"mp3")
    result = await synthesize_with_prosody(
        tts,
        MULTI,
        "voice-1",
        VoiceSettings(),
        speech_provider="fishaudio",
    )
    assert result.audio == b"mp3"
    assert "[break]" in result.speak_text
    assert result.ssml is None
    assert result.used_ssml is False
    assert tts.synthesize.await_args.args[0] == result.speak_text


@pytest.mark.asyncio
async def test_synthesize_aliyun_uses_ssml():
    tts = MagicMock()
    tts.synthesize = AsyncMock(return_value=b"mp3")
    result = await synthesize_with_prosody(
        tts,
        MULTI,
        "longanyang",
        VoiceSettings(),
        speech_provider="aliyun",
    )
    assert result.used_ssml is True
    assert result.ssml and result.ssml.startswith("<speak>")
    assert tts.synthesize.await_args.kwargs.get("ssml") == result.ssml


@pytest.mark.asyncio
async def test_synthesize_ssml_fallback():
    tts = MagicMock()
    tts.synthesize = AsyncMock(side_effect=[RuntimeError("ssml no"), b"mp3"])
    result = await synthesize_with_prosody(
        tts,
        MULTI,
        "longanyang",
        VoiceSettings(),
        speech_provider="aliyun",
    )
    assert result.audio == b"mp3"
    assert result.used_ssml is False
    assert result.ssml is None
    assert "……" in result.speak_text
    assert tts.synthesize.await_count == 2


@pytest.mark.asyncio
async def test_synthesize_ssml_fallback_keeps_cosyvoice_sanitize():
    """SSML failure must not reintroduce —— via punct rebuild from display."""
    tts = MagicMock()
    tts.synthesize = AsyncMock(side_effect=[RuntimeError("ssml no"), b"mp3"])
    body = "小猫看见希望——前面有灯。\n\n它安心睡了。"
    result = await synthesize_with_prosody(
        tts,
        body,
        "longanyang",
        VoiceSettings(),
        speech_provider="aliyun",
    )
    assert "——" in result.display
    assert "——" not in result.speak_text
    assert "希望，前面" in result.speak_text
    # Fallback path text argument must also be sanitized.
    assert "——" not in (tts.synthesize.await_args_list[1].args[0] or "")
    assert "希望，前面" in (tts.synthesize.await_args_list[1].args[0] or "")

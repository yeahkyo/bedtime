"""Unit tests for bedtime narration prosody (provider pauses, no local mix)."""

from unittest.mock import patch

from app.services.narration_prosody import (
    build_pause_segments,
    prepare_narration,
    render_fish_breaks,
    render_punct_breaths,
    render_ssml_breaks,
    strip_performance_markers,
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
    assert prepared.ssml is None
    assert prepared.speech_rate_delta == 0
    assert prepared.loudness_rate == 0


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
    assert "[pause" not in prepared.display


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

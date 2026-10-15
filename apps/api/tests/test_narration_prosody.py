"""Unit tests for bedtime narration prosody (SSML / punctuation, no local mix)."""

from app.services.narration_prosody import (
    apply_performance_heuristics,
    markers_to_punctuated_text,
    markers_to_ssml,
    prepare_narration,
    strip_performance_markers,
    voice_supports_ssml,
)


def test_strip_performance_markers():
    raw = "轻轻地。[pause:short]他慢慢睡着了。[soft][slow]晚安。"
    assert strip_performance_markers(raw) == "轻轻地。他慢慢睡着了。晚安。"


def test_heuristics_and_prepare_display():
    body = (
        "今晚月亮亮亮的。小猫抬起爪子。\n\n"
        "可是球滚远了。后来它又捡回来。\n\n"
        "它轻轻闭上眼睛。慢慢睡着了。"
    )
    marked = apply_performance_heuristics(body)
    assert "[pause:" in marked
    prepared = prepare_narration(body, voice_id="custom_demo")
    assert "[" not in prepared.display
    assert "……" in prepared.speak_text
    assert prepared.ssml is None  # clone / default 2.0 → no SSML
    # Markers must not stack extra whole-utterance slow on top of user speed_tier.
    assert prepared.speech_rate_delta == 0
    assert prepared.loudness_rate == 0


def test_existing_markers_trusted():
    body = "开头一句。[pause:think]\n\n中间。[pause:short]\n\n[soft][slow]结尾。[pause:long]"
    assert apply_performance_heuristics(body) == body
    prepared = prepare_narration(body, voice_id="custom_x")
    assert prepared.display == "开头一句。\n\n中间。\n\n结尾。"
    assert "……" in prepared.speak_text


def test_markers_to_ssml_breaks_and_prosody():
    marked = "开头。[pause:think][soft][slow]轻轻睡着了。[pause:long]"
    ssml = markers_to_ssml(marked)
    assert ssml.startswith("<speak>")
    assert 'break time="900ms"' in ssml
    assert "<prosody" in ssml
    assert "轻轻睡着了" in ssml
    assert "&lt;" not in ssml


def test_markers_to_punctuated():
    marked = "第一句。[pause:think]第二句。[pause:short]"
    spoken = markers_to_punctuated_text(marked)
    assert "第一句" in spoken and "第二句" in spoken
    assert "……" in spoken
    assert "[pause" not in spoken


def test_clone_voice_no_ssml_flag():
    assert voice_supports_ssml("custom_abc") is False
    assert voice_supports_ssml("S_123") is False


def test_non_volc_speech_provider_no_ssml():
    assert voice_supports_ssml("zh_female_vv", speech_provider="fishaudio") is False
    assert voice_supports_ssml("zh_female_vv", speech_provider="elevenlabs") is False
    prepared = prepare_narration("晚安。", voice_id="zh_female_vv", speech_provider="fishaudio")
    assert prepared.ssml is None


def test_prepare_empty():
    prepared = prepare_narration("")
    assert prepared.display == ""
    assert prepared.speak_text == ""

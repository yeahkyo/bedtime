"""STORY_SKIP_TTS gates speech synthesis after LLM."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from app.core.config import clear_settings_cache
from app.services.story_jobs import story_tts_disabled


def test_story_tts_disabled_reads_settings(monkeypatch):
    clear_settings_cache()
    monkeypatch.setenv("STORY_SKIP_TTS", "1")
    clear_settings_cache()
    assert story_tts_disabled() is True
    monkeypatch.setenv("STORY_SKIP_TTS", "0")
    clear_settings_cache()
    assert story_tts_disabled() is False
    clear_settings_cache()


@pytest.mark.asyncio
async def test_run_tts_respects_skip_flag(monkeypatch):
    from app.services import story_jobs as sj

    clear_settings_cache()
    monkeypatch.setenv("STORY_SKIP_TTS", "1")
    clear_settings_cache()

    finalize = MagicMock()

    async def _fin(*_a, **_k):
        finalize()

    with patch.object(sj, "_finalize_without_tts", _fin), patch.object(
        sj, "_claim_tts_lease", MagicMock()
    ) as claim:
        await sj._run_tts_and_store(
            MagicMock(),
            story_id=1,
            user_id=1,
            narration_body="hello",
            provider_voice_id="v",
            voice_settings={},
            speech_name="fishaudio",
            job_t0=0.0,
            llm_ms=10,
        )
    finalize.assert_called_once()
    claim.assert_not_called()
    clear_settings_cache()

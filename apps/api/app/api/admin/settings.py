from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.core.security import require_admin
from app.services.provider_settings import (
    SPEECH_PROVIDERS,
    STORY_PROVIDERS,
    env_speech_provider,
    env_story_provider,
    get_runtime_overrides,
    list_available_providers,
    resolve_speech_provider_name,
    resolve_story_provider_name,
    set_runtime_overrides,
)

router = APIRouter(prefix="/settings", tags=["admin-settings"])


class ProvidersSettingsOut(BaseModel):
    story_provider: str
    speech_provider: str
    env_story_provider: str
    env_speech_provider: str
    overrides: dict[str, str]
    available: dict


class ProvidersSettingsPatch(BaseModel):
    story_provider: str | None = Field(default=None, max_length=32)
    speech_provider: str | None = Field(default=None, max_length=32)


async def _providers_out() -> ProvidersSettingsOut:
    overrides = await get_runtime_overrides()
    return ProvidersSettingsOut(
        story_provider=await resolve_story_provider_name(),
        speech_provider=await resolve_speech_provider_name(),
        env_story_provider=env_story_provider(),
        env_speech_provider=env_speech_provider(),
        overrides=overrides,
        available=list_available_providers(),
    )


@router.get("/providers", response_model=ProvidersSettingsOut)
async def get_providers_settings(_: str = Depends(require_admin)) -> ProvidersSettingsOut:
    return await _providers_out()


@router.patch("/providers", response_model=ProvidersSettingsOut)
async def patch_providers_settings(
    body: ProvidersSettingsPatch,
    _: str = Depends(require_admin),
) -> ProvidersSettingsOut:
    if body.story_provider is None and body.speech_provider is None:
        raise HTTPException(status_code=400, detail="No provider fields to update")
    if body.story_provider is not None and body.story_provider.strip().lower() not in STORY_PROVIDERS:
        raise HTTPException(status_code=400, detail="Invalid story_provider")
    if body.speech_provider is not None and body.speech_provider.strip().lower() not in SPEECH_PROVIDERS:
        raise HTTPException(status_code=400, detail="Invalid speech_provider")
    try:
        await set_runtime_overrides(
            story_provider=body.story_provider,
            speech_provider=body.speech_provider,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return await _providers_out()

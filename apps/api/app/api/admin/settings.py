from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.core.security import require_admin
from app.services.provider_settings import (
    STORY_PROVIDERS,
    env_story_model,
    env_story_provider,
    get_runtime_overrides,
    list_available_providers,
    resolve_story_model,
    resolve_story_provider_name,
    set_runtime_overrides,
)

router = APIRouter(prefix="/settings", tags=["admin-settings"])


class ProvidersSettingsOut(BaseModel):
    story_provider: str
    story_model: str
    env_story_provider: str
    env_story_model: str
    overrides: dict[str, str]
    available: dict


class ProvidersSettingsPatch(BaseModel):
    story_provider: str | None = Field(default=None, max_length=32)
    story_model: str | None = Field(default=None, max_length=128)


async def _providers_out() -> ProvidersSettingsOut:
    overrides = await get_runtime_overrides()
    story = await resolve_story_provider_name()
    return ProvidersSettingsOut(
        story_provider=story,
        story_model=await resolve_story_model(story),
        env_story_provider=env_story_provider(),
        env_story_model=env_story_model(story),
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
    data = body.model_dump(exclude_unset=True)
    if not data:
        raise HTTPException(status_code=400, detail="No provider fields to update")
    if "story_provider" in data and data["story_provider"] is not None:
        if data["story_provider"].strip().lower() not in STORY_PROVIDERS:
            raise HTTPException(status_code=400, detail="Invalid story_provider")
    try:
        await set_runtime_overrides(
            story_provider=data.get("story_provider"),
            story_model=data.get("story_model") if "story_model" in data else None,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return await _providers_out()

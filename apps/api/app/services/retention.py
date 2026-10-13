from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import get_settings
from app.models.story import Story, StoryAudio
from app.models.voice import Voice
from app.providers.factory import get_clone_provider
from app.services.storage import storage_service


async def purge_expired_raw_voices(db: AsyncSession) -> int:
    now = datetime.now(timezone.utc)
    result = await db.execute(
        select(Voice).where(Voice.raw_object_key.is_not(None), Voice.raw_purge_after.is_not(None))
    )
    count = 0
    for voice in result.scalars().all():
        if voice.raw_purge_after and voice.raw_purge_after <= now and voice.raw_object_key:
            await storage_service.delete(voice.raw_object_key)
            voice.raw_object_key = None
            voice.raw_purge_after = None
            count += 1
    await db.commit()
    return count


async def purge_expired_stories(db: AsyncSession) -> int:
    now = datetime.now(timezone.utc)
    result = await db.execute(
        select(Story)
        .where(Story.expires_at.is_not(None), Story.expires_at <= now)
        .options(selectinload(Story.audio))
    )
    count = 0
    for story in result.scalars().all():
        if story.audio and story.audio.object_key:
            await storage_service.delete(story.audio.object_key)
        await db.delete(story)
        count += 1
    await db.commit()
    return count


async def cascade_delete_user(db: AsyncSession, user_id: int) -> None:
    clone = get_clone_provider()
    voices = (await db.execute(select(Voice).where(Voice.user_id == user_id))).scalars().all()
    for voice in voices:
        if voice.kind == "clone":
            try:
                await clone.delete(voice.provider_voice_id)
            except Exception:
                pass
        if voice.raw_object_key:
            await storage_service.delete(voice.raw_object_key)

    stories = (await db.execute(select(Story).where(Story.user_id == user_id))).scalars().all()
    for story in stories:
        audio = (
            await db.execute(select(StoryAudio).where(StoryAudio.story_id == story.id))
        ).scalar_one_or_none()
        if audio:
            await storage_service.delete(audio.object_key)

    from app.models.user import User

    user = await db.get(User, user_id)
    if user:
        await db.delete(user)
    await db.commit()


def story_expiry_from_now(months: int | None = None) -> datetime:
    settings = get_settings()
    m = months if months is not None else settings.story_retention_months
    return datetime.now(timezone.utc) + timedelta(days=30 * m)


def raw_voice_purge_at() -> datetime:
    settings = get_settings()
    return datetime.now(timezone.utc) + timedelta(hours=settings.raw_voice_retention_hours)

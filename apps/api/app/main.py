from contextlib import asynccontextmanager
import logging
from pathlib import Path
import sys

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from app.api import account, auth, children, stories, voices
from app.api.admin import router as admin_router
from app.core.config import get_settings, validate_settings_for_runtime
from app.core.db import Base, SessionLocal, engine
from app.core.redis_client import close_redis
from app.models import (  # noqa: F401
    Child,
    Memory,
    MemoryAsset,
    MemoryElement,
    Story,
    StoryAudio,
    StoryBeatPattern,
    StorySeries,
    UsageLedger,
    User,
    Voice,
    VoicePrefs,
)
from app.services.beat_patterns import seed_beat_patterns_if_empty
from app.services.provider_settings import env_speech_provider, env_story_provider


def _configure_app_logging() -> None:
    """Uvicorn often leaves root at WARNING; ensure app.* INFO (e.g. story_timing) reaches stderr."""
    log = logging.getLogger("app")
    log.setLevel(logging.INFO)
    if not any(isinstance(h, logging.StreamHandler) for h in log.handlers):
        handler = logging.StreamHandler(sys.stderr)
        handler.setLevel(logging.INFO)
        handler.setFormatter(logging.Formatter("%(levelname)s:%(name)s:%(message)s"))
        log.addHandler(handler)
    # Avoid depending on root level (WARNING) filtering propagated records.
    log.propagate = False


_configure_app_logging()


async def _ensure_story_async_columns(conn) -> None:
    """create_all won't add columns to existing tables — patch for async jobs."""
    for stmt in (
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS progress VARCHAR(32) NULL",
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS error_message TEXT NULL",
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS story_provider VARCHAR(32) NULL",
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS speech_provider VARCHAR(32) NULL",
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS episode_plan_json TEXT NULL",
        "ALTER TABLE children ADD COLUMN IF NOT EXISTS birth_date DATE NULL",
        "ALTER TABLE children ADD COLUMN IF NOT EXISTS gender VARCHAR(32) NULL",
        "ALTER TABLE children ADD COLUMN IF NOT EXISTS intro TEXT NULL",
    ):
        try:
            await conn.execute(text(stmt))
        except Exception:
            # Older MariaDB without IF NOT EXISTS: ignore duplicate column errors.
            pass


async def _backfill_child_birth_dates(db) -> None:
    """Legacy rows only have age_band — approximate birth_date once."""
    from sqlalchemy import select

    from app.models.child import Child
    from app.services.child_profile import (
        approximate_birth_date_from_age_band,
        normalize_gender,
        sync_age_band,
    )

    rows = (await db.execute(select(Child).where(Child.birth_date.is_(None)))).scalars().all()
    if not rows:
        return
    for child in rows:
        birth = approximate_birth_date_from_age_band(child.age_band)
        child.birth_date = birth
        child.age_band = sync_age_band(birth, child.age_band)
        if not child.gender:
            child.gender = normalize_gender(None)
    await db.commit()


@asynccontextmanager
async def lifespan(_: FastAPI):
    validate_settings_for_runtime()
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        await _ensure_story_async_columns(conn)
    async with SessionLocal() as db:
        await seed_beat_patterns_if_empty(db)
        await _backfill_child_birth_dates(db)
    yield
    await close_redis()
    await engine.dispose()


app = FastAPI(
    title="Lullvale Bedtime API",
    version="0.1.0",
    lifespan=lifespan,
)

_settings = get_settings()
if _settings.is_dev:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )
else:
    origins = _settings.cors_origin_list()
    if origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=origins,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )

app.include_router(auth.router, prefix="/v1")
app.include_router(children.router, prefix="/v1")
app.include_router(stories.router, prefix="/v1")
app.include_router(voices.router, prefix="/v1")
app.include_router(account.router, prefix="/v1")
app.include_router(admin_router, prefix="/admin")

local_data = Path(__file__).resolve().parents[1] / ".data"
local_data.mkdir(parents=True, exist_ok=True)
# Only expose anonymous /media in local-dev; production should use signed/private storage.
if _settings.storage_backend == "local" and _settings.is_dev:
    app.mount("/media", StaticFiles(directory=str(local_data)), name="media")


@app.get("/health")
async def health() -> dict:
    from app.core.config import clear_settings_cache, get_settings

    clear_settings_cache()
    s = get_settings()
    return {
        "ok": True,
        "env": s.env,
        "mock_providers": s.mock_providers,
        "provider_profile": s.provider_profile,
        "story_provider": env_story_provider(s),
        "speech_provider": env_speech_provider(s),
        "ark_configured": bool(s.ark_api_key),
        "speech_configured": bool(
            s.fish_audio_api_key or s.volc_speech_api_key or s.ark_api_key or s.elevenlabs_api_key
        ),
        "fish_configured": bool(s.fish_audio_api_key),
    }


@app.get("/")
async def root() -> dict:
    return {"service": "lullvale-bedtime-api", "docs": "/docs"}

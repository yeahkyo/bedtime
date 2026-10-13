from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from app.api import account, auth, children, stories, voices
from app.core.config import get_settings, validate_settings_for_runtime
from app.core.db import Base, engine
from app.core.redis_client import close_redis
from app.models import (  # noqa: F401
    Child,
    Memory,
    MemoryAsset,
    MemoryElement,
    Story,
    StoryAudio,
    StorySeries,
    UsageLedger,
    User,
    Voice,
    VoicePrefs,
)


async def _ensure_story_async_columns(conn) -> None:
    """create_all won't add columns to existing tables — patch for async jobs."""
    for stmt in (
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS progress VARCHAR(32) NULL",
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS error_message TEXT NULL",
    ):
        try:
            await conn.execute(text(stmt))
        except Exception:
            # Older MariaDB without IF NOT EXISTS: ignore duplicate column errors.
            pass


@asynccontextmanager
async def lifespan(_: FastAPI):
    validate_settings_for_runtime()
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        await _ensure_story_async_columns(conn)
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
        "ark_configured": bool(s.ark_api_key),
        "speech_configured": bool(s.volc_speech_api_key or s.ark_api_key),
    }


@app.get("/")
async def root() -> dict:
    return {"service": "lullvale-bedtime-api", "docs": "/docs"}

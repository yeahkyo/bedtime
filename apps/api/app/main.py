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
from app.api.elements import router as elements_router
from app.api.kernels import router as kernels_router
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
    StoryElement,
    StoryElementCategory,
    StoryElementSubcategory,
    StoryElementUsage,
    StorySeries,
    StoryShape,
    UsageLedger,
    User,
    Voice,
    VoicePrefs,
)
from app.services.provider_settings import first_configured_speech_provider, env_story_provider
from app.services.story_elements import (
    enable_elements_if_none_enabled,
    seed_story_elements_if_empty,
)
from app.services.story_job_recovery import (
    mark_process_started,
    reclaim_orphaned_story_jobs,
    spawn_resumed_tts_jobs,
)
from app.services.llm_agents import seed_llm_agents_if_missing
from app.services.story_kernels import seed_story_kernels_if_empty
from app.services.story_shapes import seed_story_shapes_if_empty


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
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS speech_model VARCHAR(128) NULL",
        "ALTER TABLE voices ADD COLUMN IF NOT EXISTS speech_model VARCHAR(128) NULL",
        "ALTER TABLE voices ADD COLUMN IF NOT EXISTS speed_tier VARCHAR(16) NULL",
        "UPDATE voices SET speed_tier = 'medium' WHERE speed_tier IS NULL OR speed_tier = ''",
        "ALTER TABLE voices ADD COLUMN IF NOT EXISTS speed DOUBLE NOT NULL DEFAULT 1.0",
        "UPDATE voices SET speed = 0.85 WHERE speed_tier = 'slow' AND ABS(speed - 1.0) < 0.001",
        "UPDATE voices SET speed = 1.1 WHERE speed_tier = 'fast' AND ABS(speed - 1.0) < 0.001",
        "ALTER TABLE voices ADD COLUMN IF NOT EXISTS enabled TINYINT(1) NOT NULL DEFAULT 1",
        "ALTER TABLE voices ADD COLUMN IF NOT EXISTS preview_text TEXT NULL",
        "ALTER TABLE voices ADD COLUMN IF NOT EXISTS preview_object_key VARCHAR(512) NULL",
        "ALTER TABLE voices ADD COLUMN IF NOT EXISTS preview_generated_at DATETIME NULL",
        "ALTER TABLE voices ADD COLUMN IF NOT EXISTS description VARCHAR(200) NULL",
        "ALTER TABLE voices ADD COLUMN IF NOT EXISTS sort_order INT NOT NULL DEFAULT 0",
        # Global system voice catalog: user_id NULL = shared across all users.
        "ALTER TABLE voices MODIFY user_id INT NULL",
        # Default narration speed is medium (1.0); bump legacy slow defaults (no client speed UI).
        "UPDATE voice_prefs SET speed_tier = 'medium', speed = 1.0 "
        "WHERE speed_tier = 'slow' AND ABS(speed - 0.85) < 0.001",
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS episode_plan_json TEXT NULL",
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS metrics_json TEXT NULL",
        "ALTER TABLE stories ADD COLUMN prompts_json MEDIUMTEXT NULL",
        "ALTER TABLE stories ADD COLUMN IF NOT EXISTS progress_at DATETIME NULL",
        "ALTER TABLE children ADD COLUMN IF NOT EXISTS birth_date DATE NULL",
        "ALTER TABLE children ADD COLUMN IF NOT EXISTS gender VARCHAR(32) NULL",
        "ALTER TABLE children ADD COLUMN IF NOT EXISTS intro TEXT NULL",
        "ALTER TABLE story_element_subcategories ADD COLUMN IF NOT EXISTS generation_brief TEXT NULL",
        "ALTER TABLE story_element_subcategories ADD COLUMN IF NOT EXISTS id_prefix VARCHAR(16) NULL",
        # Legacy beat_patterns catalog replaced by story_shapes.
        "DROP TABLE IF EXISTS story_beat_patterns",
        # Shape pool no longer stores theme/focus bias columns.
        "ALTER TABLE story_shapes DROP COLUMN theme_tags_json",
        "ALTER TABLE story_shapes DROP COLUMN focus_ids_json",
        "ALTER TABLE story_shapes ADD COLUMN effect TEXT NULL",
        "ALTER TABLE llm_agents ADD COLUMN temperature DOUBLE NULL",
    ):
        try:
            await conn.execute(text(stmt))
        except Exception:
            # Older MariaDB without IF NOT EXISTS: ignore duplicate column errors.
            pass
    await _migrate_story_elements_objective_schema(conn)


async def _migrate_story_elements_objective_schema(conn) -> None:
    """Local/pre-prod: reshape story_elements to name/description/age_stage only."""
    # Detect legacy columns; if present, wipe rows (not shipped to prod yet) and reshape.
    try:
        cols = {
            str(r[0])
            for r in (
                await conn.execute(text("SHOW COLUMNS FROM story_elements"))
            ).fetchall()
        }
    except Exception:
        return
    legacy = {"topic", "fact", "philosophy", "min_age_years", "max_age_years", "min_age_months"}
    if not (cols & legacy) and {"name", "description", "age_stage"} <= cols:
        return
    for stmt in (
        "DELETE FROM story_element_usages",
        "DELETE FROM story_elements",
    ):
        try:
            await conn.execute(text(stmt))
        except Exception:
            pass
    for stmt in (
        "ALTER TABLE story_elements ADD COLUMN name VARCHAR(256) NOT NULL DEFAULT ''",
        "ALTER TABLE story_elements ADD COLUMN description TEXT NULL",
        "ALTER TABLE story_elements ADD COLUMN age_stage VARCHAR(32) NOT NULL DEFAULT 'preschool_3_5'",
    ):
        try:
            await conn.execute(text(stmt))
        except Exception:
            pass
    for col in (
        "topic",
        "fact",
        "philosophy",
        "min_age_years",
        "max_age_years",
        "min_age_months",
        "max_age_months",
    ):
        try:
            await conn.execute(text(f"ALTER TABLE story_elements DROP COLUMN {col}"))
        except Exception:
            pass
    for stmt in (
        "ALTER TABLE story_elements MODIFY name VARCHAR(256) NOT NULL DEFAULT ''",
        "ALTER TABLE story_elements MODIFY description TEXT NOT NULL",
        "ALTER TABLE story_elements MODIFY age_stage VARCHAR(32) NOT NULL DEFAULT 'preschool_3_5'",
        "CREATE INDEX ix_story_elements_age_stage ON story_elements (age_stage, enabled)",
        "DROP INDEX ix_story_elements_age_years ON story_elements",
        "DROP INDEX ix_story_elements_age_months ON story_elements",
    ):
        try:
            await conn.execute(text(stmt))
        except Exception:
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
    mark_process_started()
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        await _ensure_story_async_columns(conn)
    async with SessionLocal() as db:
        await seed_story_shapes_if_empty(db)
        await seed_story_elements_if_empty(db)
        await enable_elements_if_none_enabled(db)
        await seed_story_kernels_if_empty(db)
        await seed_llm_agents_if_missing(db)
        await _backfill_child_birth_dates(db)
        resume_jobs, failed_n = await reclaim_orphaned_story_jobs(db)
    if resume_jobs:
        await spawn_resumed_tts_jobs(resume_jobs)
    if resume_jobs or failed_n:
        import logging

        logging.getLogger(__name__).warning(
            "story_reclaim startup resumed_tts=%s marked_failed=%s",
            len(resume_jobs),
            failed_n,
        )
    yield
    await close_redis()
    await engine.dispose()


_settings = get_settings()
_docs = _settings.api_docs_enabled
app = FastAPI(
    title="Lullvale Bedtime API",
    version="0.1.0",
    lifespan=lifespan,
    docs_url="/docs" if _docs else None,
    redoc_url="/redoc" if _docs else None,
    openapi_url="/openapi.json" if _docs else None,
)

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
app.include_router(kernels_router, prefix="/v1")
app.include_router(elements_router, prefix="/v1")
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
        "speech_provider": first_configured_speech_provider(s),
        "ark_configured": bool(s.ark_api_key),
        "speech_configured": bool(
            s.fish_audio_api_key or s.volc_speech_api_key or s.ark_api_key or s.elevenlabs_api_key
        ),
        "fish_configured": bool(s.fish_audio_api_key),
        "story_skip_tts": bool(s.story_skip_tts),
    }


@app.get("/")
async def root() -> dict:
    return {"service": "lullvale-bedtime-api", "docs": "/docs"}

from fastapi import APIRouter

from app.api.admin import auth, beats, settings, stories, users

router = APIRouter()
router.include_router(auth.router)
router.include_router(users.router)
router.include_router(stories.router)
router.include_router(settings.router)
router.include_router(beats.router)

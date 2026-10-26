from fastapi import APIRouter

from app.api.admin import (
    analytics,
    auth,
    elements,
    invites,
    kernels,
    llm_agents,
    series,
    settings,
    shapes,
    stories,
    users,
    voices,
)

router = APIRouter()
router.include_router(auth.router)
router.include_router(users.router)
router.include_router(invites.router)
router.include_router(stories.router)
router.include_router(series.router)
router.include_router(settings.router)
router.include_router(shapes.router)
router.include_router(elements.router)
router.include_router(kernels.router)
router.include_router(llm_agents.router)
router.include_router(voices.router)
router.include_router(analytics.router)

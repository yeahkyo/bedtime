from datetime import timezone

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.core.config import get_settings
from app.core.security import create_admin_token

router = APIRouter(prefix="/auth", tags=["admin-auth"])


class AdminLoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=64)
    password: str = Field(min_length=1, max_length=128)


class AdminLoginOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_at: str
    operator: str
    username: str


@router.post("/login", response_model=AdminLoginOut)
async def admin_login(body: AdminLoginRequest) -> AdminLoginOut:
    settings = get_settings()
    expected_user = (settings.admin_bootstrap_username or "admin").strip()
    expected_pass = (settings.admin_bootstrap_password or "").strip()
    if not expected_pass:
        raise HTTPException(status_code=503, detail="Admin login is not configured")
    if body.username.strip() != expected_user or body.password != expected_pass:
        raise HTTPException(status_code=401, detail="Invalid username or password")
    token, expires = create_admin_token(expected_user)
    return AdminLoginOut(
        access_token=token,
        expires_at=expires.astimezone(timezone.utc).isoformat(),
        operator=expected_user,
        username=expected_user,
    )

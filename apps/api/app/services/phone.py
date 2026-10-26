import re

from fastapi import HTTPException


_CN_MOBILE = re.compile(r"^1[3-9]\d{9}$")

# Non-CN mobiles reserved for App Store / Play review demo logins.
_APP_REVIEW_PHONES = frozenset({"01234567890"})


def normalize_phone(raw: str) -> str:
    """Normalize to 11-digit CN mobile (no +86). Raises 400 on invalid."""
    s = (raw or "").strip().replace(" ", "").replace("-", "")
    if s.startswith("+86"):
        s = s[3:]
    elif s.startswith("86") and len(s) == 13:
        s = s[2:]
    if s in _APP_REVIEW_PHONES:
        return s
    if not _CN_MOBILE.match(s):
        raise HTTPException(status_code=400, detail="Invalid phone number")
    return s


def apple_sub_for_phone(phone: str) -> str:
    return f"phone:{phone}"

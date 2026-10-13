"""Client-safe error messages (log full exceptions server-side)."""

from __future__ import annotations


def safe_error_message(exc: BaseException, *, fallback: str = "Something went wrong") -> str:
    """Map exceptions to short, stable strings safe for API clients / DB error_message."""
    name = type(exc).__name__
    # Known FastAPI / domain patterns sometimes already carry a stable detail.
    detail = getattr(exc, "detail", None)
    if isinstance(detail, str) and detail and len(detail) <= 200 and "\n" not in detail:
        if not any(tok in detail.lower() for tok in ("traceback", "file \"", "sqlalchemy")):
            return detail[:500]

    mapping = {
        "HTTPException": fallback,
        "TimeoutError": "Request timed out",
        "asyncio.TimeoutError": "Request timed out",
        "ConnectError": "Upstream service unavailable",
        "ReadTimeout": "Upstream service timed out",
        "APIStatusError": "Upstream provider error",
        "JSONDecodeError": "Invalid response from provider",
    }
    if name in mapping:
        return mapping[name]
    # Prefer generic categories over leaking provider/SQL internals.
    text = str(exc).lower()
    if "quota" in text or "limit" in text:
        return "Quota exceeded"
    if "timeout" in text:
        return "Request timed out"
    if "not found" in text:
        return "Resource not found"
    return fallback

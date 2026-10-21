"""Child profile helpers: birth date → age band, gender normalize."""

from __future__ import annotations

from datetime import date, datetime, timezone

GENDER_VALUES = ("girl", "boy", "other", "unspecified")
GENDER_LABELS_ZH = {
    "girl": "女孩",
    "boy": "男孩",
    "other": "其他",
    "unspecified": "不指定",
}

# Mid-band ages used only to backfill birth_date from legacy age_band.
_LEGACY_BAND_AGES = {
    "2-3": 2.5,
    "3-5": 4.0,
    "6-8": 7.0,
    "9-12": 10.5,
}


def normalize_gender(raw: str | None) -> str:
    g = (raw or "unspecified").strip().lower()
    aliases = {
        "female": "girl",
        "f": "girl",
        "女": "girl",
        "女孩": "girl",
        "male": "boy",
        "m": "boy",
        "男": "boy",
        "男孩": "boy",
        "unknown": "unspecified",
        "none": "unspecified",
        "": "unspecified",
    }
    g = aliases.get(g, g)
    return g if g in GENDER_VALUES else "unspecified"


def age_years_on(birth: date, *, on: date | None = None) -> float:
    today = on or date.today()
    if birth > today:
        return 0.0
    days = (today - birth).days
    return max(0.0, days / 365.25)


def age_months_on(birth: date | None, *, on: date | None = None) -> int:
    """Whole months since birth (calendar months). None birth → 48 (~4y)."""
    if birth is None:
        return 48
    today = on or date.today()
    if birth > today:
        return 0
    months = (today.year - birth.year) * 12 + (today.month - birth.month)
    if today.day < birth.day:
        months -= 1
    return max(0, months)


def age_years_int_on(birth: date | None, *, on: date | None = None) -> int:
    """Whole years since birth (calendar). None birth → 4."""
    if birth is None:
        return 4
    today = on or date.today()
    if birth > today:
        return 0
    years = today.year - birth.year
    if (today.month, today.day) < (birth.month, birth.day):
        years -= 1
    return max(0, years)


def age_band_from_birth_date(birth: date | None, *, on: date | None = None) -> str:
    """Runtime prompt bucket from birth date — not a stored source of truth."""
    if birth is None:
        return "3-5"
    years = age_years_on(birth, on=on)
    if years < 3:
        return "2-3"
    if years < 6:
        return "3-5"
    if years < 9:
        return "6-8"
    return "9-12"


def approximate_birth_date_from_age_band(age_band: str | None, *, on: date | None = None) -> date:
    """Best-effort birth date for migrating legacy age_band rows."""
    today = on or date.today()
    years = _LEGACY_BAND_AGES.get((age_band or "3-5").strip(), 4.0)
    # Approximate without calendar edge cases: subtract years*365 days.
    return date.fromordinal(max(1, today.toordinal() - int(years * 365.25)))


def parse_birth_date(raw: str | date | datetime | None) -> date | None:
    if raw is None:
        return None
    if isinstance(raw, datetime):
        return raw.date()
    if isinstance(raw, date):
        return raw
    text = str(raw).strip()
    if not text:
        return None
    for fmt in ("%Y-%m-%d", "%Y/%m/%d", "%Y.%m.%d"):
        try:
            return datetime.strptime(text[:10], fmt).date()
        except ValueError:
            continue
    raise ValueError(f"Invalid birth_date: {raw!r}")


def sync_age_band(birth: date | None, fallback_band: str | None = None) -> str:
    if birth is not None:
        return age_band_from_birth_date(birth)
    return (fallback_band or "3-5").strip() or "3-5"

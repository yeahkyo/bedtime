"""DAU and classic D1/D7/D30 retention from analytics_events activity days."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta

# Events that count as "used the app that day".
ACTIVITY_EVENT_NAMES: frozenset[str] = frozenset(
    {
        "app_open",
        "register_success",
        "login_success",
        "create_open",
        "generate_tap",
        "story_ready",
        "story_failed",
        "player_open",
        "playback_complete",
        "quota_hit",
    }
)

MAX_ENGAGEMENT_RANGE_DAYS = 90
RETENTION_OFFSETS = (1, 7, 30)


@dataclass(frozen=True)
class DauPoint:
    day: date
    users: int


@dataclass(frozen=True)
class RetentionCohort:
    cohort_date: date
    cohort_size: int
    d1: float | None
    d7: float | None
    d30: float | None


@dataclass(frozen=True)
class EngagementResult:
    from_date: date
    to_date: date
    as_of: date
    dau: list[DauPoint]
    retention: list[RetentionCohort]
    avg_dau: float | None
    avg_d1: float | None
    avg_d7: float | None
    avg_d30: float | None


def clamp_engagement_range(from_date: date, to_date: date) -> tuple[date, date]:
    if to_date < from_date:
        from_date, to_date = to_date, from_date
    span = (to_date - from_date).days + 1
    if span > MAX_ENGAGEMENT_RANGE_DAYS:
        from_date = to_date - timedelta(days=MAX_ENGAGEMENT_RANGE_DAYS - 1)
    return from_date, to_date


def _users_on(
    by_day: dict[date, set[int]], day: date
) -> set[int]:
    return by_day.get(day) or set()


def _rate(cohort: set[int], returned: set[int]) -> float | None:
    if not cohort:
        return None
    return len(cohort & returned) / len(cohort)


def _avg(values: list[float]) -> float | None:
    if not values:
        return None
    return sum(values) / len(values)


def compute_engagement(
    user_days: set[tuple[int, date]],
    from_date: date,
    to_date: date,
    *,
    as_of: date | None = None,
) -> EngagementResult:
    """Compute DAU + retention for each cohort day in [from_date, to_date].

    ``user_days`` must include activity through ``to_date + 30 days`` (or through
    ``as_of``) so D30 can be evaluated when mature.
    Retention rates are null when the look-ahead day is after ``as_of``.
    """
    from_date, to_date = clamp_engagement_range(from_date, to_date)
    as_of = as_of or date.today()

    by_day: dict[date, set[int]] = {}
    for user_id, day in user_days:
        by_day.setdefault(day, set()).add(user_id)

    dau: list[DauPoint] = []
    retention: list[RetentionCohort] = []
    d1_vals: list[float] = []
    d7_vals: list[float] = []
    d30_vals: list[float] = []

    day = from_date
    while day <= to_date:
        cohort = _users_on(by_day, day)
        dau.append(DauPoint(day=day, users=len(cohort)))

        rates: dict[int, float | None] = {}
        for offset in RETENTION_OFFSETS:
            target = day + timedelta(days=offset)
            if target > as_of:
                rates[offset] = None
            else:
                rates[offset] = _rate(cohort, _users_on(by_day, target))

        retention.append(
            RetentionCohort(
                cohort_date=day,
                cohort_size=len(cohort),
                d1=rates[1],
                d7=rates[7],
                d30=rates[30],
            )
        )
        if rates[1] is not None and len(cohort) > 0:
            d1_vals.append(rates[1])
        if rates[7] is not None and len(cohort) > 0:
            d7_vals.append(rates[7])
        if rates[30] is not None and len(cohort) > 0:
            d30_vals.append(rates[30])

        day += timedelta(days=1)

    dau_users = [p.users for p in dau]
    return EngagementResult(
        from_date=from_date,
        to_date=to_date,
        as_of=as_of,
        dau=dau,
        retention=retention,
        avg_dau=(sum(dau_users) / len(dau_users)) if dau_users else None,
        avg_d1=_avg(d1_vals),
        avg_d7=_avg(d7_vals),
        avg_d30=_avg(d30_vals),
    )

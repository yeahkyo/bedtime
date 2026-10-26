"""Unit tests for DAU / D1/D7/D30 engagement math."""

from datetime import date, timedelta

from app.services.analytics_engagement import (
    MAX_ENGAGEMENT_RANGE_DAYS,
    clamp_engagement_range,
    compute_engagement,
)


def test_clamp_engagement_range_swaps_and_caps():
    start, end = clamp_engagement_range(date(2026, 1, 10), date(2026, 1, 1))
    assert start == date(2026, 1, 1)
    assert end == date(2026, 1, 10)

    long_end = date(2026, 10, 1)
    long_start = long_end - timedelta(days=200)
    start, end = clamp_engagement_range(long_start, long_end)
    assert end == long_end
    assert (end - start).days + 1 == MAX_ENGAGEMENT_RANGE_DAYS


def test_dau_and_retention_rates():
    # Cohort Oct 1: users 1,2 — both return on Oct 2; only 1 on Oct 8; none on Oct 31
    # Cohort Oct 2: user 1 only
    user_days = {
        (1, date(2026, 10, 1)),
        (2, date(2026, 10, 1)),
        (1, date(2026, 10, 2)),
        (2, date(2026, 10, 2)),
        (1, date(2026, 10, 8)),
    }
    as_of = date(2026, 11, 15)
    result = compute_engagement(
        user_days,
        date(2026, 10, 1),
        date(2026, 10, 2),
        as_of=as_of,
    )
    assert [p.users for p in result.dau] == [2, 2]

    c0 = result.retention[0]
    assert c0.cohort_size == 2
    assert c0.d1 == 1.0
    assert c0.d7 == 0.5
    assert c0.d30 == 0.0

    c1 = result.retention[1]
    assert c1.cohort_size == 2
    assert c1.d1 == 0.0  # no activity on Oct 3
    assert c1.d7 == 0.0  # Oct 2+7 = Oct 9; only Oct 8 in data
    assert c1.d30 == 0.0

    assert result.avg_dau == 2.0
    assert result.avg_d1 == 0.5  # (1.0 + 0.0) / 2


def test_immature_retention_is_null():
    user_days = {(1, date(2026, 10, 20))}
    as_of = date(2026, 10, 22)  # only D1 mature
    result = compute_engagement(
        user_days,
        date(2026, 10, 20),
        date(2026, 10, 20),
        as_of=as_of,
    )
    c = result.retention[0]
    assert c.d1 == 0.0
    assert c.d7 is None
    assert c.d30 is None
    assert result.avg_d7 is None
    assert result.avg_d30 is None

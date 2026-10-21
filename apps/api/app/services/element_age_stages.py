"""Developmental age stages for story-element catalog (filter + generation)."""

from __future__ import annotations

from typing import Any

# Erikson / childhood framing. No dedicated infant stage (<2 uses toddler pool).
AGE_STAGES: dict[str, dict[str, Any]] = {
    "toddler_2_3": {
        "id": "toddler_2_3",
        "label_zh": "幼儿期（约2–3岁）",
        "label_en": "Toddler 2–3",
        "min_age_years": 2,
        "max_age_years": 3,
        "target_share": 0.20,
        "theory_hint": (
            "感觉运动后期与象征萌芽；安全依恋与身体掌控（Erikson: 自主 vs 羞怯）。"
            "条目宜具体、可指可摸、短时观察，避免抽象规则。"
        ),
    },
    "preschool_3_5": {
        "id": "preschool_3_5",
        "label_zh": "学前期（约3–5岁）",
        "label_en": "Preschool 3–5",
        "min_age_years": 3,
        "max_age_years": 5,
        "target_share": 0.40,
        "theory_hint": (
            "前运算阶段与主动探索（Erikson: 主动 vs 内疚）。"
            "可理解简单因果、角色扮演、情绪命名；仍忌抽象道德说教。"
        ),
    },
    "early_school_6_8": {
        "id": "early_school_6_8",
        "label_zh": "学龄初期（约6–8岁）",
        "label_en": "Early school 6–8",
        "min_age_years": 6,
        "max_age_years": 8,
        "target_share": 0.25,
        "theory_hint": (
            "具体运算萌芽与能力感（Erikson: 勤奋 vs 自卑）。"
            "可接触更清晰的机制、公平萌芽、他人视角；仍保持可观察、可举例。"
        ),
    },
    "late_school_9_12": {
        "id": "late_school_9_12",
        "label_zh": "学龄中期（约9–12岁）",
        "label_en": "Middle school age 9–12",
        "min_age_years": 9,
        "max_age_years": 12,
        "target_share": 0.15,
        "theory_hint": (
            "具体运算巩固，形式运算萌芽；同伴比较与能力感加深。"
            "可写更细的机制、分类与系统关系、简单假设验证；仍保持可观察实例，禁止抽象说教。"
        ),
    },
}

AGE_STAGE_IDS = tuple(AGE_STAGES.keys())


def age_stage_for_years(age_years: int) -> str:
    """Map whole years to the primary developmental stage for filtering."""
    y = max(0, int(age_years))
    if y < 3:
        # No infant catalog: 0–2 share toddler pool.
        return "toddler_2_3"
    if y < 6:
        return "preschool_3_5"
    if y < 9:
        return "early_school_6_8"
    return "late_school_9_12"


def stages_matching_years(age_years: int) -> list[str]:
    """Stages whose year window contains the child (inclusive).

    Clamps below catalog floor to toddler and above ceiling to late school
    so 0–1 and 13+ still get a pool without a dedicated infant stage.
    """
    y = max(0, int(age_years))
    if y < 2:
        y = 2
    if y > 12:
        y = 12
    return [
        sid
        for sid, meta in AGE_STAGES.items()
        if int(meta["min_age_years"]) <= y <= int(meta["max_age_years"])
    ]


def list_age_stages() -> list[dict[str, Any]]:
    return [
        {
            "id": m["id"],
            "label_zh": m["label_zh"],
            "label_en": m["label_en"],
            "min_age_years": m["min_age_years"],
            "max_age_years": m["max_age_years"],
            "target_share": m["target_share"],
            "theory_hint": m["theory_hint"],
        }
        for m in AGE_STAGES.values()
    ]


def suggested_counts(total: int) -> dict[str, int]:
    """Split a target inventory across stages by target_share (remainder → preschool)."""
    total = max(0, int(total))
    raw = {
        sid: int(total * float(AGE_STAGES[sid]["target_share"]))
        for sid in AGE_STAGE_IDS
    }
    assigned = sum(raw.values())
    rem = total - assigned
    if rem and "preschool_3_5" in raw:
        raw["preschool_3_5"] += rem
    return raw

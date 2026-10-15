from app.providers.base import StoryRequest
from app.providers.story_prompt import (
    BEAT_PATTERNS,
    PLAN_SYSTEM_PROMPT,
    SERIES_OUTLINE_SYSTEM_PROMPT,
    SYSTEM_PROMPT,
    build_outline_user_message,
    build_plan_user_message,
    build_series_opening_note,
    build_user_message,
    build_user_payload,
    choose_development_focus,
    clamp_episode_count,
    ensure_soft_hook_in_body,
    focus_from_series_outline,
    select_beat_pattern,
    select_cast_intro_mode,
    select_opening_pattern,
    estimate_length_target,
    get_age_spec,
    merge_keywords,
    normalize_age_band,
    normalize_dial,
    parse_json_object,
    resolve_style_dials,
    slice_series_context,
    validate_episode_plan,
)


def test_normalize_age_band():
    assert normalize_age_band("3-5") == "3-5"
    assert normalize_age_band("3–5") == "3-5"
    assert normalize_age_band("preschool") == "3-5"
    assert normalize_age_band("2") == "2-3"
    assert normalize_age_band("unknown") == "3-5"


def test_age_guidance_is_soft():
    spec = get_age_spec("3-5")
    assert "主线" in spec.guidance or "口语" in spec.guidance


def test_merge_keywords_dedupes_and_caps():
    merged = merge_keywords(
        ["小兔子玩偶", "奶奶", "小兔子玩偶"],
        ["火车", "奶奶"],
        limit=10,
    )
    assert merged == ["小兔子玩偶", "奶奶", "火车"]


def test_focus_stable_for_same_inputs():
    a = choose_development_focus("3-5", "粉色秋千", salt="豆豆")
    b = choose_development_focus("3-5", "粉色秋千", salt="豆豆")
    assert a == b


def test_normalize_dial_defaults():
    assert normalize_dial("plot_drive", None) == "light"
    assert normalize_dial("plot_drive", "arc") == "arc"
    assert normalize_dial("plot_drive", "nope") == "light"
    assert normalize_dial("lead_in", None) == "soft"
    assert normalize_dial("lead_in", "curious") == "curious"


def test_oral_and_lead_in_in_system_prompt():
    assert "听感" in SYSTEM_PROMPT
    assert "一句一事" in SYSTEM_PROMPT
    assert "story_plan" in SYSTEM_PROMPT
    assert "听前开场白" in SYSTEM_PROMPT
    assert "播客" in SYSTEM_PROMPT
    assert "[pause:short]" in SYSTEM_PROMPT
    assert "cast_spine" in SERIES_OUTLINE_SYSTEM_PROMPT
    assert "catchphrase" in SERIES_OUTLINE_SYSTEM_PROMPT
    assert "禁止把终集 focus_id 设为 wind_down" in SERIES_OUTLINE_SYSTEM_PROMPT
    assert "beat_pattern" in PLAN_SYSTEM_PROMPT
    assert "升级或转变" in PLAN_SYSTEM_PROMPT
    assert "听前开场白" in PLAN_SYSTEM_PROMPT
    assert "try_1" in PLAN_SYSTEM_PROMPT
    assert "cast_use" in PLAN_SYSTEM_PROMPT


def test_focus_from_series_outline():
    outline = {
        "episodes": [
            {"episode_no": 1, "focus_id": "tiny_brave", "focus_how": "挥挥手"},
            {"episode_no": 2, "focus_id": "emotion_held", "focus_how": "被软光牵住"},
        ]
    }
    fid, how = focus_from_series_outline(outline, 2, age_band="3-5")
    assert fid == "emotion_held"
    assert "软光" in (how or "")
    assert focus_from_series_outline(None, 1) == (None, None)


def test_select_beat_pattern_stable_and_mapped():
    a = select_beat_pattern("tiny_brave", episode_no=1, salt="豆豆")
    b = select_beat_pattern("tiny_brave", episode_no=1, salt="豆豆")
    assert a == b
    assert a["id"] in ("two_gates", "threshold", "helper_earned")
    assert a.get("lineage")
    assert "升级或转变" in a["instruction"]
    settle = select_beat_pattern("wind_down", episode_no=2, salt="x")
    assert settle["id"] in ("settle_ladder", "home_and_back", "echo_shift")


def test_select_beat_pattern_prefers_theme_tags():
    # 「钥匙」应偏向 misused_gift（寓言礼物框）
    picked = select_beat_pattern(
        "gentle_agency",
        theme="一把会发光的小钥匙",
        episode_no=1,
        salt="theme-key",
    )
    assert picked["id"] in BEAT_PATTERNS
    # theme-matched pool for 钥匙 includes misused_gift; selection may still rotate
    # among options that include theme hits — assert lineage variety exists
    assert picked["lineage"] in ("fairy", "fable", "folk", "drama", "ritual")
    forest = select_beat_pattern(
        "tiny_brave",
        theme="黑森林里的小火车",
        episode_no=1,
        salt="forest-train",
    )
    assert forest["id"] in ("two_gates", "threshold", "helper_earned", "home_and_back")


def test_select_opening_and_cast_intro():
    none = select_opening_pattern("none", episode_no=1, salt="a")
    assert none["id"] == "none"
    curious = select_opening_pattern("curious", episode_no=1, salt="岛岛")
    assert curious["id"] in ("call_question", "gentle_wonder", "familiar_anomaly")
    assert curious["opening_kind"] in ("curiosity", "scene")
    absent = select_opening_pattern(
        "soft", episode_no=1, child_cast_absent=True, salt="x"
    )
    assert absent["id"] != "ritual_soft"
    assert select_cast_intro_mode(soft_series_mode=True, episode_no=1)["id"] == "full_intro"
    assert select_cast_intro_mode(soft_series_mode=False, episode_no=1)["id"] == "full_intro"
    assert select_cast_intro_mode(soft_series_mode=True, episode_no=3)["id"] == "light_refresh"


def test_ensure_soft_hook_in_body():
    body = "小羊睡着了。"
    out = ensure_soft_hook_in_body(body, "明天跟着萤火虫去找软草地。")
    assert "明天跟着萤火虫" in out
    already = ensure_soft_hook_in_body(
        "明天跟着萤火虫去找软草地。然后睡。", "明天跟着萤火虫去找软草地。"
    )
    assert already.count("明天跟着萤火虫") == 1


def test_deep_wind_softens_curious_lead():
    req = StoryRequest(
        child_nickname="豆豆",
        age_band="3-5",
        language="zh",
        theme="月亮",
        duration_minutes=5,
        wind_down="deep",
        lead_in="curious",
    )
    dials = resolve_style_dials(req)
    assert dials["lead_in"]["level"] == "soft"


def test_series_opening_note_with_recap():
    req = StoryRequest(
        child_nickname="豆豆",
        age_band="3-5",
        language="zh",
        theme="秋千",
        duration_minutes=5,
        recap="上次小兔子修好了秋千",
        soft_series_mode=True,
    )
    note = build_series_opening_note(req)
    assert note is not None
    assert "回顾" in note
    payload = build_user_payload(req)
    assert payload["series_opening_note"] is not None
    assert payload["style_dials"]["lead_in"]["level"] == "soft"


def test_mood_rich_soft_guard():
    req = StoryRequest(
        child_nickname="豆豆",
        age_band="3-5",
        language="zh",
        theme="月亮",
        duration_minutes=5,
        plot_drive="mood",
        imagery="rich",
    )
    dials = resolve_style_dials(req)
    assert dials["plot_drive"]["level"] == "mood"
    assert dials["imagery"]["level"] == "balanced"


def test_length_target_zh_vs_en():
    zh = estimate_length_target("zh", 5)
    en = estimate_length_target("en", 5)
    assert zh["unit"] == "chars"
    assert en["unit"] == "words"
    assert zh["target"] == 5 * 230
    assert en["target"] == 5 * 130
    assert zh["min"] < zh["target"] < zh["max"]
    assert zh["target"] != en["target"]


def test_user_payload_includes_style_dials_and_length():
    req = StoryRequest(
        child_nickname="豆豆",
        age_band="3-5",
        language="zh",
        theme="月亮探险",
        duration_minutes=3,
        keywords=["星星娃娃"],
        child_cast_role="absent",
        plot_drive="arc",
        imagery="sparse",
        wonder="fantasy",
        wind_down="playful",
        dialogue="more",
        lead_in="curious",
        development_focus="tiny_brave",
        development_focus_label="小小勇敢",
    )
    payload = build_user_payload(req)
    assert payload["style_dials"]["plot_drive"]["level"] == "arc"
    assert "障碍" in payload["style_dials"]["plot_drive"]["instruction"]
    assert payload["style_dials"]["dialogue"]["level"] == "more"
    assert payload["style_dials"]["lead_in"]["level"] == "curious"
    assert "开场白" in payload["style_dials"]["lead_in"]["instruction"]
    assert "12%" in payload["style_dials"]["lead_in"]["instruction"]
    assert any("开场白" in r for r in payload["style_reminders"])
    assert any("听感" in r or "口语" in r for r in payload["style_reminders"])
    assert "child_profile_guidance" in payload
    assert payload["length_target"]["target"] == 3 * 230
    assert "汉字" in payload["length_target"]["instruction"]
    assert "length_target" in SYSTEM_PROMPT
    assert "星星娃娃" in build_user_message(req)


def test_slice_series_context_episode():
    outline = {
        "title": "小灯系列",
        "throughline": "找到暖光",
        "threads": [{"id": "t1", "what": "小灯", "payoff_episode": 3}],
        "cast_spine": ["豆豆"],
        "episodes": [
            {"episode_no": 1, "premise": "遇见灯", "soft_promise": "灯会怎样", "plants": ["灯闪一下"], "payoffs": []},
            {"episode_no": 2, "premise": "跟着走", "soft_promise": "路通向哪", "plants": [], "payoffs": []},
            {"episode_no": 3, "premise": "暖光", "soft_promise": "", "plants": [], "payoffs": ["灯亮了"]},
        ],
    }
    ctx = slice_series_context(outline, 2)
    assert ctx["episode_no"] == 2
    assert ctx["episode"]["premise"] == "跟着走"
    assert ctx["is_finale"] is False
    assert slice_series_context(outline, 3)["is_finale"] is True


def test_plan_message_embeds_series_context():
    outline = {
        "title": "系列",
        "throughline": "x",
        "threads": [],
        "episodes": [
            {"episode_no": 1, "premise": "p1", "soft_promise": "q1", "plants": [], "payoffs": []},
            {"episode_no": 2, "premise": "p2", "soft_promise": "q2", "plants": ["a"], "payoffs": []},
        ],
    }
    req = StoryRequest(
        child_nickname="豆豆",
        age_band="3-5",
        language="zh",
        theme="森林",
        duration_minutes=5,
        soft_series_mode=True,
        series_outline=outline,
        episode_no=2,
    )
    msg = build_plan_user_message(req)
    assert "series_context" in msg
    assert "跟着走" not in msg  # premise of ep2 is p2
    assert "p2" in msg
    assert "beat_pattern" in msg


def test_lead_in_none_forces_empty_promise():
    plan = validate_episode_plan(
        {
            "wish": "玩",
            "snag": "",
            "try_beat": "试",
            "turn_ok": "好",
            "soft_promise": "不该留下",
            "opening_kind": "curiosity",
            "sleep_beat": "睡",
            "title_hint": "题",
        },
        lead_in="none",
    )
    assert plan["opening_kind"] == "none"
    assert plan["soft_promise"] == ""
    assert plan["try_1"]
    assert plan["try_2"]
    # Do not inject canned goodnight prose when model omits 晚安.
    assert plan["sleep_beat"] == "睡"
    assert "晚安，一点点" not in plan["sleep_beat"]


def test_validate_plan_never_injects_canned_spoken_lines():
    plan = validate_episode_plan(
        {
            "wish": "找碗",
            "snag": "太暗",
            "try_1": "",
            "try_2": "",
            "try_beat": "",
            "turn_ok": "摸到了",
            "soft_promise": "今晚想弄明白小猫在找什么",
            "opening_kind": "curiosity",
            "sleep_beat": "慢慢闭上眼",
            "title_hint": "小猫",
            "opening_lines": "",
        },
        lead_in="curious",
    )
    assert "晚安，一点点" not in plan["sleep_beat"]
    assert "晚安，今晚" not in plan["sleep_beat"]
    assert plan["sleep_beat"] == "慢慢闭上眼"
    assert plan["opening_lines"] == ""
    assert "试一试" not in plan["try_1"]
    assert "再轻轻试一次" not in plan["try_2"]
    assert plan["try_1"] == "找碗"  # from wish, not a canned filler
    assert plan["try_2"] == "摸到了"


def test_validate_plan_series_soft_hook_fallback():
    plan = validate_episode_plan(
        {
            "wish": "跟萤火虫走",
            "snag": "草太高",
            "try_1": "踮脚看",
            "try_2": "晃草穗",
            "turn_ok": "光牵蹄尖",
            "soft_promise": "明天找软草地",
            "opening_kind": "recap",
            "sleep_beat": "晚安小羊，晚安光。",
            "title_hint": "软光",
            "soft_hook_hint": "",
        },
        lead_in="soft",
        soft_series_mode=True,
        beat_pattern=select_beat_pattern("emotion_held", episode_no=2, salt="a"),
    )
    assert plan["soft_hook_hint"] == "明天找软草地"
    assert plan["beat_pattern"]


def test_validate_forces_opening_kind_from_pattern():
    opening = select_opening_pattern("curious", episode_no=1, salt="z")
    plan = validate_episode_plan(
        {
            "wish": "w",
            "snag": "s",
            "try_1": "a",
            "try_2": "b",
            "turn_ok": "ok",
            "soft_promise": "今晚有一点点好奇",
            "opening_kind": "scene",
            "sleep_beat": "晚安草，晚安光。",
            "title_hint": "t",
            "opening_lines": "",
        },
        lead_in="curious",
        opening_pattern=opening,
        cast_intro_mode=select_cast_intro_mode(soft_series_mode=True, episode_no=1),
    )
    assert plan["opening_kind"] == opening["opening_kind"]
    # opening_lines stay empty if model omitted them — do not copy soft_promise in.
    assert plan["opening_lines"] == ""
    assert plan["cast_intro_mode"] == "full_intro"


def test_draft_message_includes_story_plan():
    req = StoryRequest(
        child_nickname="豆豆",
        age_band="3-5",
        language="zh",
        theme="月亮",
        duration_minutes=5,
        child_gender="girl",
        child_intro="喜欢小兔子",
    )
    plan = {
        "wish": "摸月亮",
        "snag": "够不着",
        "try_beat": "踮脚",
        "turn_ok": "看见倒影",
        "soft_promise": "月亮会怎样",
        "opening_kind": "curiosity",
        "opening_pattern": "gentle_wonder",
        "opening_lines": "安顿听者；点出月亮窗边；轻提今晚会看见什么",
        "plants_tonight": [],
        "payoffs_tonight": [],
        "places": ["窗边"],
        "cast": ["豆豆"],
        "sleep_beat": "闭上眼",
        "title_hint": "窗边的月亮",
        "soft_hook_hint": "",
    }
    msg = build_user_message(req, plan)
    assert "story_plan" in msg
    assert "摸月亮" in msg
    assert "听前开场白" in msg
    assert "warm_up_host_voice" in msg
    assert "must_land_warm_up_before_plot" in msg
    assert "land_try_beats_as_planned" in msg
    assert "try_escalation_required" not in msg
    assert "child_profile_guidance" in msg
    assert "女孩" in msg or "偏女孩" in msg


def test_child_profile_guidance_in_payload():
    from app.providers.story_prompt import build_child_profile_guidance

    g = build_child_profile_guidance(
        gender="boy", intro="爱挖机", nickname="悠悠"
    )
    assert "男孩" in g
    assert "轻点" in g
    assert "悠悠" in g


def test_outline_user_message_has_count():
    req = StoryRequest(
        child_nickname="豆豆",
        age_band="3-5",
        language="zh",
        theme="秋千",
        duration_minutes=5,
        episode_count=5,
        need_series_outline=True,
    )
    msg = build_outline_user_message(req)
    assert "5" in msg or '"episode_count": 5' in msg
    assert clamp_episode_count(99) == 8


def test_parse_json_object_fenced():
    data = parse_json_object('```json\n{"a": 1}\n```')
    assert data["a"] == 1

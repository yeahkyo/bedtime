import json

from app.providers.base import StoryRequest
from app.providers.story_prompt import (
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
    STORY_SHAPES,
    select_cast_intro_mode,
    select_opening_pattern,
    estimate_length_target,
    length_range_for_llm,
    max_tokens_for_story,
    get_age_spec,
    merge_keywords,
    normalize_age_band,
    normalize_dial,
    parse_json_object,
    resolve_style_dials,
    slice_series_context,
    validate_episode_plan,
)
from app.services.story_shapes import apply_seed_fallback


apply_seed_fallback()


def _sample_plan(**overrides):
    base = {
        "title": "窗边光",
        "theme": "一点暖光也能安心",
        "casts": [{"name": "小羊", "desc": "夜里爱跺蹄找光的小羊"}],
        "beats": [
            "小羊望着窗外的光",
            "草挡住了路",
            "小羊绕到旁边轻轻拨草",
            "小羊靠着草坐下",
        ],
        "shape": "离家一点点再回家",
    }
    base.update(overrides)
    return base


def test_normalize_age_band():
    assert normalize_age_band("3-5") == "3-5"
    assert normalize_age_band("3–5") == "3-5"
    assert normalize_age_band("preschool") == "3-5"
    assert normalize_age_band("2") == "2-3"
    assert normalize_age_band("9-12") == "9-12"
    assert normalize_age_band("10") == "9-12"
    assert normalize_age_band("unknown") == "3-5"


def test_age_spec_and_focus_pool_9_12():
    spec = get_age_spec("9-12")
    assert spec.band == "9-12"
    assert "因果" in spec.guidance or "选择" in spec.guidance
    fid, _ = choose_development_focus("9-12", "星空", salt="豆豆")
    assert fid in {
        "try_persist",
        "friend_repair",
        "mentalize_light",
        "curious_cause",
        "own_choice",
    }


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


def test_audiences_and_roster_in_plan_payload():
    req = StoryRequest(
        child_nickname="豆豆",
        age_band="3-5",
        language="zh",
        theme="月亮",
        duration_minutes=5,
        audiences=[
            {
                "name": "豆豆",
                "age": 4,
                "gender": "女孩",
                "prefer": "跳舞、恐龙",
            }
        ],
        roster=[{"name": "小灯", "desc": "会发光的灯"}],
        episode_no=1,
    )
    payload = build_user_payload(req)
    assert "keywords" not in payload
    assert payload["audiences"][0]["prefer"] == "跳舞、恐龙"
    assert payload["roster"][0]["name"] == "小灯"
    plan = json.loads(build_plan_user_message(req))
    assert "audiences" in plan
    assert "fantasy" in plan
    assert "keywords" not in plan
    assert "age" not in plan
    assert "gender" not in plan
    assert plan["audiences"][0]["age"] == 4


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
    assert "开篇的垫话" in SYSTEM_PROMPT
    assert "dialog" in SYSTEM_PROMPT
    assert "casts" in SYSTEM_PROMPT
    assert "wish/snag" not in SYSTEM_PROMPT
    assert '"cast"' in SERIES_OUTLINE_SYSTEM_PROMPT
    assert '"line"' in SERIES_OUTLINE_SYSTEM_PROMPT
    assert "禁止把终集 focus 设为 wind_down" in SERIES_OUTLINE_SYSTEM_PROMPT
    assert "fantasy" in PLAN_SYSTEM_PROMPT
    assert "len" in PLAN_SYSTEM_PROMPT
    assert "roster" in PLAN_SYSTEM_PROMPT
    assert "roster" not in SYSTEM_PROMPT
    assert "casts" in PLAN_SYSTEM_PROMPT
    assert "casts" in SYSTEM_PROMPT
    assert "wish / snag" not in PLAN_SYSTEM_PROMPT
    assert "tonight_theme_pref" not in PLAN_SYSTEM_PROMPT
    assert "dials.wonder" not in PLAN_SYSTEM_PROMPT
    assert "dials.wonder" in SERIES_OUTLINE_SYSTEM_PROMPT
    assert "body:" in SYSTEM_PROMPT or "body：" in SYSTEM_PROMPT


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


def test_select_beat_pattern_stable_and_avoids_recent():
    a = select_beat_pattern("tiny_brave", episode_no=1, salt="豆豆")
    b = select_beat_pattern("tiny_brave", episode_no=1, salt="豆豆")
    assert a == b
    assert a["story_shape"] in STORY_SHAPES
    assert a["id"] == a["story_shape"]
    assert a.get("beat_min") and a.get("beat_max")
    assert a["beat_min"] <= a["beat_max"]

    avoided = select_beat_pattern(
        "wind_down", episode_no=3, salt="x", recent_shapes=["binary_op", "helper"]
    )
    assert avoided["story_shape"] not in ("binary_op", "helper")
    assert avoided["story_shape"] in STORY_SHAPES


def test_select_beat_pattern_ignores_theme_bias():
    # Theme/focus no longer shrink the shape pool; still returns a valid shape.
    picked = select_beat_pattern(
        "gentle_agency",
        theme="一把会发光的小钥匙",
        episode_no=1,
        salt="theme-key",
    )
    assert picked["story_shape"] in STORY_SHAPES


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


def test_length_band_product_tiers():
    from app.providers.story_prompt import canonicalize_duration_minutes

    assert canonicalize_duration_minutes(3) == 3
    assert canonicalize_duration_minutes(4) == 3
    assert canonicalize_duration_minutes(5) == 5
    assert canonicalize_duration_minutes(7) == 5
    assert canonicalize_duration_minutes(8) == 10
    assert canonicalize_duration_minutes(12) == 10

    # UI listen copy unchanged; LLM len uses reference minutes ±1 @ 220 chars/min
    zh3 = estimate_length_target("zh", 3)
    assert zh3["listen_minutes_min"] == 2 and zh3["listen_minutes_max"] == 4
    assert zh3["reference_minutes"] == 4
    assert zh3["target"] == 880
    assert zh3["min"] == 660
    assert zh3["max"] == 1100
    assert length_range_for_llm("zh", 3) == "660-1100"
    zh5 = estimate_length_target("zh", 5)
    assert zh5["reference_minutes"] == 7
    assert zh5["min"] == 1320
    assert zh5["max"] == 1760
    assert length_range_for_llm("zh", 5) == "1320-1760"
    zh10 = estimate_length_target("zh", 10)
    assert zh10["reference_minutes"] == 10
    assert zh10["min"] == 1980
    assert zh10["max"] == 2420
    assert estimate_length_target("zh", 8)["duration_minutes"] == 10
    en5 = estimate_length_target("en", 5)
    assert en5["unit"] == "words"
    assert en5["reference_minutes"] == 7
    assert en5["min"] == 600
    assert en5["max"] == 800
    zh5_tok = max_tokens_for_story("zh", 5)
    zh10_tok = max_tokens_for_story("zh", 10)
    assert zh5_tok >= 1024
    assert zh10_tok > zh5_tok
    assert "下限-上限" in SYSTEM_PROMPT
    assert "minutes：" not in SYSTEM_PROMPT


def test_user_payload_includes_style_dials_and_len_band():
    req = StoryRequest(
        child_nickname="豆豆",
        age_band="3-5",
        language="zh",
        theme="月亮探险",
        duration_minutes=3,
        audiences=[{"name": "豆豆", "age": 4}],
        roster=[{"name": "星星娃娃"}],
        child_cast_role="absent",
        plot_drive="arc",
        imagery="sparse",
        wonder="fantasy",
        wind_down="playful",
        dialogue="more",
        lead_in="curious",
        development_focus="tiny_brave",
        development_focus_label="勇气",
    )
    payload = build_user_payload(req)
    assert payload["tonight_focus"]["id"] == "tiny_brave"
    assert payload["tonight_focus"]["axis"] == "courage"
    assert payload["tonight_focus"]["axis_label"] == "勇气"
    assert "how" not in payload["tonight_focus"]
    assert payload["style_dials"]["plot_drive"]["level"] == "arc"
    assert "障碍" in payload["style_dials"]["plot_drive"]["instruction"]
    assert payload["style_dials"]["wonder"]["level"] == "fantasy"
    assert payload["style_dials"]["wonder"]["label"] == "更幻想"
    assert "想象" in payload["style_dials"]["wonder"]["instruction"]
    assert payload["style_dials"]["dialogue"]["level"] == "more"
    assert payload["style_dials"]["lead_in"]["level"] == "curious"
    assert "开场白" in payload["style_dials"]["lead_in"]["instruction"]
    assert "12%" in payload["style_dials"]["lead_in"]["instruction"]
    assert any("开场白" in r for r in payload["style_reminders"])
    assert any("听感" in r or "口语" in r for r in payload["style_reminders"])
    assert "audiences" in payload
    assert "roster" in payload
    assert payload["duration_minutes"] == 3
    band = length_range_for_llm("zh", 3)
    plan_msg = build_plan_user_message(req)
    assert "星星娃娃" in plan_msg
    assert '"fantasy": 5' in plan_msg
    assert '"minutes"' not in plan_msg
    plan = json.loads(plan_msg)
    assert plan["len"] == band
    draft_msg = build_user_message(req, _sample_plan())
    assert '"dialog": 5' in draft_msg
    draft = json.loads(draft_msg)
    assert draft["len"] == band
    assert "audiences" in draft
    assert "roster" not in draft
    assert "星星娃娃" not in draft_msg


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
    assert ctx["ep"] == 2
    assert ctx["ep_data"]["premise"] == "跟着走"
    assert ctx["finale"] is False
    assert slice_series_context(outline, 3)["finale"] is True
    assert ctx["arc"] == "找到暖光"
    assert ctx["threads"][0]["at"] == 3


def test_plan_message_is_simplified_schema():
    req = StoryRequest(
        child_nickname="豆豆",
        age_band="3-5",
        language="zh",
        theme="森林",
        duration_minutes=5,
        audiences=[{"name": "豆豆", "age": 4, "gender": "女孩"}],
        roster=[{"name": "小兔子"}],
        wonder="soft",
        soft_series_mode=True,
        episode_no=2,
    )
    msg = build_plan_user_message(req)
    payload = json.loads(msg)
    assert set(payload) == {
        "theme",
        "audiences",
        "roster",
        "fantasy",
        "len",
    }
    assert payload["theme"] == "森林"
    assert payload["audiences"][0]["name"] == "豆豆"
    assert payload["roster"][0]["name"] == "小兔子"
    assert payload["fantasy"] == 3
    assert payload["len"] == length_range_for_llm("zh", 5)
    assert "series" not in payload
    assert "dials" not in payload
    assert "age" not in payload
    assert "gender" not in payload



def test_normalize_audiences_maps_gender_token_by_story_language():
    from datetime import date

    from app.api.stories import _normalize_audiences
    from app.models.child import Child
    from app.schemas.common import AudienceItem, StoryCreate

    child = Child(
        user_id=1,
        nickname="豆豆",
        birth_date=date(2020, 1, 1),
        gender="boy",
    )
    body_zh = StoryCreate(
        child_id=1,
        theme="月亮",
        language="zh",
        audiences=[AudienceItem(name="豆豆", age=4, gender="girl")],
    )
    out_zh = _normalize_audiences(body_zh, child)
    assert out_zh[0]["gender"] == "女孩"

    body_en = StoryCreate(
        child_id=1,
        theme="moon",
        language="en",
        audiences=[AudienceItem(name="Ada", age=5, gender="boy")],
    )
    out_en = _normalize_audiences(body_en, child)
    assert out_en[0]["gender"] == "boy"

    # Legacy Chinese label still accepted and remapped for English stories.
    body_legacy = StoryCreate(
        child_id=1,
        theme="moon",
        language="en",
        audiences=[AudienceItem(name="Ada", age=5, gender="女孩")],
    )
    out_legacy = _normalize_audiences(body_legacy, child)
    assert out_legacy[0]["gender"] == "girl"


def test_prompt_age_years_falls_back_to_band():
    from app.providers.story_prompt import prompt_age_years, prompt_gender_label

    req = StoryRequest(
        child_nickname="豆豆",
        age_band="6-8",
        language="zh",
        theme="月亮",
        duration_minutes=5,
        child_gender="boy",
    )
    assert prompt_age_years(req) == 7
    assert prompt_gender_label(req) == "男孩"
    req_en = StoryRequest(
        child_nickname="Ada",
        age_band="3-5",
        language="en",
        theme="moon",
        duration_minutes=5,
        child_gender="girl",
        child_age_years=5,
    )
    assert prompt_age_years(req_en) == 5
    assert prompt_gender_label(req_en) == "girl"


def test_tonight_focus_drops_legacy_soft_guidance_label():
    req = StoryRequest(
        child_nickname="豆豆",
        age_band="3-5",
        language="zh",
        theme="好奇",
        duration_minutes=5,
        development_focus="curious_cause",
        development_focus_label=(
            "让一个具体疑问像小气泡一样在场景里冒出来，禁止点题说教。"
        ),
    )
    payload = build_user_payload(req)
    assert payload["tonight_focus"]["axis"] == "curiosity"
    assert payload["tonight_focus"]["axis_label"] == "好奇"
    assert "小气泡" not in json.dumps(payload["tonight_focus"], ensure_ascii=False)


def test_validate_accepts_new_plan_schema():
    plan = validate_episode_plan(_sample_plan(core="一点点勇气"))
    assert set(plan) == {"title", "theme", "core", "casts", "beats", "shape"}
    assert plan["core"] == "一点点勇气"
    assert plan["casts"][0]["name"] == "小羊"
    assert plan["casts"][0]["desc"]
    assert isinstance(plan["beats"][0], str)
    assert plan["shape"] == "离家一点点再回家"


def test_validate_accepts_legacy_aliases():
    plan = validate_episode_plan(
        {
            "story_shape": "三段重复",
            "cast": [{"name": "小熊", "move": "揉眼睛", "tonight_does": "躺下"}],
            "beats": [{"n": 1, "action": "揉眼睛"}, {"n": 2, "action": "躺下"}],
            "title_hint": "睡",
            "theme": "困倦",
        }
    )
    assert plan["title"] == "睡"
    assert plan["shape"] == "三段重复"
    assert plan["casts"][0]["name"] == "小熊"
    assert "躺下" in plan["casts"][0]["desc"]
    assert plan["beats"] == ["揉眼睛", "躺下"]


def test_validate_plan_is_lean():
    plan = validate_episode_plan(
        _sample_plan(title="窗边", theme="光"),
        story_element={"id": "el1", "name": "小灯"},
    )
    assert set(plan.keys()) == {"title", "theme", "core", "casts", "beats", "shape"}
    assert plan["core"] is None
    assert "eid" not in plan
    assert "hook" not in plan
    assert "setting" not in plan


def test_validate_plan_requires_beat_text():
    plan = validate_episode_plan(_sample_plan())
    assert plan["beats"][0]
    assert plan["casts"][0]["name"] == "小羊"


def test_validate_plan_core_alias_and_truncate():
    plan = validate_episode_plan(
        _sample_plan(development_focus_label="第一次说对不起" + ("长" * 40))
    )
    assert plan["core"] is not None
    assert plan["core"].startswith("第一次说对不起")
    assert len(plan["core"]) == 32


def test_draft_message_is_flat_outline():
    req = StoryRequest(
        child_nickname="豆豆",
        age_band="3-5",
        language="zh",
        theme="月亮",
        duration_minutes=5,
        dialogue="some",
        child_gender="boy",
        child_age_years=3,
    )
    plan = validate_episode_plan(
        _sample_plan(
            title="窗边的月亮",
            beats=["摸月亮", "踮脚", "看见倒影", "闭上眼"],
        )
    )
    msg = build_user_message(req, plan)
    payload = json.loads(msg)
    assert set(payload) == {
        "title",
        "theme",
        "casts",
        "beats",
        "audiences",
        "dialog",
        "len",
    }
    assert "roster" not in payload
    assert payload["title"] == "窗边的月亮"
    assert "摸月亮" in payload["beats"]
    assert payload["audiences"] == []
    assert payload["dialog"] == 3
    assert payload["len"] == length_range_for_llm("zh", 5)
    assert "plan" not in payload
    assert "check" not in payload
    assert "age" not in payload
    assert "gender" not in payload


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
        wonder="everyday",
    )
    msg = build_outline_user_message(req)
    # Payload is JSON only; task lead lives on Agent user_prompt_template.
    data = json.loads(msg)
    assert data["n"] == 5
    assert "wonder" in data["dials"]
    assert data["dials"]["wonder"]["lv"] == "everyday"
    assert "请为软系列" not in msg
    assert clamp_episode_count(99) == 8


def test_parse_json_object_fenced():
    data = parse_json_object('```json\n{"a": 1}\n```')
    assert data["a"] == 1

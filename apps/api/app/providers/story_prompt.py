"""Bedtime story prompt builder: age guidance, keywords, cast, style dials."""

from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass
from typing import Any

from app.providers.base import StoryRequest

MAX_KEYWORDS_IN_PROMPT = 12

# Parent-facing style dials → concrete LLM instructions (3 levels each).
STYLE_DIALS: dict[str, dict[str, dict[str, str]]] = {
    "plot_drive": {
        "mood": {
            "label": "氛围向",
            "instruction": (
                "以状态与节奏为主，可没有强烈障碍；"
                "用轻微动作与重复推进；不要硬造戏剧冲突。"
            ),
        },
        "light": {
            "label": "轻情节",
            "instruction": (
                "要有一个小愿望和一个小卡住；角色完成两次具体尝试（第一次不够，第二次才更好）；"
                "事情变好后尽快入睡；只要一条线，不要第二条故事。"
            ),
        },
        "arc": {
            "label": "更有故事",
            "instruction": (
                "愿望与障碍写清楚；用两三次推进动作把事做完，中间要有一点延迟；"
                "仍保持单线与今晚情绪闭环；禁止新开第二条支线。"
            ),
        },
    },
    "imagery": {
        "sparse": {
            "label": "干净口述",
            "instruction": (
                "短句；一句一个动作；先说得出名字的东西，再跟动作；"
                "叠词极少（全篇≤1次）；几乎不堆形容词；像低声讲给困倦的孩子听。"
            ),
        },
        "balanced": {
            "label": "适中",
            "instruction": (
                "可用少量可摸可听的身体感（凉、暖、叮一声、脚边）；"
                "叠词全篇≤3次且不反复同一词；禁止排比、长定语与开篇堆修饰；"
                "宁可多一步动作，也不写华丽空句。"
            ),
        },
        "rich": {
            "label": "更细腻",
            "instruction": (
                "可多一点感官，但仍必须是听得见、摸得到、指得着的细节；"
                "禁止排比、景点清单、抽象意境词堆砌；不能用景物代替情节推进。"
            ),
        },
    },
    "lead_in": {
        "none": {
            "label": "直接开讲",
            "instruction": "不要单独开场总领；第一句就进入故事里的人与事。",
        },
        "soft": {
            "label": "轻轻总领",
            "instruction": (
                "正文开头用很短的口述总领（约2～4句，约占全文5%～10%），"
                "帮孩子把注意力转到今晚的故事；然后自然接进正叙。"
                "形态每次自选其一并换着写，禁止固定套话："
                "轻好奇、今晚要弄清的一件小事、把人带进场景的短邀请；"
                "若有 recap/连续故事可加一句上回回顾。"
                "禁止主题宣讲、道德点题、课堂提问腔、吓人硬悬念。"
            ),
        },
        "curious": {
            "label": "好奇开场",
            "instruction": (
                "正文开头用短口述总领（约2～4句），偏轻好奇或今晚要弄明白的小事；"
                "问句不必要求孩子回答；随后马上进入故事动作。"
                "形态要多样，禁止每篇同一句式；禁止说教点题与硬悬念。"
                "若有 recap/连续故事，可先一句回顾再抛出今晚好奇。"
            ),
        },
    },
    "wonder": {
        "everyday": {
            "label": "日常",
            "instruction": "偏现实生活场景与逻辑；最多轻度拟人，不造奇幻世界。",
        },
        "soft": {
            "label": "轻奇幻",
            "instruction": "可有一点点温柔想象（如月亮眨眼、玩具轻声说话）；不写复杂世界观。",
        },
        "fantasy": {
            "label": "更幻想",
            "instruction": "可用更明显的想象设定，但仍单线、安全、今晚安心入睡。",
        },
    },
    "wind_down": {
        "deep": {
            "label": "很快安静",
            "instruction": "前半就降速；冲突极轻；后段几乎只有重复与入睡。",
        },
        "gentle": {
            "label": "先轻轻再睡",
            "instruction": "中段可有一点小起伏，最后约三分之一明显变慢并入睡。",
        },
        "playful": {
            "label": "活泼一点再收",
            "instruction": (
                "前中段可更有动作或轻轻笑意，结尾必须明显减速入睡；"
                "仍禁止惊吓与硬悬念。"
            ),
        },
    },
    "dialogue": {
        "low": {
            "label": "很少对话",
            "instruction": "以旁白动作为主；对话极少（0～2句短话）或不出现。",
        },
        "some": {
            "label": "一点对话",
            "instruction": "可有少量简短对话（大约2～5句），每句很短，像轻声说话。",
        },
        "more": {
            "label": "对话多些",
            "instruction": (
                "可用更多简短对话推进关系或情节，但仍适合口述；"
                "避免长段独白或成人腔。"
            ),
        },
    },
}

DEFAULT_DIALS = {
    "plot_drive": "light",
    "imagery": "balanced",
    "wonder": "soft",
    "wind_down": "gentle",
    "dialogue": "some",
    "lead_in": "soft",
}

# Bedtime listening pace (spoken aloud), not silent reading speed.
# zh: characters/minute; en: words/minute — units differ, must stay separate.
LENGTH_RATES = {
    "zh": {
        "unit": "chars",
        "unit_label": "汉字（含标点近似按字计）",
        "per_minute": 230,
        "tolerance": 0.12,
    },
    "en": {
        "unit": "words",
        "unit_label": "English words",
        "per_minute": 130,
        "tolerance": 0.12,
    },
}


@dataclass(frozen=True)
class AgeSpec:
    band: str
    label_zh: str
    guidance: str


AGE_SPECS: dict[str, AgeSpec] = {
    "2-3": AgeSpec(
        band="2-3",
        label_zh="约2–3岁",
        guidance="更短、更慢；超短句；具体东西+动作；地点要少；适合困倦听。",
    ),
    "3-5": AgeSpec(
        band="3-5",
        label_zh="约3–5岁",
        guidance="一条好懂的主线；短句口语朗读感；可有一点点小担心并很快被安抚。",
    ),
    "6-8": AgeSpec(
        band="6-8",
        label_zh="约6–8岁",
        guidance="清晰主线；口语短句与简短对话；结尾明显安静下来；仍避免书面腔。",
    ),
}

FOCUS_POOLS: dict[str, list[tuple[str, str]]] = {
    "2-3": [
        ("secure_presence", "安心在场：重要的人/陪伴物/声音还在"),
        ("body_rhythm", "身体节奏：拥抱、呼吸变慢、眼皮变沉"),
        ("name_feeling", "轻轻点出感受：困、想抱、暖暖的（不分析）"),
    ],
    "3-5": [
        ("tiny_brave", "小小勇敢：试一下就好，马上被接住"),
        ("emotion_held", "情绪被接住：一点点担心 → 被看见 → 安心"),
        ("gentle_agency", "小小自主：自己做一件很小的事"),
        ("share_space", "给同伴/玩具一点空间（不说教）"),
        ("wind_down", "玩过/看过之后，慢慢安静准备睡觉"),
    ],
    "6-8": [
        ("try_persist", "坚持一下：小小努力后可以休息"),
        ("friend_repair", "小摩擦后和好（双方都不被贬低）"),
        ("fair_turn", "轮流/公平的萌芽"),
        ("mentalize_light", "别人也可能有不一样的小心思，仍友善收场"),
    ],
}

MOTIF_WHITELIST = [
    "小小尝试后安心",
    "重复节奏（像童谣）",
    "日常里的一点温柔神奇",
    "找到温暖或陪伴",
    "一起慢慢变安静",
    "好奇但不吓人的小期待",
]

# Internal beat menus (not shown in App). Algorithm picks; LLM fills slots.
BEAT_PATTERNS: dict[str, dict[str, Any]] = {
    "approach_retry": {
        "label": "靠近再试",
        "slots": "wish, snag, try_1, try_2, turn_ok",
        "instruction": (
            "角色主动靠近或试一次；第一次不够；第二次才更接近成功。"
            "禁止「一露面就被完全安抚、没有主动尝试」。"
        ),
    },
    "wait_signal": {
        "label": "等待约定",
        "slots": "wish, snag, try_1, try_2, turn_ok",
        "instruction": (
            "小目标依赖一个约定信号（风、光、声音等）。"
            "try_1 可以是等待/张望；try_2 是守住约定或轻轻提醒；今晚只推进，不提前兑现季终信号。"
        ),
    },
    "make_and_fix": {
        "label": "动手修好",
        "slots": "wish, snag, try_1, try_2, turn_ok",
        "instruction": (
            "动手布置或制作；第一次弄歪/摆不齐；第二次用角色标志动作修好。"
        ),
    },
    "lost_and_held": {
        "label": "走散被接住",
        "slots": "wish, snag, try_1, try_2, turn_ok",
        "instruction": (
            "有一点点走丢或担心；角色先自己找/叫；再被温柔接住（触感要写到）。"
            "接住是结果，不能替代前面的主动试。"
        ),
    },
    "share_turn": {
        "label": "让一点地方",
        "slots": "wish, snag, try_1, try_2, turn_ok",
        "instruction": (
            "想独占或抢先；第一次不太会让；第二次轻轻让出一点空间或轮流。"
        ),
    },
    "settle_after_play": {
        "label": "玩过再静",
        "slots": "wish, snag, try_1, try_2, turn_ok",
        "instruction": (
            "先有一小段轻玩；再慢慢收；两次收（如放下、盖上、说晚安）而不是突然睡倒。"
        ),
    },
}

# focus_id → preferred beat patterns (rotated by episode salt)
FOCUS_BEAT_MAP: dict[str, list[str]] = {
    "tiny_brave": ["approach_retry", "lost_and_held"],
    "emotion_held": ["lost_and_held", "approach_retry"],
    "gentle_agency": ["make_and_fix", "share_turn"],
    "share_space": ["share_turn", "make_and_fix"],
    "wind_down": ["settle_after_play", "wait_signal"],
    "secure_presence": ["lost_and_held", "settle_after_play"],
    "body_rhythm": ["settle_after_play", "wait_signal"],
    "name_feeling": ["lost_and_held", "settle_after_play"],
    "try_persist": ["approach_retry", "make_and_fix"],
    "friend_repair": ["share_turn", "lost_and_held"],
    "fair_turn": ["share_turn", "make_and_fix"],
    "mentalize_light": ["share_turn", "lost_and_held"],
}

# Internal opening menus (not shown in App).
OPENING_PATTERNS: dict[str, dict[str, Any]] = {
    "none": {
        "label": "直接开讲",
        "opening_kind": "none",
        "instruction": "不要单独总领段；第一句就进入故事里的人与事。",
    },
    "ritual_soft": {
        "label": "轻仪式",
        "opening_kind": "scene",
        "instruction": (
            "用2～3句很软的睡前招呼作总领（可轻唤听者，但 child_cast_role=absent 时禁止点孩子名字）。"
            "禁止每篇同一句「小朋友你一定……」；随后马上进正叙。"
        ),
    },
    "call_question": {
        "label": "呼叫提问",
        "opening_kind": "curiosity",
        "instruction": (
            "总领用轻呼叫/提问拉注意，如「你见过……吗？」「你听……？」「今天……」。"
            "不问课堂题、不要求回答；2～3句后进入故事动作。"
        ),
    },
    "familiar_anomaly": {
        "label": "熟悉反常",
        "opening_kind": "scene",
        "instruction": (
            "总领先点出一个具体小画面，再跟一个轻反常（如捂眼睛、停住脚、草穗歪了）。"
            "2～3句，立刻让人知道「今晚有一点点不一样」。"
        ),
    },
    "gentle_wonder": {
        "label": "温柔疑问",
        "opening_kind": "curiosity",
        "instruction": (
            "总领提出一个低风险小疑问（他们找得到吗？小羊会怎么做呢？），"
            "不制造硬悬念；2～3句后进正叙。"
        ),
    },
}

# lead_in → candidate opening pattern ids
LEAD_OPENING_MAP: dict[str, list[str]] = {
    "none": ["none"],
    "soft": ["familiar_anomaly", "ritual_soft", "gentle_wonder"],
    "curious": ["call_question", "gentle_wonder", "familiar_anomaly"],
}

CAST_INTRO_MODES: dict[str, dict[str, str]] = {
    "full_intro": {
        "label": "完整建档",
        "instruction": (
            "在总领之后、主冲突之前，用2～4句完成建档："
            "每个主要角色一句（名字+一个标志动作或喜好）；"
            "再加一句说明今晚在哪儿、在做什么（接 throughline/本集一小步）。"
            "禁止只扔名字不挂钩。"
        ),
    },
    "light_refresh": {
        "label": "轻点名",
        "instruction": (
            "续集：用一两句带过熟悉角色（可点标志动作），不要重新开世界观；"
            "可接一句上回软期待/recap。"
        ),
    },
    "none": {
        "label": "不另介绍",
        "instruction": "不单独介绍段；姓名随动作自然带出即可（仅短篇续集或 lead_in=none 时）。",
    },
}

SYSTEM_PROMPT = """你是一位会讲睡前故事的家长旁白：写给幼儿**听**的晚安故事（口述朗读感），不是给大人默读的儿童散文。

优先级：睡前安全 > 听感 > 跨集伏笔落地 > 文学辞藻。
教育意义只能潜移默化，绝不能压过入睡。

用户消息里的 style_dials 是家长选择的风格档位：**必须遵守各档位的 instruction**，它们优先于你的默认文风。

口语听感（比「少形容词」更优先）：
- 一句一事；先出现叫得出名字的东西/人，再跟动作。
- 对话一句一个意思；禁止「不是A，是因为B所以C」式绕句。
- 用可摸可听可指的细节（凉、刺一下、叮、沙沙）；少用抽象意境词。
- 可用轻口语（后来、这下、可是、你瞧）；少用书面词：乍一、悬、接话、随着、上方、位置、起伏、耷拉。
- 每段尽量不超过3句；信息别挤在长定语里。
- 每隔几句可有拟声、短重复或呼唤（呼——、沙沙沙、等一等）；禁止用华丽描写凑字。
- 场景里的东西必须参与动作，禁止只写风景观光。

朗读节奏标记（稀疏，全文约4～10个；勿用 markdown）：
- 仅可用：[pause:short] [pause:think] [pause:long] [slow] [soft] [warm]
- 标记只在 body；title/soft_hook 不要标记。没把握可不标。

正文开头结构（必须按 story_plan 落地，顺序固定）：
1) opening_pattern：若非 none，body 最前先写独立总领段（约2～3句），严格遵守 opening_pattern.instruction；再写后面。
2) cast_intro_mode：full_intro 时紧接总领做角色+场景建档；light_refresh 时一两句点名即可；none 可省略。
3) 再进入 wish/snag 与两次尝试。
- lead_in=none 或 opening_pattern=none：不要单独总领。
- 连续故事：recap 一两句即可；禁止冗长前情。
- child_cast_role=absent：全文与总领都不要出现孩子昵称。

若含 story_plan：**必须按计划写**，不要另起炉灶：
- 兑现 wish / snag / try_1 / try_2 / turn_ok（若只有 try_beat 则当试一次，仍要有波折）。
- 角色按 cast_use：每人的标志动作或口头禅至少出现一次并推动情节；首集/单集须让听者听清「谁是谁」。
- places/scene_jobs 里的物要干活。
- plants_tonight 只埋或轻碰；payoffs_tonight 之外不得提前兑现季终大伏笔。
- sleep_beat 必须在正文末段落地：对今晚出现过的2～4个名物/角色说晚安（渐弱），不要只写「睡着了」。
- soft_series_mode 时：正文末段（晚安前）必须有一句可朗读的软期待，语义等于 soft_hook 字段；soft_hook 与正文一致。

底线：
1) 单线；今晚情绪闭环；禁止硬悬念。
2) 安全：禁止暴力、恐怖、抛弃、惩罚恐吓、医疗创伤。
3) 角色按 cast_hint；keywords 不必用尽。
4) 勿默认全篇卧室，也勿景点巡礼。
5) 禁止说教总结与心理学术语；禁止照搬知名作品专有角色名。
6) soft_hook：仅 soft_series_mode=true 时为下一集温和期待一句；否则 null。
7) tonight_focus / beat_pattern 只通过动作体现，不要点题说教。
8) language 以 zh 开头用口语中文；以 en 开头用温柔简单英语。
9) 尽量达到 length_target（朗读约等于 duration_minutes）。
10) 只输出 JSON（不要 markdown）：{"title": string, "body": string, "soft_hook": null 或 string}
"""

SERIES_OUTLINE_SYSTEM_PROMPT = """你是睡前「软系列」叙事策划（不是写正文）。为幼儿设计一小季温和连载大纲。

规则：
1) 每集今晚情绪闭环、可单独安心入睡；跨集只用温和期待，禁止硬悬念。
2) throughline 是整季小目标（如「找到能跳舞的软草地」）；每集 premise 必须是主线的一小步，不能写成无关的偶遇即止。
3) 1～2 条 threads；每条写清 what 与 payoff_episode；非 payoff 集只能埋或轻碰，禁止提前兑现。
4) cast_spine 用对象：每人 name + move（标志动作）+ catchphrase（口头禅，可短）；禁止只有形容词标签。
5) 每集 focus_how 必须是动作级；禁止把终集 focus_id 设为 wind_down；终集也要有今晚情节（可兑现线索）。
6) soft_promise / sleep_note 必须是可直接朗读的短句（不是气氛说明）。
7) plants：本集只埋的线索；payoffs：本集允许轻兑现的（须对照 threads 的 payoff_episode）。
8) 只输出 JSON（不要 markdown），字段短写（≤40字）：
{
  "title": string,
  "throughline": string,
  "cast_spine": [{"name": string, "move": string, "catchphrase": string}],
  "threads": [{"id": string, "what": string, "payoff_episode": number}],
  "episodes": [{
    "episode_no": number,
    "focus_id": string,
    "focus_how": string,
    "premise": string,
    "soft_promise": string,
    "plants": [string],
    "payoffs": [string],
    "sleep_note": string
  }]
}
episodes 长度必须等于 episode_count；episode_no 从 1 连续编号。
字符串内勿用未转义双引号；输出必须是完整可解析 JSON。
"""

PLAN_SYSTEM_PROMPT = """你是睡前故事的单集构思助手（不是写正文）。根据用户设定与 beat_pattern / opening_pattern / cast_intro_mode 产出今晚可执行的短构思 JSON。

规则：
1) 动作级、具体；禁止道德点题与书面空话。
2) 单线；今晚情绪闭环；禁止硬悬念。弱冲突可以，但不能没有节拍：禁止「露面→立刻圆满→睡」。
3) 必须遵守 beat_pattern.instruction，填满其 slots。
4) try_1 与 try_2 都要有：两次具体尝试/等待/收拾；第二次才更接近 turn_ok。禁止只用「被安抚」代替主动试。
5) 必须遵守 opening_pattern：把 opening_kind 设为与其一致；写出 opening_lines（2～3句可朗读总领提纲）。opening_pattern=none 时 opening_lines 为空、opening_kind=none。
6) 必须遵守 cast_intro_mode：full_intro 时 setting_line 写清「今晚在哪儿干什么」，cast_use 每人 how_tonight 含一句身份介绍；light_refresh 时 setting_line 可短；none 时可空。
7) soft_promise：有总领时供总领使用；lead_in/opening 为 none 时 soft_promise 为空。
8) 若有 series_context：wish 对齐 throughline 一小步；plants 只埋/轻碰；非终集不兑季终大伏笔。
9) cast_use：至少两个角色（name, signature_move, line, how_tonight）。
10) sleep_beat：2～4个名物/角色的晚安点名；系列时 soft_hook_hint 必填可朗读句。
11) 只输出 JSON（不要 markdown）：
{
  "beat_pattern": string,
  "opening_pattern": string,
  "cast_intro_mode": string,
  "opening_lines": string,
  "setting_line": string,
  "wish": string,
  "snag": string,
  "try_1": string,
  "try_2": string,
  "try_beat": string,
  "turn_ok": string,
  "soft_promise": string,
  "opening_kind": "curiosity"|"scene"|"recap"|"none",
  "plants_tonight": [string],
  "payoffs_tonight": [string],
  "places": [string],
  "scene_jobs": [string],
  "cast": [string],
  "cast_use": [{"name": string, "signature_move": string, "line": string, "how_tonight": string}],
  "sleep_beat": string,
  "title_hint": string,
  "soft_hook_hint": string
}
try_beat 可等于 try_1+试2 的合并短句；以 try_1/try_2 为准。
"""

DEFAULT_EPISODE_COUNT = 4
PLAN_REQUIRED_KEYS = (
    "wish",
    "snag",
    "turn_ok",
    "soft_promise",
    "opening_kind",
    "sleep_beat",
    "title_hint",
)


def normalize_age_band(age_band: str | None) -> str:
    raw = (age_band or "3-5").strip().lower().replace("–", "-").replace("—", "-")
    raw = re.sub(r"\s+", "", raw)
    if raw in AGE_SPECS:
        return raw
    aliases = {
        "2": "2-3",
        "toddlers": "2-3",
        "toddler": "2-3",
        "3": "3-5",
        "4": "3-5",
        "5": "3-5",
        "preschool": "3-5",
        "6": "6-8",
        "7": "6-8",
        "8": "6-8",
        "school": "6-8",
    }
    if raw in aliases:
        return aliases[raw]
    m = re.match(r"^(\d+)\s*-\s*(\d+)", raw)
    if m:
        key = f"{m.group(1)}-{m.group(2)}"
        if key in AGE_SPECS:
            return key
        lo = int(m.group(1))
        if lo <= 2:
            return "2-3"
        if lo <= 5:
            return "3-5"
        return "6-8"
    return "3-5"


def get_age_spec(age_band: str | None) -> AgeSpec:
    return AGE_SPECS[normalize_age_band(age_band)]


def merge_keywords(
    keywords: list[str] | None,
    interests: list[str] | None = None,
    *,
    limit: int = MAX_KEYWORDS_IN_PROMPT,
) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()
    for raw in list(keywords or []) + list(interests or []):
        if not isinstance(raw, str):
            continue
        k = raw.strip()
        if not k:
            continue
        key = k.lower()
        if key in seen:
            continue
        seen.add(key)
        out.append(k)
        if len(out) >= limit:
            break
    return out


def length_lang_key(language: str | None) -> str:
    lang = (language or "zh").strip().lower()
    if lang.startswith("en"):
        return "en"
    return "zh"


def story_http_timeout_seconds(duration_minutes: int) -> float:
    """HTTP timeout for LLM generation; scales with target length."""
    minutes = max(2, min(12, int(duration_minutes or 5)))
    return float(min(360, 90 + minutes * 45))


def max_tokens_for_story(language: str | None, duration_minutes: int) -> int:
    target = estimate_length_target(language, duration_minutes)
    if target["unit"] == "chars":
        return min(8192, max(1024, int(target["max"] * 1.8) + 256))
    return min(8192, max(1024, int(target["max"] * 2.2) + 256))


def estimate_length_target(language: str | None, duration_minutes: int) -> dict:
    """Estimate body length for ~duration_minutes of bedtime TTS/listening.

    Chinese and English use different units and rates on purpose:
    - zh ≈ characters/minute (typical slow-gentle narration)
    - en ≈ words/minute
    """
    minutes = max(2, min(12, int(duration_minutes or 5)))
    key = length_lang_key(language)
    cfg = LENGTH_RATES[key]
    target = int(round(minutes * cfg["per_minute"]))
    tol = cfg["tolerance"]
    min_n = int(round(target * (1 - tol)))
    max_n = int(round(target * (1 + tol)))
    if key == "zh":
        instruction = (
            f"body 正文约 {target} 字（可接受 {min_n}–{max_n} 字，按汉字计）。"
            f"对应约 {minutes} 分钟轻声朗读。"
            "篇幅不够时增加情节步骤、简短对话或口头禅重复；"
            "禁止堆形容词或书面空描写凑字。"
        )
    else:
        instruction = (
            f"Write body about {target} words (acceptable {min_n}–{max_n} words). "
            f"That should take about {minutes} minutes spoken gently aloud. "
            "If short, add plot steps, brief dialogue, or a refrain — "
            "do not pad with adjectives or literary empty description."
        )
    return {
        "language_key": key,
        "duration_minutes": minutes,
        "unit": cfg["unit"],
        "unit_label": cfg["unit_label"],
        "rate_per_minute": cfg["per_minute"],
        "target": target,
        "min": min_n,
        "max": max_n,
        "instruction": instruction,
    }


def normalize_dial(name: str, value: str | None) -> str:
    levels = STYLE_DIALS.get(name, {})
    v = (value or DEFAULT_DIALS.get(name, "")).strip().lower()
    if v in levels:
        return v
    return DEFAULT_DIALS[name]


def resolve_style_dials(request: StoryRequest) -> dict[str, dict[str, str]]:
    """Return {dial: {level, label, instruction}} with soft combo fixes."""
    plot = normalize_dial("plot_drive", request.plot_drive)
    imagery = normalize_dial("imagery", request.imagery)
    wonder = normalize_dial("wonder", request.wonder)
    wind = normalize_dial("wind_down", request.wind_down)
    dialogue = normalize_dial("dialogue", request.dialogue)
    lead = normalize_dial("lead_in", request.lead_in)

    # Soft guard: mood + rich tends to become scenery essay → pull imagery down.
    if plot == "mood" and imagery == "rich":
        imagery = "balanced"

    # Deep wind-down: curious lead can feel too perky → soften to soft.
    if wind == "deep" and lead == "curious":
        lead = "soft"

    # Short stories + high plot: keep single obstacle (instruction already says so);
    # deep wind_down + arc → remind plot finishes early (extra note on wind).
    resolved = {}
    for name, level in (
        ("plot_drive", plot),
        ("imagery", imagery),
        ("wonder", wonder),
        ("wind_down", wind),
        ("dialogue", dialogue),
        ("lead_in", lead),
    ):
        meta = STYLE_DIALS[name][level]
        instruction = meta["instruction"]
        if name == "wind_down" and plot == "arc" and level == "deep":
            instruction += "情节请在前半完成，后半只做安静收束。"
        if name == "plot_drive" and level == "arc" and (request.duration_minutes or 5) <= 3:
            instruction += "时长较短：障碍只要一个，推进动作从简。"
        if name == "lead_in" and level != "none":
            band = normalize_age_band(request.age_band)
            if band == "2-3":
                instruction += "此年龄总领更短（约1～2句），词语更具体。"
            if wind == "deep":
                instruction += "安眠档偏静：总领声音更轻、更短。"
            if (request.duration_minutes or 5) <= 3:
                instruction += "时长较短：总领最多两句。"
        resolved[name] = {
            "level": level,
            "label": meta["label"],
            "instruction": instruction,
        }
    return resolved


def build_series_opening_note(request: StoryRequest) -> str | None:
    """Extra opening guidance when continuing a soft series / recap is present."""
    recap = (request.recap or "").strip()
    if recap:
        return (
            "开场总领（若 lead_in 非 none）请用一两句自然回顾 recap 里的事，"
            "再接到今晚；不要复述成长段前情提要。"
        )
    if request.soft_series_mode:
        return (
            "这是连续故事模式：若记忆中有上次温和期待，开场可轻轻接住；"
            "没有 recap 就不要编造具体前情。"
        )
    return None


def _focus_compatible(focus_id: str, theme: str | None) -> bool:
    t = (theme or "").lower()
    if focus_id == "friend_repair" and any(k in t for k in ("一个人", "独处", "alone")):
        return False
    return True


def choose_development_focus(
    age_band: str | None,
    theme: str | None,
    *,
    preferred: str | None = None,
    salt: str = "",
) -> tuple[str, str]:
    band = normalize_age_band(age_band)
    pool = FOCUS_POOLS[band]
    if preferred:
        for fid, desc in pool:
            if preferred == fid or preferred in desc:
                return fid, desc
        for bpool in FOCUS_POOLS.values():
            for fid, desc in bpool:
                if preferred == fid:
                    return fid, desc

    candidates = [(fid, desc) for fid, desc in pool if _focus_compatible(fid, theme)]
    if not candidates:
        candidates = list(pool)
    digest = hashlib.sha256(f"{band}|{theme or ''}|{salt}".encode()).hexdigest()
    idx = int(digest[:8], 16) % len(candidates)
    return candidates[idx]


def select_beat_pattern(
    focus_id: str | None,
    *,
    episode_no: int = 1,
    salt: str = "",
) -> dict[str, Any]:
    """Pick an internal beat pattern from the menu (stable for same inputs)."""
    fid = (focus_id or "").strip()
    options = FOCUS_BEAT_MAP.get(fid) or ["approach_retry", "make_and_fix"]
    digest = hashlib.sha256(f"beat|{fid}|{episode_no}|{salt}".encode()).hexdigest()
    idx = int(digest[:8], 16) % len(options)
    pid = options[idx]
    meta = BEAT_PATTERNS.get(pid) or BEAT_PATTERNS["approach_retry"]
    return {
        "id": pid if pid in BEAT_PATTERNS else "approach_retry",
        "label": meta["label"],
        "slots": meta["slots"],
        "instruction": meta["instruction"],
    }


def select_opening_pattern(
    lead_in: str | None,
    *,
    episode_no: int = 1,
    has_recap: bool = False,
    child_cast_absent: bool = False,
    salt: str = "",
) -> dict[str, Any]:
    """Pick opening pattern from lead_in menu; stable for same inputs."""
    lead = normalize_dial("lead_in", lead_in)
    options = list(LEAD_OPENING_MAP.get(lead) or LEAD_OPENING_MAP["soft"])
    if child_cast_absent:
        options = [o for o in options if o != "ritual_soft"] or options
    if has_recap and lead != "none":
        # Prefer anomaly/refresh energy when continuing.
        preferred = [o for o in ("familiar_anomaly", "gentle_wonder", "call_question") if o in options]
        if preferred:
            options = preferred
    digest = hashlib.sha256(
        f"open|{lead}|{episode_no}|{int(has_recap)}|{int(child_cast_absent)}|{salt}".encode()
    ).hexdigest()
    idx = int(digest[:8], 16) % len(options)
    pid = options[idx]
    meta = OPENING_PATTERNS.get(pid) or OPENING_PATTERNS["familiar_anomaly"]
    return {
        "id": pid if pid in OPENING_PATTERNS else "familiar_anomaly",
        "label": meta["label"],
        "opening_kind": meta["opening_kind"],
        "instruction": meta["instruction"],
    }


def select_cast_intro_mode(
    *,
    soft_series_mode: bool,
    episode_no: int = 1,
    lead_in: str | None = "soft",
) -> dict[str, str]:
    """full_intro for standalone / series ep1; light_refresh for later eps."""
    lead = normalize_dial("lead_in", lead_in)
    if lead == "none" and soft_series_mode and int(episode_no) > 1:
        mode = "none"
    elif not soft_series_mode or int(episode_no) <= 1:
        mode = "full_intro"
    else:
        mode = "light_refresh"
    meta = CAST_INTRO_MODES[mode]
    return {"id": mode, "label": meta["label"], "instruction": meta["instruction"]}


def ensure_soft_hook_in_body(body: str, soft_hook: str | None) -> str:
    """If series soft_hook is missing from prose, append a short spoken line before the end."""
    hook = (soft_hook or "").strip()
    text = (body or "").rstrip()
    if not hook or not text:
        return text
    # Loose overlap: if most characters of hook already appear, skip.
    compact_hook = re.sub(r"\s+", "", hook)
    compact_body = re.sub(r"\s+", "", text)
    if len(compact_hook) >= 4 and compact_hook[: min(8, len(compact_hook))] in compact_body:
        return text
    if "明天" in compact_body and ("找" in compact_body or "再" in compact_body):
        return text
    return text + "\n\n" + hook


def focus_from_series_outline(
    outline: dict | None, episode_no: int, *, age_band: str | None = None
) -> tuple[str | None, str | None]:
    """Return (focus_id, focus_label) from series outline episode slice, if present."""
    if not outline:
        return None, None
    episodes = outline.get("episodes") or []
    ep: dict | None = None
    for item in episodes:
        if not isinstance(item, dict):
            continue
        try:
            if int(item.get("episode_no") or 0) == int(episode_no):
                ep = item
                break
        except (TypeError, ValueError):
            continue
    if ep is None and episodes:
        try:
            idx = min(max(int(episode_no) - 1, 0), len(episodes) - 1)
            cand = episodes[idx]
            ep = cand if isinstance(cand, dict) else None
        except (TypeError, ValueError):
            ep = None
    if not ep:
        return None, None
    fid = (ep.get("focus_id") or "").strip() or None
    how = (ep.get("focus_how") or "").strip() or None
    if not fid:
        return None, how
    # Prefer pool label when id is known; keep focus_how as richer how-text.
    if how:
        return fid, how
    _, pool_label = choose_development_focus(age_band, None, preferred=fid)
    return fid, pool_label


def build_user_payload(request: StoryRequest) -> dict:
    spec = get_age_spec(request.age_band)
    focus_id = request.development_focus
    focus_desc = request.development_focus_label
    if not focus_id or not focus_desc:
        focus_id, focus_desc = choose_development_focus(
            request.age_band,
            request.theme,
            preferred=request.development_focus,
            salt=request.child_nickname,
        )

    keywords = merge_keywords(request.keywords, request.interests)
    motif_idx = (
        int(hashlib.sha256(f"motif|{request.theme or ''}|{focus_id}".encode()).hexdigest()[:8], 16)
        % len(MOTIF_WHITELIST)
    )
    cast_role = (request.child_cast_role or "auto").strip().lower()
    cast_hints = {
        "protagonist": f"请让「{request.child_nickname}」作为故事主角出场。",
        "supporting": f"「{request.child_nickname}」可以配角出场，主线可给玩具/伙伴。",
        "absent": f"整篇不要出现「{request.child_nickname}」；用 keywords 里的角色推进故事。",
        "auto": (
            "角色完全可选：孩子可作主角、配角，或整篇不出现；"
            "keywords 中的玩具、娃娃、宠物、家人或物件都可当主角或伙伴。"
        ),
    }
    cast_hint = cast_hints.get(cast_role, cast_hints["auto"])
    cast_hint += "不必用尽所有关键词，选最贴主题的若干自然织入。"

    minutes = max(2, min(12, int(request.duration_minutes or 5)))
    max_places = 1 if minutes <= 3 else 2
    dials = resolve_style_dials(request)
    length_target = estimate_length_target(request.language, minutes)

    return {
        "child_nickname": request.child_nickname,
        "age_band": spec.band,
        "age_label": spec.label_zh,
        "age_guidance": spec.guidance,
        "language": request.language,
        "theme": request.theme,
        "duration_minutes": minutes,
        "length_target": length_target,
        "keywords": keywords,
        "child_cast_role": cast_role,
        "cast_hint": cast_hint,
        "setting_hint": (
            f"全篇建议不超过 {max_places} 个地点（含入睡处）；"
            "跟随 theme/keywords；用动作推进，结尾自然安静入睡。"
        ),
        "style_dials": dials,
        "values_hint": request.values or [],
        "require_emotional_closure": request.require_emotional_closure,
        "forbid_hard_cliffhanger": request.forbid_hard_cliffhanger,
        "recap": request.recap,
        "soft_series_mode": request.soft_series_mode,
        "series_opening_note": build_series_opening_note(request),
        "tonight_focus": {"id": focus_id, "how": focus_desc},
        "allowed_motif": MOTIF_WHITELIST[motif_idx],
        "style_reminders": [
            "严格遵循 style_dials 与 length_target.instruction",
            "听感：一句一事；对话一句一意；场景物要干活；可有拟声/短重复",
            "有节拍：小目标+延迟+两次尝试+今晚小兑现；禁止露面即圆满",
            "系列时正文末段落地 soft_hook，并有点名晚安仪式",
            "跨集伏笔只埋不兑（除非本集 payoffs 允许）",
            "开场总领遵守 lead_in；勿说教点题",
            "禁止照搬知名童话情节或角色名",
            "安心入睡优先于教育意义",
        ],
    }


def parse_json_object(content: str) -> dict:
    text = (content or "").strip()
    if text.startswith("```"):
        lines = text.splitlines()
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        text = "\n".join(lines).strip()
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        start = text.find("{")
        end = text.rfind("}")
        if start >= 0 and end > start:
            data = json.loads(text[start : end + 1])
        else:
            raise
    if not isinstance(data, dict):
        raise ValueError("JSON root must be an object")
    return data


def clamp_episode_count(n: int | None) -> int:
    return max(2, min(8, int(n or DEFAULT_EPISODE_COUNT)))


def slice_series_context(outline: dict, episode_no: int) -> dict:
    """Episode-facing slice of a series outline for plan/draft prompts."""
    episodes = outline.get("episodes") or []
    ep = None
    for item in episodes:
        if int(item.get("episode_no") or 0) == int(episode_no):
            ep = item
            break
    if ep is None and episodes:
        idx = min(max(int(episode_no) - 1, 0), len(episodes) - 1)
        ep = episodes[idx]
    if ep is None:
        ep = {
            "episode_no": episode_no,
            "premise": "",
            "soft_promise": "",
            "plants": [],
            "payoffs": [],
            "sleep_note": "",
            "focus_id": "",
            "focus_how": "",
        }
    total = len(episodes) or int(outline.get("episode_count") or episode_no)
    return {
        "series_title": outline.get("title") or "",
        "throughline": outline.get("throughline") or "",
        "cast_spine": outline.get("cast_spine") or [],
        "threads": outline.get("threads") or [],
        "episode_no": int(episode_no),
        "episode_count": total,
        "is_finale": int(episode_no) >= total,
        "episode": ep,
    }


def validate_episode_plan(
    plan: dict,
    *,
    lead_in: str,
    soft_series_mode: bool = False,
    beat_pattern: dict[str, Any] | None = None,
    opening_pattern: dict[str, Any] | None = None,
    cast_intro_mode: dict[str, str] | None = None,
) -> dict:
    missing = [k for k in PLAN_REQUIRED_KEYS if k not in plan]
    if missing:
        raise ValueError(f"episode plan missing keys: {missing}")

    if opening_pattern:
        plan["opening_pattern"] = opening_pattern.get("id") or "familiar_anomaly"
        plan["opening_pattern_meta"] = {
            "id": opening_pattern.get("id"),
            "label": opening_pattern.get("label"),
            "instruction": opening_pattern.get("instruction"),
        }
        forced_kind = str(opening_pattern.get("opening_kind") or "scene")
    else:
        plan.setdefault("opening_pattern", "familiar_anomaly")
        forced_kind = str(plan.get("opening_kind") or "scene")

    kind = str(plan.get("opening_kind") or forced_kind).strip().lower()
    if kind not in ("curiosity", "scene", "recap", "none"):
        kind = forced_kind if forced_kind in ("curiosity", "scene", "recap", "none") else "scene"
    if lead_in == "none" or (opening_pattern and opening_pattern.get("id") == "none"):
        plan["opening_kind"] = "none"
        plan["soft_promise"] = ""
        plan["opening_lines"] = ""
    else:
        # Prefer pattern-forced kind so lead_in and draft stay aligned.
        plan["opening_kind"] = forced_kind if forced_kind != "none" else kind
        if not str(plan.get("opening_lines") or "").strip():
            plan["opening_lines"] = str(plan.get("soft_promise") or "").strip()

    if cast_intro_mode:
        plan["cast_intro_mode"] = cast_intro_mode.get("id") or "full_intro"
        plan["cast_intro_meta"] = {
            "id": cast_intro_mode.get("id"),
            "label": cast_intro_mode.get("label"),
            "instruction": cast_intro_mode.get("instruction"),
        }
    else:
        plan.setdefault("cast_intro_mode", "full_intro")
    plan.setdefault("setting_line", "")
    plan.setdefault("opening_lines", plan.get("opening_lines") or "")

    try_1 = str(plan.get("try_1") or "").strip()
    try_2 = str(plan.get("try_2") or "").strip()
    try_beat = str(plan.get("try_beat") or "").strip()
    if not try_1 and try_beat:
        # Legacy single beat → split lightly if model used "；" / "。再"
        parts = re.split(r"[；;]|。再|，再", try_beat, maxsplit=1)
        try_1 = parts[0].strip() or try_beat
        try_2 = (parts[1].strip() if len(parts) > 1 else "") or try_beat
    if not try_1:
        try_1 = try_beat or str(plan.get("wish") or "试一试")
    if not try_2:
        try_2 = try_beat or str(plan.get("turn_ok") or "再轻轻试一次")
    plan["try_1"] = try_1
    plan["try_2"] = try_2
    plan["try_beat"] = try_beat or f"{try_1}；{try_2}"

    if beat_pattern:
        plan["beat_pattern"] = beat_pattern.get("id") or plan.get("beat_pattern") or "approach_retry"
        plan["beat_pattern_meta"] = {
            "id": beat_pattern.get("id"),
            "label": beat_pattern.get("label"),
            "instruction": beat_pattern.get("instruction"),
        }
    else:
        plan.setdefault("beat_pattern", "approach_retry")

    plan.setdefault("plants_tonight", [])
    plan.setdefault("payoffs_tonight", [])
    plan.setdefault("places", [])
    plan.setdefault("scene_jobs", [])
    plan.setdefault("cast", [])
    plan.setdefault("cast_use", [])
    plan.setdefault("soft_hook_hint", "")
    if soft_series_mode and not str(plan.get("soft_hook_hint") or "").strip():
        # Fall back to soft_promise so draft still has a hook line.
        plan["soft_hook_hint"] = str(plan.get("soft_promise") or "").strip()
    sleep = str(plan.get("sleep_beat") or "")
    if "晚安" not in sleep:
        plan["sleep_beat"] = (sleep + " 晚安，一点点；晚安，今晚。").strip()
    return plan


def build_outline_user_message(request: StoryRequest) -> str:
    payload = build_user_payload(request)
    count = clamp_episode_count(request.episode_count)
    outline_payload = {
        "episode_count": count,
        "theme": payload["theme"],
        "language": payload["language"],
        "age_band": payload["age_band"],
        "age_guidance": payload["age_guidance"],
        "keywords": payload["keywords"],
        "cast_hint": payload["cast_hint"],
        "style_dials": {
            k: {"level": v["level"], "label": v["label"]}
            for k, v in payload["style_dials"].items()
        },
        "focus_pool_hint": FOCUS_POOLS.get(payload["age_band"], []),
        "tonight_focus_seed": payload["tonight_focus"],
        "values_hint": payload["values_hint"],
    }
    lead = (
        f"请为软系列设计 {count} 集睡前大纲。只输出 JSON。\n"
        if not (request.language or "zh").lower().startswith("en")
        else f"Design a soft bedtime series outline with {count} episodes. JSON only.\n"
    )
    return lead + json.dumps(outline_payload, ensure_ascii=False)


def build_plan_user_message(
    request: StoryRequest,
    *,
    beat_pattern: dict[str, Any] | None = None,
    opening_pattern: dict[str, Any] | None = None,
    cast_intro_mode: dict[str, str] | None = None,
) -> str:
    payload = build_user_payload(request)
    lead_level = payload["style_dials"]["lead_in"]["level"]
    focus_id = (payload.get("tonight_focus") or {}).get("id") or request.development_focus
    ep_no = int(request.episode_no or 1)
    salt = request.child_nickname or ""
    cast_absent = (request.child_cast_role or "").strip().lower() == "absent"
    beat = beat_pattern or select_beat_pattern(focus_id, episode_no=ep_no, salt=salt)
    opening = opening_pattern or select_opening_pattern(
        lead_level,
        episode_no=ep_no,
        has_recap=bool((request.recap or "").strip()),
        child_cast_absent=cast_absent,
        salt=salt,
    )
    intro = cast_intro_mode or select_cast_intro_mode(
        soft_series_mode=bool(request.soft_series_mode or request.series_outline),
        episode_no=ep_no,
        lead_in=lead_level,
    )
    plan_payload = {
        **{k: payload[k] for k in (
            "child_nickname",
            "age_band",
            "age_guidance",
            "language",
            "theme",
            "duration_minutes",
            "keywords",
            "cast_hint",
            "setting_hint",
            "style_dials",
            "recap",
            "soft_series_mode",
            "tonight_focus",
            "allowed_motif",
        )},
        "lead_in_level": lead_level,
        "episode_no": request.episode_no,
        "beat_pattern": beat,
        "opening_pattern": opening,
        "cast_intro_mode": intro,
        "series_context": (
            slice_series_context(request.series_outline, request.episode_no)
            if request.series_outline
            else None
        ),
    }
    if lead_level == "none" or opening.get("id") == "none":
        plan_payload["opening_constraint"] = (
            "opening_kind must be none; soft_promise empty; opening_lines empty"
        )
    lead = (
        "请只输出今晚单集构思 JSON（不要正文）。"
        "必须遵守 beat_pattern、opening_pattern、cast_intro_mode。\n"
        if not (request.language or "zh").lower().startswith("en")
        else (
            "Output tonight's episode plan JSON only (no prose). "
            "Obey beat_pattern, opening_pattern, and cast_intro_mode.\n"
        )
    )
    return lead + json.dumps(plan_payload, ensure_ascii=False)


def build_user_message(request: StoryRequest, plan: dict | None = None) -> str:
    payload = build_user_payload(request)
    if plan is not None:
        payload["story_plan"] = plan
        need_opening = (plan.get("opening_pattern") or "none") != "none"
        payload["draft_checklist"] = {
            "body_order": [
                "opening_lines (own paragraph)" if need_opening else "skip_opening",
                "cast_intro / setting_line",
                "wish_snag_tries",
                "soft_hook then goodnight" if request.soft_series_mode else "goodnight",
            ],
            "must_land_opening_paragraph": need_opening,
            "opening_lines": plan.get("opening_lines") or None,
            "opening_pattern": plan.get("opening_pattern"),
            "cast_intro_mode": plan.get("cast_intro_mode"),
            "setting_line": plan.get("setting_line") or None,
            "must_include_try_1": plan.get("try_1"),
            "must_include_try_2": plan.get("try_2"),
            "must_land_soft_hook_in_body": bool(request.soft_series_mode),
            "soft_hook_line": plan.get("soft_hook_hint") or None,
            "must_land_goodnight_ritual": True,
            "sleep_beat": plan.get("sleep_beat"),
            "cast_use": plan.get("cast_use") or [],
            "no_early_thread_payoff": True,
            "forbid_child_nickname": (request.child_cast_role or "").lower() == "absent",
        }
    if request.series_outline is not None:
        payload["series_context"] = slice_series_context(
            request.series_outline, request.episode_no
        )
    lang = (request.language or "zh").lower()
    if lang.startswith("zh"):
        lead = (
            "请按系统规则、style_dials"
            + ("与 story_plan/draft_checklist" if plan is not None else "")
            + "写今晚的睡前故事。"
            "正文顺序：总领段（若需要）→ 角色/场景建档（若需要）→ 情节 → 软期待（系列）→ 晚安。"
            "系列时正文末段（晚安前）必须出现 soft_hook 那句软期待。"
            "只输出 JSON 对象（不要 markdown）："
            '{"title","body","soft_hook"}。\n'
        )
    else:
        lead = (
            "Write tonight's bedtime story per the system rules, style_dials"
            + (", story_plan, and draft_checklist" if plan is not None else "")
            + ". Order: opening → cast intro → plot → soft_hook (series) → goodnight. "
            'Reply with ONLY a JSON object (no markdown): {"title","body","soft_hook"}.\n'
        )
    return lead + json.dumps(payload, ensure_ascii=False)

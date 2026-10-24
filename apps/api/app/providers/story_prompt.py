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
                "可用少量可摸可听的身体感（凉、暖、脚边的布、窗外一点光）；"
                "叠词全篇≤3次且不反复同一词；禁止排比、长定语与开篇堆修饰；"
                "宁可多一步动作，也不写华丽空句。"
                "不要默认用「叮叮 / 叮当 / 小响片」当开场钩子。"
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
            "instruction": "不要单独听前开场白；第一句就进入故事里的人与事。",
        },
        "soft": {
            "label": "听前开场白",
            "instruction": (
                "正文开头先写一段「听前开场白」（像播客/口述讲故事的开场），"
                "用口语把听者从日常安顿进今晚故事，再逐渐进入正叙——"
                "禁止第一句就进书本式情节或主冲突。"
                "开场白约占全文 12%～20%（常见约 5～8 句，可分两小段），旁白可对听者轻声说话；"
                "自然点到若干：今晚会遇见谁、在怎样的小地方、有什么轻轻值得期待的小事"
                "（软好奇，非硬悬念）；可轻提人物小特点或场景触感。"
                "再用一两句过渡，才进入 wish/动作主线。"
                "若有 recap/连续故事，开场白里一两句接住上回，再讲今晚。"
                "形态要多样，禁止固定套话、主题宣讲、道德点题、课堂提问腔、剧透 try/turn 结局。"
            ),
        },
        "curious": {
            "label": "好奇开场白",
            "instruction": (
                "正文开头先写听前开场白（约占全文 12%～20%，约 5～8 句），偏轻好奇："
                "可抛一个低风险小疑问或「今晚要弄明白的小事」，并带出人物/背景，"
                "让听者安下心再进故事；问句不必要求回答。"
                "之后逐渐过渡进正叙，禁止开场白一两句就切进冲突。"
                "若有 recap/连续故事，可先接住上回再抛出今晚好奇。"
                "禁止说教点题、吓人硬悬念、剧透结局。"
            ),
        },
    },
    "wonder": {
        "everyday": {
            "label": "生活向",
            "instruction": (
                "生活向：场景、物件与因果都贴近孩子日常（家、幼儿园、散步、玩具）；"
                "最多轻度拟人，禁止魔法国度、穿越、大型奇幻设定。"
                "setting 与 beats 须像「今晚真的可能发生」的小事。"
            ),
        },
        "soft": {
            "label": "轻想象",
            "instruction": (
                "轻想象：以日常为底，可有一点点温柔想象（月亮眨眼、玩具轻声说话）；"
                "不写复杂世界观、不堆奇幻规则；幻想只服务安心与听感。"
            ),
        },
        "fantasy": {
            "label": "更幻想",
            "instruction": (
                "更幻想：可用更明显的想象设定或温柔奇遇，但仍单线、安全、低冲突；"
                "禁止恐怖、史诗战争与难懂世界观；今晚必须安心入睡。"
            ),
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

# Duration → length band for LLM `len` (+ max_tokens headroom).
# zh: characters/minute; en: words/minute — units differ, must stay separate.
# Band width is ±1 listening minute (per_minute units), not a percentage of target.
LENGTH_RATES = {
    "zh": {
        "unit": "chars",
        "unit_label": "汉字（含标点近似按字计）",
        "per_minute": 220,
    },
    "en": {
        "unit": "words",
        "unit_label": "English words",
        # Bedtime speaking pace (independent of zh chars/min).
        "per_minute": 100,
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
    "9-12": AgeSpec(
        band="9-12",
        label_zh="约9–12岁",
        guidance=(
            "主线仍清晰，可有一点点因果或选择；口语自然，可有简短对话；"
            "允许轻微好奇/思考，但结尾仍明显安静；禁止说教、课堂腔与成人讽刺。"
        ),
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
    "9-12": [
        ("try_persist", "坚持一下：小小努力后可以休息"),
        ("friend_repair", "小摩擦后和好（双方都不被贬低）"),
        ("mentalize_light", "别人也可能有不一样的小心思，仍友善收场"),
        ("curious_cause", "小小因果：好奇发生了什么，轻轻弄明白（不讲课）"),
        ("own_choice", "做一个小决定并被尊重，然后安心收场"),
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

# Story architecture: DB-backed shape pool (Admin「故事结构」). Soft beat ranges.
from app.services.story_shapes import (  # noqa: E402
    SHAPE_SEED,
    default_roles_for_shape,
    default_shape_id,
    get_runtime_shape_ids,
    select_beat_pattern,
    select_story_shape,
    shape_beat_range,
    shape_guidance,
    shape_payload,
)

STORY_SHAPES = tuple(s["id"] for s in SHAPE_SEED)
STORY_SHAPE_SPECS = {
    s["id"]: {
        "label": s["label_zh"],
        "beat_min": s["beat_min"],
        "beat_max": s["beat_max"],
        "guidance": s["guidance"],
        "effect": s.get("effect") or "",
    }
    for s in SHAPE_SEED
}
# Known development-focus ids (from age pools). Shape selection no longer maps focus→shape.
FOCUS_BEAT_MAP: dict[str, list[str]] = {
    fid: []
    for pool in FOCUS_POOLS.values()
    for fid, _ in pool
}

# Internal opening menus (not shown in App). Warm-up = host voice before plot.
OPENING_PATTERNS: dict[str, dict[str, Any]] = {
    "none": {
        "label": "直接开讲",
        "opening_kind": "none",
        "instruction": "不要单独听前开场白；第一句就进入故事里的人与事。",
    },
    "ritual_soft": {
        "label": "轻仪式",
        "opening_kind": "scene",
        "instruction": (
            "听前开场白用很软的睡前招呼（可轻唤听者，但 child_cast_role=absent 时禁止点孩子名字），"
            "再慢慢点出今晚会遇见谁、在哪儿、有什么轻轻值得听下去的小事；"
            "约 5～7 句后再过渡进正叙。禁止每篇同一句「小朋友你一定……」。"
        ),
    },
    "call_question": {
        "label": "呼叫提问",
        "opening_kind": "curiosity",
        "instruction": (
            "听前开场白用轻呼叫/提问拉注意，如「你见过……吗？」「你听……？」「今晚……」；"
            "顺带带出人物或场景触感；不问课堂题、不要求回答；"
            "约 5～7 句后再过渡进故事动作，勿两句切冲突。"
        ),
    },
    "familiar_anomaly": {
        "label": "熟悉反常",
        "opening_kind": "scene",
        "instruction": (
            "听前开场白先安顿听者，再点出一个具体小画面与轻反常"
            "（如捂眼睛、停住脚、草穗歪了），让人感到「今晚有一点点不一样」；"
            "可轻提相关人物；约 5～7 句后过渡进正叙，勿剧透怎么解决。"
        ),
    },
    "gentle_wonder": {
        "label": "温柔疑问",
        "opening_kind": "curiosity",
        "instruction": (
            "听前开场白提出一个低风险小疑问（他们找得到吗？小羊会怎么做呢？），"
            "并简介谁在场、在怎样的小地方；不制造硬悬念；"
            "约 5～7 句后过渡进正叙。"
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
            "听前开场白里或紧随其后、主冲突之前，用口语完成建档："
            "每个主要角色一句（名字+一个标志动作或喜好）；"
            "再说明今晚在哪儿、在做什么（接 throughline/本集一小步）。"
            "可与开场白融在同一段口播里，但须让听者先认识人/地方，再进情节节拍。"
            "禁止只扔名字不挂钩。"
        ),
    },
    "light_refresh": {
        "label": "轻点名",
        "instruction": (
            "续集：在开场白里用一两句带过熟悉角色（可点标志动作），不要重新开世界观；"
            "可接一句上回软期待/recap。"
        ),
    },
    "none": {
        "label": "不另介绍",
        "instruction": "不单独介绍段；姓名随动作自然带出即可（仅短篇续集或 lead_in=none 时）。",
    },
}

SYSTEM_PROMPT = """你是一个资深的睡前故事作家。你擅长将一个故事写成温暖的、适合睡前听的文字。

【你的任务】
- 你将得到一个json输入，它将描述故事的基本信息及大纲。
- 你需要根据输入信息，将这个故事的正文写出来
- 文本的开头不要直接进入故事，写一段开篇的垫话。内容可以是你对故事的提炼，组织成可以吸引小听众注意力和兴趣的语言。
- 文本结尾不要戛然而止。故事讲完后可以有一段与情节相关交流式的总结语言，然后自然的引导到休息、睡觉、明天见等睡前故事结尾的感受。

【核心要求】
- 文本要适合读和听，所以不要过多使用长句，修辞和用语不要过于书面。
- 根据目标听众的年龄来遣词造句

【输入格式】
输入是一个json，以下是字段说明：
- title：故事题目。
- theme：故事主题、内核、核心创意的简述。
- casts：故事中出现的角色，用数组的形式表示，每个元素是一个json，有以下两个字段。
  - name：角色名称。如果有昵称，用斜杠分格。如：哆啦A梦/小叮当
  - desc：角色概述。简述角色设定、性格、习惯等，让角色鲜活起来。
- beats：故事的节拍（推动故事前进的最小叙事单位），用数组形式表示，每个元素是字符串，描述一个节拍。
- age：目标听众的年龄（整数，单位：岁）。你的文字、语言要适合这个年纪的听众。
- gender：目标听众的性别（如：男孩、女孩、其他、不指定）。可轻柔影响称呼与细节，禁止刻板印象与说教。
- dialog: 对话的多少，0-5打分。分数越高则写更多的对话，分数越低则少对话，0分是完全不要用直接的对话描写。
- len：正文目标篇幅范围，字符串格式「下限-上限」（如 880-1320）；中文按汉字计、英文按词计。body（含开篇垫话与结尾）尽量落在该区间内；优先故事质量，禁止堆形容词或空描写凑字。

【输出要求】
输出一个json对象，字段说明如下：
- title: 故事标题
- body: 正文。包括开篇垫话、故事正文、结尾的话。
"""

SERIES_OUTLINE_SYSTEM_PROMPT = """你是睡前「软系列」叙事策划（不是写正文）。为幼儿设计一小季温和连载大纲。

规则：
1) 每集今晚情绪闭环、可单独安心入睡；跨集只用温和期待，禁止硬悬念。
2) arc 是整季小目标（如「找到能跳舞的软草地」）；每集 premise 必须是主线的一小步，不能写成无关的偶遇即止。
3) 服从输入 dials.wonder：everyday 整季偏生活场景；soft 以日常为底可轻想象；fantasy 可更温柔奇遇，仍禁止复杂世界观。
4) 1～2 条 threads；每条写清 what 与 at（兑现集号）；非 at 集只能埋或轻碰，禁止提前兑现。
5) cast 用对象：每人 name + move（标志动作）+ line（口头禅，可短）；禁止只有形容词标签。
6) 每集 how 必须是动作级；禁止把终集 focus 设为 wind_down；终集也要有今晚情节（可兑现线索）。
7) hook / sleep 必须是可直接朗读的短句（不是气氛说明）。
8) plants：本集只埋的线索；payoffs：本集允许轻兑现的（须对照 threads.at）。
9) 只输出 JSON（不要 markdown），字段短写（≤40字）：
{
  "title": string,
  "arc": string,
  "cast": [{"name": string, "move": string, "line": string}],
  "threads": [{"id": string, "what": string, "at": number}],
  "episodes": [{
    "ep": number,
    "focus": string,
    "how": string,
    "premise": string,
    "hook": string,
    "plants": [string],
    "payoffs": [string],
    "sleep": string
  }]
}
episodes 长度必须等于 n；ep 从 1 连续编号。
字符串内勿用未转义双引号；输出必须是完整可解析 JSON。
"""

PLAN_SYSTEM_PROMPT = """你是一位世界级的儿童睡前故事作家，你擅长写温暖但富有想象力的儿童故事。

【你的任务】
- 根据输入的关键词构思故事的核心创意、背景、地点、角色、事件、结构。
- 你不写全文，只要写出故事大纲。

【核心要求】
- 严禁暴力、色情等不适合小孩的内容
- 不要有强烈冲突、激烈争吵、打斗等不适合睡前听的内容

【输入说明】
关键词信息会以json的形式输入，以下说明字段含义：
- theme：故事主题。它将是你创作故事内核的初始动机。
- keywords：关键词。以这些关键词提到的事物为出发点，来构思场景、情节、角色。
- age：目标听众的年龄（整数，单位：岁）。你的故事情节、角色要适合这个年纪的听众。
- gender：目标听众的性别（如：男孩、女孩、其他、不指定）。构思角色与称呼时可参考，禁止刻板印象与说教。
- fantasy: 故事是偏幻想还是偏日常。0-5打分。分数越高则世界观与剧情设定更偏虚构幻想充满想象力；分数越低则更偏日常生活。
- len：目标正文篇幅范围，字符串格式「下限-上限」（如 880-1320）；中文按汉字计、英文按词计。beats 数量与密度应能支撑该篇幅，仍保持睡前温和，禁止为空凑拍。
- roster：今晚已选角色库（数组，可空）。元素含 k（child|person|toy）、n（名字），可选 rel（关系）、note（特征）。优先轻用 1～3 个写入 casts；禁止把名单当必须清单；可与 keywords 搭配，勿整篇只围着名单转。

【输出格式】
将你构思的内容梳理为一个json，这个数据将用于给下一位作家用来写正文。json的字段说明如下：
- title：故事题目。
- theme：故事主题、背景与核心创意的简述（可稍完整）。
- core：一句短标签（建议≤12字），概括今晚故事的情感或成长内核，供界面展示；具体、可感，禁止空话套话。
- casts：故事中出现的角色，用数组的形式表示，每个元素是一个json，有以下两个字段。
  - name：角色名称。如果有昵称，用斜杠分格。如：哆啦A梦/小叮当
  - desc：角色概述。简述角色设定、性格、习惯等，让角色鲜活起来。
- beats：故事的节拍（推动故事前进的最小叙事单位），用数组形式表示，每个元素是字符串，描述一个节拍。数量与密度应能支撑 len 给出的篇幅区间。
- shape: 故事的结构。用一句简短的话或词描述你用到的结构。
"""

DEFAULT_EPISODE_COUNT = 4
# Lean plan keys (legacy aliases accepted on input).
PLAN_REQUIRED_ALIASES: dict[str, tuple[str, ...]] = {
    "title": ("title", "title_hint"),
    "casts": ("casts", "cast", "cast_use"),
    "beats": ("beats",),
    "shape": ("shape", "story_shape"),
}

# wonder dial → fantasy 0–5 for simplified plan/draft prompts.
WONDER_FANTASY_SCORE = {"everyday": 1, "soft": 3, "fantasy": 5}
DIALOGUE_DIALOG_SCORE = {"low": 1, "some": 3, "more": 5}


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
        "9": "9-12",
        "10": "9-12",
        "11": "9-12",
        "12": "9-12",
        "preteen": "9-12",
        "tween": "9-12",
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
        if lo <= 8:
            return "6-8"
        return "9-12"
    return "3-5"


def get_age_spec(age_band: str | None) -> AgeSpec:
    return AGE_SPECS[normalize_age_band(age_band)]


def merge_keywords(
    keywords: list[str] | None,
    interests: list[str] | None = None,
    *,
    limit: int = MAX_KEYWORDS_IN_PROMPT,
) -> list[str]:
    """Dedupe/cap string tags. Prefer tonight keywords first, then interests."""
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


def pick_soft_likes(
    interests: list[str] | None,
    *,
    salt: str = "",
    max_n: int = 1,
) -> list[str]:
    """Rotate at most max_n profile interests for optional flavor (not every night)."""
    pool = merge_keywords(None, interests, limit=MAX_KEYWORDS_IN_PROMPT)
    if not pool or max_n <= 0:
        return []
    # ~half the nights inject no like — avoids "every episode dances".
    dig = hashlib.sha256(f"likes|{salt}|{','.join(pool)}".encode()).hexdigest()
    if int(dig[:2], 16) % 2 == 0:
        return []
    start = int(dig[2:6], 16) % len(pool)
    rotated = pool[start:] + pool[:start]
    return rotated[:max_n]


def length_lang_key(language: str | None) -> str:
    lang = (language or "zh").strip().lower()
    if lang.startswith("en"):
        return "en"
    return "zh"


def story_http_timeout_seconds(duration_minutes: int) -> float:
    """HTTP timeout for LLM generation; scales with target listening duration."""
    minutes = max(2, min(12, int(duration_minutes or 5)))
    return float(min(360, 90 + minutes * 45))


def estimate_length_target(language: str | None, duration_minutes: int) -> dict:
    """Map duration → {min,max,target} band (zh chars / en words, ±1 minute)."""
    minutes = max(2, min(12, int(duration_minutes or 5)))
    key = length_lang_key(language)
    cfg = LENGTH_RATES[key]
    rate = int(cfg["per_minute"])
    target = int(round(minutes * rate))
    # ±1 listening minute of content, independent of total duration.
    min_n = max(1, target - rate)
    max_n = target + rate
    return {
        "language_key": key,
        "duration_minutes": minutes,
        "unit": cfg["unit"],
        "unit_label": cfg.get("unit_label") or cfg["unit"],
        "rate_per_minute": rate,
        "target": target,
        "min": min_n,
        "max": max_n,
    }


def length_range_for_llm(language: str | None, duration_minutes: int) -> str:
    """Compact len string for plan/draft user JSON, e.g. '880-1320'."""
    band = estimate_length_target(language, duration_minutes)
    return f"{int(band['min'])}-{int(band['max'])}"


def max_tokens_for_story(language: str | None, duration_minutes: int) -> int:
    """Internal API content budget from length band max (not a hard LLM cap)."""
    band = estimate_length_target(language, duration_minutes)
    approx = int(band["max"])
    if band["unit"] == "chars":
        return min(8192, max(1024, int(approx * 1.8) + 256))
    return min(8192, max(1024, int(approx * 2.2) + 256))


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
                instruction += "此年龄开场白略短（约4～5句），词语具体、可摸可听。"
            elif band == "9-12":
                instruction += "此年龄开场白可略清晰一点，仍短、口语、不讲课。"
            if wind == "deep":
                instruction += "安眠档偏静：开场白声音更轻，仍须先安顿听者再进情节。"
            if (request.duration_minutes or 5) <= 3:
                instruction += "时长较短：开场白约4～5句，仍须与正叙分开，勿压缩成一句就进冲突。"
        resolved[name] = {
            "level": level,
            "label": meta["label"],
            "instruction": instruction,
        }
    return resolved


def build_series_opening_note(request: StoryRequest) -> str | None:
    """Extra warm-up guidance when continuing a soft series / recap is present."""
    recap = (request.recap or "").strip()
    if recap:
        return (
            "听前开场白（若 lead_in 非 none）请用一两句自然回顾 recap 里的事，"
            "再接到今晚值得期待的小事；不要复述成长段前情提要。"
        )
    if request.soft_series_mode:
        return (
            "这是连续故事模式：若记忆中有上次温和期待，开场白可轻轻接住；"
            "没有 recap 就不要编造具体前情。"
        )
    return None


def build_child_profile_guidance(
    *,
    gender: str,
    intro: str | None,
    nickname: str | None = None,
) -> str:
    """Soft instructions so gender/intro tilt language without stereotypes."""
    g = (gender or "unspecified").strip().lower()
    parts: list[str] = []
    if g == "girl":
        parts.append(
            "孩子偏女孩：代词/称谓自然一致；兴趣与细节可略贴女孩日常或 intro，"
            "禁止公主/粉裙等刻板堆砌。"
        )
    elif g == "boy":
        parts.append(
            "孩子偏男孩：代词/称谓自然一致；兴趣与细节可略贴男孩日常或 intro，"
            "禁止「男孩就该勇敢」等刻板堆砌。"
        )
    else:
        parts.append(
            "性别不指定或多元：保持中性称谓与兴趣倾向，勿强加性别刻板印象。"
        )
    text = (intro or "").strip()
    if text:
        who = f"「{nickname}」" if nickname else "孩子"
        parts.append(
            f"child_intro 是{who}的可选背景，全文自然轻点 1～2 处即可，"
            "勿整段复述、勿说教。"
        )
    return " ".join(parts)


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


def resolve_target_feeling(request: "StoryRequest") -> str:
    """Map style dials to a speakable target_feeling for plan/draft."""
    if getattr(request, "target_feeling", None):
        tf = str(request.target_feeling or "").strip()
        if tf:
            return tf
    wd = (request.wind_down or "gentle").strip().lower()
    if wd == "deep":
        return "困倦"
    if wd == "playful":
        return "轻微好奇"
    wonder = (request.wonder or "soft").strip().lower()
    if wonder == "fantasy":
        return "轻微好奇"
    return "安心"


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
    norm = normalize_series_outline(outline)
    episodes = norm.get("episodes") or []
    ep: dict | None = None
    for item in episodes:
        if not isinstance(item, dict):
            continue
        try:
            if int(item.get("ep") or 0) == int(episode_no):
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
    fid = (ep.get("focus") or "").strip() or None
    how = (ep.get("how") or "").strip() or None
    if not fid:
        return None, how
    if how:
        return fid, how
    _, pool_label = choose_development_focus(age_band, None, preferred=fid)
    return fid, pool_label


def build_user_payload(request: StoryRequest) -> dict:
    from app.core.config import get_settings
    from app.services.story_kernels import AXIS_LABELS_ZH, axis_for_focus

    spec = get_age_spec(request.age_band)
    focus_id = (request.development_focus or "").strip() or None
    # Auto-pick is gated off during phase-1 (FEATURE_STORY_FOCUS_ELEMENTS=0).
    if not focus_id and get_settings().feature_story_focus_elements:
        focus_id, _pool_how = choose_development_focus(
            request.age_band,
            request.theme,
            preferred=request.development_focus,
            salt=request.child_nickname,
        )
    axis = None
    axis_label = None
    if focus_id:
        axis, axis_label = axis_for_focus(focus_id)
        # Accept short axis zh if already set; drop legacy long soft_guidance labels.
        label_in = (request.development_focus_label or "").strip()
        if label_in in AXIS_LABELS_ZH.values():
            axis_label = label_in
            for aid, zh in AXIS_LABELS_ZH.items():
                if zh == label_in:
                    axis = aid
                    break

    audiences = [
        a
        for a in (request.audiences or [])
        if isinstance(a, dict) and str(a.get("name") or "").strip()
    ]
    roster = [
        r
        for r in (request.roster or [])
        if isinstance(r, dict) and str(r.get("name") or r.get("n") or "").strip()
    ][:8]
    # Normalize legacy roster keys if any slipped through.
    normalized_roster: list[dict] = []
    for r in roster:
        name = str(r.get("name") or r.get("n") or "").strip()
        if not name:
            continue
        item: dict = {"name": name}
        desc = str(r.get("desc") or "").strip()
        if not desc:
            rel = str(r.get("rel") or r.get("relation") or "").strip()
            note = str(r.get("note") or "").strip()
            desc = "，".join(p for p in (rel, note) if p)
        if desc:
            item["desc"] = desc
        if r.get("age") is not None:
            try:
                item["age"] = int(r["age"])
            except (TypeError, ValueError):
                pass
        gender = str(r.get("gender") or "").strip()
        if gender:
            item["gender"] = gender
        normalized_roster.append(item)

    motif_salt = f"motif|{request.theme or ''}|{focus_id or 'none'}"
    motif_idx = (
        int(hashlib.sha256(motif_salt.encode()).hexdigest()[:8], 16)
        % len(MOTIF_WHITELIST)
    )
    cast_role = (request.child_cast_role or "auto").strip().lower()
    cast_hints = {
        "protagonist": f"请让「{request.child_nickname}」作为故事主角出场。",
        "supporting": f"「{request.child_nickname}」可以配角出场，主线可给玩具/伙伴。",
        "absent": f"整篇不要出现「{request.child_nickname}」；可用 roster 里的角色推进故事。",
        "auto": (
            "角色完全可选：孩子可作主角、配角，或整篇不出现；"
            "roster 里的玩具、娃娃、家人或物件都可当主角或伙伴。"
        ),
    }
    cast_hint = cast_hints.get(cast_role, cast_hints["auto"])
    if normalized_roster:
        cast_hint += (
            "roster 是今晚已选角色库（优先轻用 1～3 个）："
            "name=名字，desc=概述，age/gender 可选；禁止把名单当必须清单。"
        )
    if audiences:
        cast_hint += (
            "audiences 是今晚听众：name/age/gender/desc/prefer；"
            "prefer 是故事偏好，可轻点，禁止当每集主线。"
        )

    minutes = max(2, min(12, int(request.duration_minutes or 5)))
    max_places = 1 if minutes <= 3 else 2
    dials = resolve_style_dials(request)

    out = {
        "language": request.language,
        "theme": request.theme,
        "duration_minutes": minutes,
        "audiences": audiences,
        "roster": normalized_roster,
        "child_cast_role": cast_role,
        "cast_hint": cast_hint,
        "setting_hint": (
            f"全篇建议不超过 {max_places} 个地点（含入睡处）；"
            "主线跟 theme 与今晚情节；audiences/roster 都是可选点缀；用动作推进，结尾自然安静入睡。"
        ),
        "style_dials": dials,
        "require_emotional_closure": request.require_emotional_closure,
        "forbid_hard_cliffhanger": request.forbid_hard_cliffhanger,
        "recap": request.recap,
        "soft_series_mode": request.soft_series_mode,
        "series_opening_note": build_series_opening_note(request),
        "allowed_motif": MOTIF_WHITELIST[motif_idx],
        "age_band": spec.band,
        "age_guidance": spec.guidance,
        "style_reminders": [
            "听感优先：口语旁白，一句一事；正文篇幅落在 len 给出的字数区间",
            "先听前开场白安顿听者，再渐入正文；勿像翻书开念",
            "忠实落地 plan；结尾自然收束；系列才写 hook；勿说教",
            "勿把故事偏好当成每集主线",
        ],
    }
    if focus_id:
        out["tonight_focus"] = {
            "id": focus_id,
            "axis": axis,
            "axis_label": axis_label,
        }
    return out


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


def _pick(d: dict | None, *keys: str, default: Any = None) -> Any:
    if not isinstance(d, dict):
        return default
    for k in keys:
        if k in d and d[k] is not None:
            return d[k]
    return default


def _slim_dials(dials: dict[str, dict[str, str]]) -> dict[str, dict[str, str]]:
    return {k: {"lv": v["level"], "tip": v["instruction"]} for k, v in dials.items()}


def normalize_series_outline(outline: dict) -> dict:
    """Canonical short-key series outline; accepts legacy long keys on input."""
    cast_raw = _pick(outline, "cast", "cast_spine", default=[]) or []
    cast_out: list[Any] = []
    if isinstance(cast_raw, list):
        for item in cast_raw:
            if isinstance(item, dict):
                cast_out.append(
                    {
                        "name": str(item.get("name") or "").strip(),
                        "move": str(item.get("move") or "").strip(),
                        "line": str(
                            _pick(item, "line", "catchphrase", default="") or ""
                        ).strip(),
                    }
                )
            elif isinstance(item, str) and item.strip():
                cast_out.append({"name": item.strip(), "move": "", "line": ""})

    threads_raw = outline.get("threads") or []
    threads_out: list[dict[str, Any]] = []
    if isinstance(threads_raw, list):
        for t in threads_raw:
            if not isinstance(t, dict):
                continue
            at = _pick(t, "at", "payoff_episode")
            try:
                at_n = int(at) if at is not None else None
            except (TypeError, ValueError):
                at_n = None
            threads_out.append(
                {
                    "id": str(t.get("id") or "").strip(),
                    "what": str(t.get("what") or "").strip(),
                    "at": at_n,
                }
            )

    eps_raw = outline.get("episodes") or []
    eps_out: list[dict[str, Any]] = []
    if isinstance(eps_raw, list):
        for i, ep in enumerate(eps_raw):
            if not isinstance(ep, dict):
                continue
            ep_no = _pick(ep, "ep", "episode_no", default=i + 1)
            try:
                ep_no = int(ep_no)
            except (TypeError, ValueError):
                ep_no = i + 1
            eps_out.append(
                {
                    "ep": ep_no,
                    "focus": str(_pick(ep, "focus", "focus_id", default="") or "").strip(),
                    "how": str(_pick(ep, "how", "focus_how", default="") or "").strip(),
                    "premise": str(ep.get("premise") or "").strip(),
                    "hook": str(
                        _pick(ep, "hook", "soft_promise", default="") or ""
                    ).strip(),
                    "plants": list(ep.get("plants") or [])
                    if isinstance(ep.get("plants"), list)
                    else [],
                    "payoffs": list(ep.get("payoffs") or [])
                    if isinstance(ep.get("payoffs"), list)
                    else [],
                    "sleep": str(
                        _pick(ep, "sleep", "sleep_note", default="") or ""
                    ).strip(),
                }
            )

    return {
        "title": str(outline.get("title") or "").strip(),
        "arc": str(_pick(outline, "arc", "throughline", default="") or "").strip(),
        "cast": cast_out,
        "threads": threads_out,
        "episodes": eps_out,
    }


def slice_series_context(outline: dict, episode_no: int) -> dict:
    """Episode-facing slice of a series outline for plan/draft prompts (short keys)."""
    norm = normalize_series_outline(outline) if outline else normalize_series_outline({})
    episodes = norm.get("episodes") or []
    ep = None
    for item in episodes:
        if int(item.get("ep") or 0) == int(episode_no):
            ep = item
            break
    if ep is None and episodes:
        idx = min(max(int(episode_no) - 1, 0), len(episodes) - 1)
        ep = episodes[idx]
    if ep is None:
        ep = {
            "ep": episode_no,
            "premise": "",
            "hook": "",
            "plants": [],
            "payoffs": [],
            "sleep": "",
            "focus": "",
            "how": "",
        }
    total = len(episodes) or int(episode_no)
    return {
        "title": norm.get("title") or "",
        "arc": norm.get("arc") or "",
        "cast": norm.get("cast") or [],
        "threads": norm.get("threads") or [],
        "ep": int(episode_no),
        "n": total,
        "finale": int(episode_no) >= total,
        "main": True,
        "ep_data": ep,
    }


# Mid-band whole years when birth_date / child_age_years is unavailable.
_AGE_BAND_YEARS = {
    "2-3": 3,
    "3-5": 4,
    "6-8": 7,
    "9-12": 10,
}


def prompt_age_years(request: StoryRequest) -> int:
    """Numeric age (years) for plan/draft LLM JSON."""
    if request.child_age_years is not None:
        try:
            return max(0, int(request.child_age_years))
        except (TypeError, ValueError):
            pass
    band = normalize_age_band(request.age_band)
    return int(_AGE_BAND_YEARS.get(band, 4))


def prompt_gender_label(request: StoryRequest) -> str:
    """Human-readable gender for plan/draft LLM JSON (by story language)."""
    from app.services.child_profile import gender_label_for_language

    label = gender_label_for_language(request.child_gender, request.language)
    if label:
        return label
    if (request.language or "zh").strip().lower().startswith("en"):
        return "unspecified"
    return "不指定"


def fantasy_score_from_wonder(wonder: str | None) -> int:
    level = normalize_dial("wonder", wonder)
    return int(WONDER_FANTASY_SCORE.get(level, 3))


def dialog_score_from_dialogue(dialogue: str | None) -> int:
    level = normalize_dial("dialogue", dialogue)
    return int(DIALOGUE_DIALOG_SCORE.get(level, 3))


def validate_episode_plan(
    plan: dict,
    *,
    lead_in: str = "soft",
    soft_series_mode: bool = False,
    beat_pattern: dict[str, Any] | None = None,
    opening_pattern: dict[str, Any] | None = None,
    cast_intro_mode: dict[str, str] | None = None,
    story_element: dict[str, Any] | None = None,
    target_feeling: str | None = None,
) -> dict:
    """Normalize LLM plan into lean dict for the simplified draft stage.

    Accepts the new schema (casts/desc, string beats, free-text shape) and
    legacy aliases. Catalog beat windows / forced shape ids are not enforced.
    """
    _ = (
        lead_in,
        soft_series_mode,
        beat_pattern,
        opening_pattern,
        cast_intro_mode,
        story_element,
        target_feeling,
    )
    missing = [
        canon
        for canon, aliases in PLAN_REQUIRED_ALIASES.items()
        if not any(a in plan for a in aliases)
    ]
    if missing:
        raise ValueError(f"episode plan missing keys: {missing}")

    title = str(_pick(plan, "title", "title_hint", default="") or "").strip() or "睡前故事"
    theme = plan.get("theme")
    if theme is not None:
        theme_s = str(theme).strip()
        theme = theme_s or None

    core_raw = _pick(plan, "core", "development_focus_label", default="")
    core = str(core_raw or "").strip() or None
    if core and len(core) > 32:
        core = core[:32]

    shape = str(_pick(plan, "shape", "story_shape", default="") or "").strip() or "自由结构"

    beats_raw = plan.get("beats")
    if not isinstance(beats_raw, list) or not beats_raw:
        raise ValueError("episode plan beats must be a non-empty list")
    beats: list[str] = []
    for i, src in enumerate(beats_raw):
        if isinstance(src, dict):
            action = str(src.get("action") or src.get("beat") or "").strip()
        else:
            action = str(src or "").strip()
        if not action:
            raise ValueError(f"episode plan beat {i + 1} missing text")
        beats.append(action)

    cast_raw = _pick(plan, "casts", "cast", "cast_use", default=[])
    casts: list[dict[str, str]] = []
    if isinstance(cast_raw, list):
        for item in cast_raw[:6]:
            if isinstance(item, dict):
                name = str(item.get("name") or "").strip()
                desc = str(
                    _pick(
                        item,
                        "desc",
                        "does",
                        "tonight_does",
                        "how_tonight",
                        "move",
                        "signature_move",
                        default="",
                    )
                    or ""
                ).strip()
                if name:
                    casts.append({"name": name, "desc": desc})
            elif isinstance(item, str) and item.strip():
                casts.append({"name": item.strip(), "desc": ""})
    if not casts:
        raise ValueError("episode plan casts must include at least one character")

    return {
        "title": title,
        "theme": theme,
        "core": core,
        "casts": casts,
        "beats": beats,
        "shape": shape,
    }


def build_outline_user_message(request: StoryRequest) -> str:
    payload = build_user_payload(request)
    count = clamp_episode_count(request.episode_count)
    dials = _slim_dials(payload["style_dials"])
    # Outline only needs wonder tip in full; others level-only.
    dials_out = {
        k: ({"lv": v["lv"], "tip": v["tip"]} if k == "wonder" else {"lv": v["lv"]})
        for k, v in dials.items()
    }
    outline_payload = {
        "n": count,
        "theme": payload["theme"],
        "lang": payload["language"],
        "audiences": payload.get("audiences") or [],
        "roster": payload.get("roster") or [],
        "cast_tip": payload["cast_hint"],
        "dials": dials_out,
        "age_how": payload["age_guidance"],
    }
    focus = payload.get("tonight_focus")
    if isinstance(focus, dict) and focus.get("id"):
        outline_payload["focus_pool"] = FOCUS_POOLS.get(payload["age_band"], [])
        outline_payload["focus_seed"] = {
            "id": focus.get("id"),
            "axis": focus.get("axis"),
            "label": focus.get("axis_label"),
        }
    # Task lead lives in LLM Agent user_prompt_template — payload is JSON only.
    return json.dumps(outline_payload, ensure_ascii=False)


def build_plan_user_message(
    request: StoryRequest,
    *,
    beat_pattern: dict[str, Any] | None = None,
    opening_pattern: dict[str, Any] | None = None,
    cast_intro_mode: dict[str, str] | None = None,
    recent_history: dict[str, Any] | None = None,
) -> str:
    """Assemble plan user JSON only (task lead is on the Agent user template)."""
    _ = (beat_pattern, opening_pattern, cast_intro_mode, recent_history)
    payload = build_user_payload(request)
    plan_payload = {
        "theme": payload["theme"],
        "audiences": payload.get("audiences") or [],
        "roster": payload.get("roster") or [],
        "fantasy": fantasy_score_from_wonder(request.wonder),
        "len": length_range_for_llm(request.language, payload["duration_minutes"]),
    }
    return json.dumps(plan_payload, ensure_ascii=False)


def build_user_message(request: StoryRequest, plan: dict | None = None) -> str:
    """Assemble simplified draft user JSON matching the draft system prompt."""
    payload = build_user_payload(request)
    draft: dict[str, Any] = {
        "title": (plan or {}).get("title") or payload["theme"] or "睡前故事",
        "theme": (plan or {}).get("theme") or payload["theme"],
        "casts": list((plan or {}).get("casts") or []),
        "beats": list((plan or {}).get("beats") or []),
        "audiences": payload.get("audiences") or [],
        "dialog": dialog_score_from_dialogue(request.dialogue),
        "len": length_range_for_llm(request.language, payload["duration_minutes"]),
    }
    # Legacy plan rows: cast/move/does → casts; beat objects → strings.
    if not draft["casts"]:
        legacy = (plan or {}).get("cast") or []
        if isinstance(legacy, list):
            for item in legacy:
                if isinstance(item, dict) and item.get("name"):
                    desc = str(
                        item.get("desc")
                        or item.get("does")
                        or item.get("move")
                        or ""
                    ).strip()
                    draft["casts"].append({"name": str(item["name"]).strip(), "desc": desc})
    if draft["beats"] and isinstance(draft["beats"][0], dict):
        draft["beats"] = [
            str(b.get("action") or "").strip()
            for b in draft["beats"]
            if isinstance(b, dict) and str(b.get("action") or "").strip()
        ]
    # Task lead lives in LLM Agent user_prompt_template — payload is JSON only.
    return json.dumps(draft, ensure_ascii=False)


def empty_recent_history() -> dict[str, Any]:
    return {
        "shapes_used": [],
        "themes_used": [],
        "core_elements_used": [],
        "last_summary": None,
    }


def history_fields_from_plan(plan: dict | None) -> dict[str, Any]:
    """Extract persistable history fields from a validated episode plan."""
    if not isinstance(plan, dict):
        return {}
    raw_shape = str(_pick(plan, "shape", "story_shape", default="") or "").strip() or None
    # Only persist catalog shape ids for soft-dedup; free-text shape notes are skipped.
    known = set(get_runtime_shape_ids()) or set(STORY_SHAPES)
    shape = raw_shape if raw_shape in known else None
    theme = plan.get("theme")
    if theme is not None:
        theme = str(theme).strip() or None
    core = _pick(plan, "props", "core_element") or []
    if isinstance(core, str):
        core = [core]
    core_list = [str(x).strip() for x in core if str(x).strip()]
    summary = None
    beats = plan.get("beats") or []
    if isinstance(beats, list) and beats:
        last = beats[-1]
        if isinstance(last, dict) and last.get("action"):
            summary = str(last.get("action")).strip()[:80]
        elif isinstance(last, str) and last.strip():
            summary = last.strip()[:80]
    return {
        "story_shape": shape,
        "theme": theme,
        "core_element": core_list,
        "last_summary": summary,
    }


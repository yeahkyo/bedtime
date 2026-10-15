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

# Rhythm frames from fairy / fable / folk / drama (bedtime-soft). Algorithm picks by theme+focus.
# Shared slots stay wish/snag/try_1/try_2/turn_ok so draft pipeline stays stable.
_BEAT_SLOTS = "wish, snag, try_1, try_2, turn_ok"
_ESCALATION_RULE = (
    "try_2 相对 try_1 必须升级或转变：换方法、换视角、换工具、或先收再放；"
    "禁止「同一动作更用力/再试一次」；禁止 try_2 只是被旁人直接解决。"
)

BEAT_PATTERNS: dict[str, dict[str, Any]] = {
    "two_gates": {
        "label": "两道小门槛",
        "lineage": "fairy",
        "theme_tags": (
            "找", "寻", "路", "门", "桥", "洞", "森林", "冒险", "火车", "旅行",
            "河", "山", "宝藏", "地图",
        ),
        "slots": _BEAT_SLOTS,
        "instruction": (
            "童话式小旅程：愿望前有两道轻门槛。"
            "try_1：直冲/催促/硬闯 → 被挡住或弄僵；"
            "try_2：观察、绕道、问路、或借一件具体小物 → 才过第二道。"
            f"{_ESCALATION_RULE}"
        ),
    },
    "misused_gift": {
        "label": "礼物先用错",
        "lineage": "fable",
        "theme_tags": (
            "礼物", "灯", "钥匙", "种子", "伞", "碗", "帽", "鞋", "魔", "工具",
            "箱子", "瓶",
        ),
        "slots": _BEAT_SLOTS,
        "instruction": (
            "寓言式：一件具体小物/能力先用错方向。"
            "try_1：用它求快/显摆/吓人 → 反而更糟或没用；"
            "try_2：改用它安抚、照路、分享、或修好一件小事 → 才贴合愿望。"
            f"{_ESCALATION_RULE}"
        ),
    },
    "home_and_back": {
        "label": "出门再回家",
        "lineage": "fairy",
        "theme_tags": (
            "家", "床", "出门", "回来", "月亮", "夜", "窗", "院子", "散步",
        ),
        "slots": _BEAT_SLOTS,
        "instruction": (
            "童话环状：离开熟悉处一点 → 遇见轻巧事 → 带着一点变化回家。"
            "try_1：想离开或想抓住什么却慌/急；"
            "try_2：用新发现的小办法（带回一件声响/触感/约定）安稳返回。"
            "turn_ok 要写清「回家后多了一点什么」。"
            f"{_ESCALATION_RULE}"
        ),
    },
    "helper_earned": {
        "label": "帮忙要换来",
        "lineage": "fairy",
        "theme_tags": (
            "朋友", "帮", "一起", "猫", "狗", "羊", "兔", "鸟", "伙伴", "哥哥",
            "姐姐",
        ),
        "slots": _BEAT_SLOTS,
        "instruction": (
            "童话求助：帮助不是白送。"
            "try_1：只喊/只催/只抢 → 对方不理或帮不上；"
            "try_2：先做一件具体小事（让位、递物、轻声问、等一等）→ 才换来协作。"
            f"{_ESCALATION_RULE}"
        ),
    },
    "soft_rule": {
        "label": "轻轻破规矩",
        "lineage": "fable",
        "theme_tags": (
            "分享", "轮流", "排队", "等待", "规矩", "先", "抢", "独享", "公平",
        ),
        "slots": _BEAT_SLOTS,
        "instruction": (
            "寓言式轻规矩：想抢先或独占。"
            "try_1：抢/占 → 卡住或两人都不开心；"
            "try_2：主动让一点、轮流、或立一个可执行的小约定 → 才顺。"
            "禁止说教点题「要学会分享」。"
            f"{_ESCALATION_RULE}"
        ),
    },
    "reframe_reveal": {
        "label": "误会翻面",
        "lineage": "drama",
        "theme_tags": (
            "怕", "暗", "影", "怪声", "躲", "误会", "怪", "空", "静", "风声",
        ),
        "slots": _BEAT_SLOTS,
        "instruction": (
            "戏剧翻面：把吓人的东西看清楚。"
            "try_1：躲开/捂住/猜错 → 更紧；"
            "try_2：靠近看/听/摸一下 → 发现是无理解的温和原因；安心来自「看懂了」。"
            f"{_ESCALATION_RULE}"
        ),
    },
    "echo_shift": {
        "label": "重复变奏",
        "lineage": "folk",
        "theme_tags": (
            "舞", "歌", "雨", "风", "脚步", "节奏", "敲", "摇", "重复", "铃",
        ),
        "slots": _BEAT_SLOTS,
        "instruction": (
            "民间反复式：同一母题做两次，第二次意义变了。"
            "try_1：重复一个动作求结果（更快/更大声）→ 不够或乱；"
            "try_2：同样母题改速度/力度/对象（更慢、更轻、对着某人）→ 才对上愿望。"
            f"{_ESCALATION_RULE}"
        ),
    },
    "threshold": {
        "label": "跨过门槛",
        "lineage": "drama",
        "theme_tags": (
            "第一次", "台阶", "岸", "水", "门缝", "高", "低", "敢", "试",
        ),
        "slots": _BEAT_SLOTS,
        "instruction": (
            "戏剧门槛：站在「差一点就跨过去」处。"
            "try_1：犹豫或假动作 → 退回；"
            "try_2：带着一件具体支撑（手、声、光、倒数）真正跨过一小步；"
            "turn_ok 写跨过后的身体感，不要空喊勇敢。"
            f"{_ESCALATION_RULE}"
        ),
    },
    "settle_ladder": {
        "label": "一级级静下来",
        "lineage": "ritual",
        "theme_tags": ("睡", "床", "枕", "被", "闭眼", "安静", "夜灯", "摇"),
        "slots": _BEAT_SLOTS,
        "instruction": (
            "仪式收束：先有一点轻动，再两级减速。"
            "try_1：还想玩/看/动 → 轻轻放下一样东西；"
            "try_2：再收一层（盖上、关一点光、声音变小）→ 才真正静。"
            "禁止突然睡着；禁止机械排比说晚安。"
            f"{_ESCALATION_RULE}"
        ),
    },
}

# focus_id → preferred frames (theme match can override / widen)
FOCUS_BEAT_MAP: dict[str, list[str]] = {
    "tiny_brave": ["two_gates", "threshold", "helper_earned"],
    "emotion_held": ["reframe_reveal", "helper_earned", "home_and_back"],
    "gentle_agency": ["misused_gift", "echo_shift", "two_gates"],
    "share_space": ["soft_rule", "helper_earned", "echo_shift"],
    "wind_down": ["settle_ladder", "home_and_back", "echo_shift"],
    "secure_presence": ["home_and_back", "helper_earned", "reframe_reveal"],
    "body_rhythm": ["settle_ladder", "echo_shift", "threshold"],
    "name_feeling": ["reframe_reveal", "settle_ladder", "home_and_back"],
    "try_persist": ["two_gates", "threshold", "misused_gift"],
    "friend_repair": ["helper_earned", "soft_rule", "reframe_reveal"],
    "fair_turn": ["soft_rule", "helper_earned", "echo_shift"],
    "mentalize_light": ["reframe_reveal", "soft_rule", "helper_earned"],
}

DEFAULT_BEAT_POOL = [
    "two_gates",
    "misused_gift",
    "home_and_back",
    "helper_earned",
    "soft_rule",
    "reframe_reveal",
    "echo_shift",
    "threshold",
    "settle_ladder",
]

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
            "可与开场白融在同一段口播里，但须让听者先认识人/地方，再进 wish。"
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

SYSTEM_PROMPT = """你是会讲睡前故事的家长旁白：写给幼儿**听**的口述晚安故事（像播客旁白，不是念书）。

优先级：安全入睡 > 听感 > 文采。职责是把 story_plan 落成可听口语；wish/try/弧光等创意结构已在 plan 定好，不要改写节拍含义。

听感：一句一事；先名词后人/动作；短对话；可摸可听的细节；场景物要参与动作。
可选稀疏标记（仅 body）：[pause:short] [pause:think] [pause:long] [slow] [soft] [warm]。

正文顺序：
1) 听前开场白（若 opening 非 none）：对听者说话，安顿注意力；轻点人物/背景/今晚软期待；再过渡进故事。禁止第一句就进书本式情节。
2) 角色/场景建档（若需要）可与开场白末尾自然衔接。
3) 按 wish/snag/try_1/try_2/turn_ok 原样落地（两段 try 保持 plan 里的不同动作，勿揉成「再试一次」）。
4) 系列 soft_hook（若有）→ 自然收束。

系列：plants 只埋；勿提前兑季终伏笔；soft_hook 与正文一致。
child_cast_role=absent 时不要出现孩子昵称。遵守 child_profile_guidance（若有）。

底线：单线今晚闭环；禁止暴力恐怖抛弃恐吓；禁止说教与照搬名著角色名；勿景点巡礼。
soft_hook 仅 soft_series_mode=true 时有一句，否则 null。
尽量达到 length_target。只输出 JSON：{"title","body","soft_hook"}
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

PLAN_SYSTEM_PROMPT = """你是睡前故事的单集构思助手（不写正文）。负责创意与结构：动机、节拍、弧光、听前开场白要点。按 beat_pattern 设计今晚可执行短构思。

要求：
- 严格遵守 beat_pattern.instruction（含 lineage 节奏）；填满 wish / snag / try_1 / try_2 / turn_ok。
- try_2 必须相对 try_1 有升级或转变（方法/视角/工具/节奏变了），禁止同动作加力，禁止旁人直接替做。创意决策在本阶段完成。
- 遵守 opening_pattern 与 cast_intro_mode。opening 非 none 时：
  opening_lines 写「听前开场白」提纲（4～6句要点）：安顿听者、点人物/背景、轻提今晚值得期待的小事；
  soft_promise 是那句软期待（可朗读）；opening_lines 不是第一句情节动作，勿剧透 try/turn。
- cast_use 至少两个角色，每人有 signature_move 与 how_tonight。
- 动作具体、单线、今晚安心收束；禁止说教与硬悬念。
- 有 series_context 时：wish 对齐 throughline 一小步；plants 只埋；soft_hook_hint 必填可朗读句。
- 遵守 child_profile_guidance（若有）：性别只轻轻影响称谓/倾向；intro 轻点即可。
- sleep_beat 一句自然收束即可，勿排比点名套话。

只输出 JSON（不要 markdown）：
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
                instruction += "此年龄开场白略短（约4～5句），词语具体、可摸可听。"
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


def _active_beat_catalog() -> tuple[dict[str, dict[str, Any]], dict[str, list[str]], list[str]]:
    """Prefer DB-backed runtime catalog; fall back to code constants."""
    try:
        from app.services.beat_patterns import (
            get_runtime_default_pool,
            get_runtime_focus_map,
            get_runtime_patterns,
        )

        patterns = get_runtime_patterns()
        if patterns:
            return patterns, get_runtime_focus_map(), get_runtime_default_pool()
    except Exception:
        pass
    return BEAT_PATTERNS, FOCUS_BEAT_MAP, list(DEFAULT_BEAT_POOL)


def _theme_matched_beats(
    theme: str | None, patterns: dict[str, dict[str, Any]]
) -> list[str]:
    """Beat ids whose theme_tags appear as substrings in the theme text."""
    text = (theme or "").strip().lower()
    if not text:
        return []
    hits: list[str] = []
    for pid, meta in patterns.items():
        tags = meta.get("theme_tags") or ()
        if any(str(tag).lower() in text for tag in tags):
            hits.append(pid)
    return hits


def select_beat_pattern(
    focus_id: str | None,
    *,
    theme: str | None = None,
    episode_no: int = 1,
    salt: str = "",
) -> dict[str, Any]:
    """Pick a rhythm frame by theme + focus (stable for same inputs).

    Catalog comes from DB (admin-editable) when seeded; otherwise code constants.
    """
    patterns, focus_map, default_pool = _active_beat_catalog()
    fid = (focus_id or "").strip()
    focus_opts = list(focus_map.get(fid) or default_pool)
    theme_hits = [p for p in _theme_matched_beats(theme, patterns) if p in patterns]

    if theme_hits:
        # Prefer theme ∩ focus; else theme hits; always keep a spare for variety.
        overlap = [p for p in theme_hits if p in focus_opts]
        options = overlap or theme_hits
        for pid in focus_opts:
            if pid not in options:
                options.append(pid)
                if len(options) >= 4:
                    break
    else:
        options = focus_opts

    options = [p for p in options if p in patterns] or list(default_pool)
    digest = hashlib.sha256(
        f"beat|{fid}|{theme or ''}|{episode_no}|{salt}".encode()
    ).hexdigest()
    idx = int(digest[:8], 16) % len(options)
    pid = options[idx]
    fallback_id = next(iter(patterns), "two_gates")
    meta = patterns.get(pid) or patterns.get(fallback_id) or BEAT_PATTERNS["two_gates"]
    resolved = pid if pid in patterns else fallback_id
    return {
        "id": resolved,
        "label": meta["label"],
        "lineage": meta.get("lineage") or "",
        "slots": meta.get("slots") or _BEAT_SLOTS,
        "instruction": meta.get("instruction") or "",
        "escalation": meta.get("escalation") or _ESCALATION_RULE,
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

    from app.services.child_profile import GENDER_LABELS_ZH, normalize_gender

    gender = normalize_gender(request.child_gender)
    intro = (request.child_intro or "").strip() or None
    profile_guidance = build_child_profile_guidance(
        gender=gender,
        intro=intro,
        nickname=request.child_nickname,
    )

    return {
        "child_nickname": request.child_nickname,
        "age_band": spec.band,
        "age_label": spec.label_zh,
        "age_guidance": spec.guidance,
        "child_gender": gender,
        "child_gender_label": GENDER_LABELS_ZH.get(gender, "不指定"),
        "child_intro": intro,
        "child_profile_guidance": profile_guidance,
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
            "听感优先：口语旁白，一句一事；遵守 length_target",
            "先听前开场白安顿听者，再渐入正文；勿像翻书开念",
            "忠实落地 story_plan；结尾自然收束；系列才写 soft_hook；勿说教",
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
        # Do not copy soft_promise into opening_lines — that injects the wrong beat as spoken prose.

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
        try_2 = (parts[1].strip() if len(parts) > 1 else "") or ""
    # Prefer model text; fall back to other plan fields only — never invent canned spoken lines.
    if not try_1:
        try_1 = try_beat or str(plan.get("wish") or "").strip()
    if not try_2:
        try_2 = str(plan.get("turn_ok") or "").strip() or try_beat
    plan["try_1"] = try_1
    plan["try_2"] = try_2
    plan["try_beat"] = try_beat or ("；".join(p for p in (try_1, try_2) if p))

    if beat_pattern:
        plan["beat_pattern"] = beat_pattern.get("id") or plan.get("beat_pattern") or "two_gates"
        plan["beat_pattern_meta"] = {
            "id": beat_pattern.get("id"),
            "label": beat_pattern.get("label"),
            "instruction": beat_pattern.get("instruction"),
        }
    else:
        plan.setdefault("beat_pattern", "two_gates")

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
    # Keep model sleep_beat as-is. Never inject canned spoken templates into the plan.
    plan["sleep_beat"] = str(plan.get("sleep_beat") or "").strip()
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
    beat = beat_pattern or select_beat_pattern(
        focus_id,
        theme=request.theme,
        episode_no=ep_no,
        salt=salt,
    )
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
            "child_gender",
            "child_gender_label",
            "child_intro",
            "child_profile_guidance",
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
        "负责创意与结构；必须遵守 beat_pattern、opening_pattern、cast_intro_mode；"
        "opening 非 none 时 opening_lines 须是听前开场白提纲（非第一句情节）。\n"
        if not (request.language or "zh").lower().startswith("en")
        else (
            "Output tonight's episode plan JSON only (no prose). "
            "Own creative structure; obey beat_pattern, opening_pattern, cast_intro_mode; "
            "if opening is not none, opening_lines must be a host warm-up outline, not plot beat one.\n"
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
                "warm_up_host_voice (own paragraphs)" if need_opening else "skip_opening",
                "cast_intro / setting_line (may blend end of warm-up)",
                "wish_snag_tries",
                "soft_hook then goodnight" if request.soft_series_mode else "goodnight",
            ],
            "must_land_warm_up_before_plot": need_opening,
            "forbid_book_like_cold_open": need_opening,
            "opening_lines": plan.get("opening_lines") or None,
            "soft_promise": plan.get("soft_promise") or None,
            "opening_pattern": plan.get("opening_pattern"),
            "cast_intro_mode": plan.get("cast_intro_mode"),
            "setting_line": plan.get("setting_line") or None,
            "must_include_try_1": plan.get("try_1"),
            "must_include_try_2": plan.get("try_2"),
            "land_try_beats_as_planned": True,
            "must_land_soft_hook_in_body": bool(request.soft_series_mode),
            "soft_hook_line": plan.get("soft_hook_hint") or None,
            "prefer_gentle_sleep_close": True,
            "forbid_parallel_goodnight_list": True,
            "sleep_beat": plan.get("sleep_beat") or None,
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
            + "写今晚的睡前故事（口语旁白，不是念书）。"
            "正文顺序：听前开场白（若需要）→ 角色/场景建档（若需要）→ 情节 → 软期待（系列）→ 晚安。"
            "开场白须先安顿听者并轻点人物/背景/软期待，再渐入正文。"
            "系列时正文末段（晚安前）必须出现 soft_hook 那句软期待。"
            "只输出 JSON 对象（不要 markdown）："
            '{"title","body","soft_hook"}。\n'
        )
    else:
        lead = (
            "Write tonight's bedtime story as spoken host narration (not reading a book), "
            "per the system rules, style_dials"
            + (", story_plan, and draft_checklist" if plan is not None else "")
            + ". Order: warm-up → cast intro → plot → soft_hook (series) → goodnight. "
            'Reply with ONLY a JSON object (no markdown): {"title","body","soft_hook"}.\n'
        )
    return lead + json.dumps(payload, ensure_ascii=False)

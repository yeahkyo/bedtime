# Providers

Text (story LLM) and speech (TTS + voice clone) are **independent**. App clients do not pick providers.

- **Story provider** defaults: Admin runtime override → `STORY_PROVIDER` → `PROVIDER_PROFILE` → mock.
- **Story model** (per stage): see [Model resolution](#story-model-resolution) below.
- **TTS / clone** follow the selected **Voice**: `Voice.provider` + optional `Voice.speech_model` (empty → env default for that provider). There is **no global Speech Provider** setting.

## Story provider selection order

1. Redis runtime override (`PATCH /admin/settings/providers`) — if set
2. `STORY_PROVIDER` env — if non-empty
3. `PROVIDER_PROFILE` preset (story LLM only)
4. `MOCK_PROVIDERS=1` → mock

| Profile | Story LLM |
|---------|-----------|
| `fish`（默认） | 豆包 Ark |
| `volc` / `aliyun` / `cosyvoice` | 豆包 Ark |
| `openai` | OpenAI |
| `deepseek` | DeepSeek |
| （`MOCK_PROVIDERS=1`） | Mock |

```bash
STORY_PROVIDER=doubao          # doubao | openai | deepseek | mock
STORY_SKIP_TTS=0               # optional: 1 = skip TTS after LLM (text-only ready)
```

## Story model resolution

Admin entities (not a “catalog” name in code):

| Admin | Table | Role |
|-------|-------|------|
| **LLM 模型** | `llm_models` | Admin-managed instances: `provider` + `model_id` + optional **tier** label (`mini` \| `lite` \| `pro`). **Not auto-seeded.** |
| **LLM 路由** | `llm_routing_rules` | Match stage + conditions → **`target_llm_model_id`** (binds a full instance, can cross providers). Not auto-seeded. |
| **Provider 设置** | Redis | Optional **force** `story_model` (kill-switch); empty = routing / env apply. Global `story_provider` is fallback when no route/agent pin. |

**Per-stage resolve priority** (see `services/llm_routing.py`):

1. Runtime Redis `story_model` (force)
2. Agent row `model` (pin; leave empty to allow routing)
3. First matching enabled routing rule → that `llm_models` row (`provider` + `model_id`)
4. Env default for fallback provider (`ARK_MODEL` / `OPENAI_MODEL` / `DEEPSEEK_MODEL`)

Example: register two instances, then rules on `story_draft` with `{"duration_minutes_max": 5}` → mini instance and `{}` → pro instance (possibly different providers). Any agent stage can have rules.

When `STORY_SKIP_TTS=1`, the job finishes after outline/plan/draft with `status=ready` and no audio. Default is off (`0`).

Story rows store `story_provider` + `story_model` + `speech_provider` (+ `speech_model`) for admin list/filter. Stage metrics include `model` / `tier` / `policy_reason` (detail prefers metrics; list falls back to them when the column is empty).

TTS 在 **音色**页配置每条 `Voice.provider` / `Voice.speech_model` / `provider_voice_id`。克隆默认跟随一条已启用的全局系统音色的 `provider`（否则探测已配置 key 的 speech 后端）。

## Fish Audio（默认语音）

```bash
FISH_AUDIO_API_KEY=...
FISH_AUDIO_DEFAULT_VOICE_ID=...   # library / custom model id for system voice
FISH_AUDIO_TTS_MODEL=s2-pro
FISH_AUDIO_BASE_URL=https://api.fish.audio
```

Clone creates a persistent model (`POST /model`), polls until `trained`, stores id as `provider_voice_id`. TTS uses `reference_id`. No Volc-style SSML — bedtime narration post-processes sentence/paragraph pauses into S2 bracket cues `[break]` / `[long-break]` in the speak text (display body stays clean).

## Volc / 豆包

```bash
ARK_API_KEY=...                 # 方舟大模型（故事）
ARK_MODEL=doubao-seed-1.6-250615
ARK_BASE_URL=https://ark.cn-beijing.volces.com/api/v3

VOLC_SPEECH_API_KEY=...         # 豆包语音控制台 API Key（可与 Ark 不同）
VOLC_TTS_RESOURCE_ID=seed-tts-2.0
VOLC_ICL_RESOURCE_ID=seed-icl-2.0
VOLC_DEFAULT_SPEAKER=zh_female_vv_uranus_bigtts
```

系统音色用 `VOLC_DEFAULT_SPEAKER`；克隆音色用 openspeech `voice_clone` 后付费 `custom_speaker_id`。

声音克隆需在控制台单独开通 **声音复刻 / Seed-ICL 2.0**（与「语音合成 2.0」不是同一商品）。未开通时 clone 会返回 `45000030 requested resource not granted`（常见内部 resource：`volc.megatts.timbre`）。
克隆成功后的朗读走 `seed-icl-2.0`，并在 `additions` 中带 `model_type: 4`。

## Aliyun / 百炼 CosyVoice

```bash
# Create/enable an Admin Voice with provider=aliyun (no global SPEECH_PROVIDER).

ALIYUN_DASHSCOPE_API_KEY=...    # 或 DASHSCOPE_API_KEY
ALIYUN_TTS_WORKSPACE_ID=...     # 业务空间 ID（专属域名）；空则回退 dashscope.aliyuncs.com
ALIYUN_TTS_REGION=cn-beijing    # 或 ap-southeast-1
ALIYUN_TTS_MODEL=cosyvoice-v3-flash
ALIYUN_TTS_DEFAULT_VOICE=longanyang
# ALIYUN_TTS_BASE_URL=          # 可选：覆盖 api/v1 根或完整 SpeechSynthesizer URL
```

- TTS：`POST …/services/audio/tts/SpeechSynthesizer`（优先 SSE；无流式块时下载 `output.audio.url`）
- 系统音色：`ALIYUN_TTS_DEFAULT_VOICE`（如 `longanyang`）
- 克隆：`voice-enrollment` / `create_voice`；样本需**公网可访问 URL**（实现会先上传到 S3/R2 再传 URL）。本地 `STORAGE_BACKEND=local` 时克隆不可用
- 复刻音色的 `target_model` 必须与 `ALIYUN_TTS_MODEL` / Admin `speech_model` 一致
- 睡前停顿：TTS 前注入 CosyVoice SSML（`<speak>` + `<break time="…ms"/>`，`enable_ssml=true`）；个别音色不支持时自动降级为标点呼吸
- CosyVoice 易乱读符号（`——`、装饰符、零宽字符等）仅在 **speak/SSML** 侧换成 `，` 等停顿，展示正文保留原样

## DeepSeek（故事）

```bash
DEEPSEEK_API_KEY=...
DEEPSEEK_BASE_URL=https://api.deepseek.com
DEEPSEEK_MODEL=deepseek-flash
# Story CoT (default on). Set DEEPSEEK_THINKING=false to cut latency/cost.
DEEPSEEK_THINKING=true
DEEPSEEK_REASONING_EFFORT=low   # ceiling: low | medium | high | max
```

设 `STORY_PROVIDER=deepseek` 或 Admin「Provider 设置」切换；语音跟所选 `Voice.provider`。

故事请求默认开 thinking；`reasoning_effort` 按 stage 取低值（outline / plan / draft 均为 `low`），`DEEPSEEK_REASONING_EFFORT` 只作上限不能再抬高。API 的 `max_tokens` = **可见 JSON 预算**（agent / `max_tokens_for_story`）+ **该 effort 的 CoT 预留**（共用一个桶）。截断时优先 **关掉 thinking 重试**，而不是胀额度再跑一轮长 CoT。Admin 目录编撰仍关 thinking。

## OpenAI + ElevenLabs

```bash
OPENAI_API_KEY=...
OPENAI_MODEL=gpt-4o-mini
ELEVENLABS_API_KEY=...
ELEVENLABS_DEFAULT_VOICE_ID=...
ELEVENLABS_MODEL_ID=eleven_multilingual_v2
```

## Admin

- Vue admin: [`apps/admin`](../apps/admin/) — Docker profile `admin`, host port **8083**
- Login: `ADMIN_BOOTSTRAP_USERNAME` / `ADMIN_BOOTSTRAP_PASSWORD`
- APIs under `/admin/` (auth, users, stories, settings/providers)
- Runtime provider defaults: Redis key `bedtime:runtime_settings`

## Story prompt（豆包 / OpenAI 共用）

实现见 `apps/api/app/providers/story_prompt.py`；阶段 Agent 配置见 Admin **LLM Agents**（`apps/api/app/services/llm_agents.py`）：

- 中文主 system：入睡优先、场景跟主题、禁说教与照搬名著（约束偏软）
- **分工**：代码只组装纯 JSON `user_payload`；任务说明（lead）写在各 Agent 的 `user_prompt_template`（可 Admin 编辑）。Admin「可用变量」只列出默认模板实际用到的占位符（通常仅 `{{user_payload}}`；软系列大纲另有 `{{episode_count}}`）
- `age_band`（`2-3` / `3-5` / `6-8` / `9-12`）只注入简短 `age_guidance`
- LLM JSON 用短字段名（如 plan：`shape`/`feel`/`hook`；draft 输出 `hook`；系列 `arc`/`cast`/`ep`）；API 请求参数名不变
- `focus`：仅 axis 级软引力 `{id, axis, label}`；kernel 长文不进成文 prompt；与客观 `element` 分工
- `POST /stories`：`character_ids`、`keywords`、`values`、`development_focus`、`child_cast_role`、`recap`
- 角色库：`/v1/characters`（`kind`: child|person|toy）；创建小孩会自动生成 `kind=child` 孪生行；今晚勾选写入 prompt `roster`，并快照到 `params_json.characters_snapshot`
- 风格档位（各 3 档，注入 `dials`：`{lv, tip}`）：
  - `plot_drive`: mood | light | arc
  - `imagery`: sparse | balanced | rich
  - `wonder`: everyday | soft | fantasy
  - `wind_down`: deep | gentle | playful
  - `dialogue`: low | some | more
- 篇幅三档（App）→ 内部 `duration_minutes`：短=`3`（文案约 2–4 分）、中=`5`（约 4–7 分）、长=`10`（约 8–12 分）。LLM `len` 按参考分钟 ±1 × 语速（短参考 **4**、中 **7**、长 **10**；中文 **220 字/分**，英文 **100 words/分**）；如中篇 `len`=`"1320-1760"`；非三档入参会 snap 到最近档；`max_tokens` 按上限估算
- `keywords` 为未建档临时补充；档案 `interests` 仅作轻度 likes，不并入 kw；`PATCH /children/{id}` 可改昵称/年龄/兴趣
- 发展焦点可覆盖；母题白名单只借鉴安心内核

## Adding a vendor

Implement `StoryProvider` and/or `TtsProvider` + `VoiceCloneProvider`, register in `factory.py`, extend allowlists in `provider_settings.py`.

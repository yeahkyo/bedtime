# Providers

Text (story LLM) and speech (TTS + voice clone) are **independent**. App clients do not pick providers; defaults come from env / admin runtime override. TTS/clone for a request follow `Voice.provider`.

## Selection order

1. Redis runtime override (`PATCH /admin/settings/providers`) — if set
2. `STORY_PROVIDER` / `SPEECH_PROVIDER` env — if non-empty
3. `PROVIDER_PROFILE` preset
4. `MOCK_PROVIDERS=1` → all mock

| Profile | Story LLM | TTS / Clone |
|---------|-----------|-------------|
| `fish`（默认） | 豆包 Ark | Fish Audio |
| `volc` | 豆包 Ark | 火山豆包语音（槽位暂停时可不用） |
| `openai` | OpenAI | ElevenLabs |
| `deepseek` | DeepSeek | Fish Audio |
| （`MOCK_PROVIDERS=1`） | Mock | Mock |

Independent knobs:

```bash
STORY_PROVIDER=doubao          # doubao | openai | deepseek | mock
SPEECH_PROVIDER=fishaudio      # fishaudio | volc | elevenlabs | mock
```

Story rows store `story_provider` + `speech_provider` for admin comparison.

## Fish Audio（默认语音）

```bash
FISH_AUDIO_API_KEY=...
FISH_AUDIO_DEFAULT_VOICE_ID=...   # library / custom model id for system voice
FISH_AUDIO_TTS_MODEL=s2-pro
FISH_AUDIO_BASE_URL=https://api.fish.audio
```

Clone creates a persistent model (`POST /model`), polls until `trained`, stores id as `provider_voice_id`. TTS uses `reference_id`. No Volc-style SSML — narration uses punctuation breaths.

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

## DeepSeek（故事）

```bash
DEEPSEEK_API_KEY=...
DEEPSEEK_BASE_URL=https://api.deepseek.com
DEEPSEEK_MODEL=deepseek-flash
```

设 `STORY_PROVIDER=deepseek` 或 Admin「Provider 设置」切换；语音仍跟 `SPEECH_PROVIDER` / `Voice.provider`。请求固定 `thinking.type=disabled`（关 CoT），并用 JSON `response_format`。

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

实现见 `apps/api/app/providers/story_prompt.py`：

- 中文主 system：入睡优先、场景跟主题、禁说教与照搬名著（约束偏软）
- `age_band`（`2-3` / `3-5` / `6-8`）只注入简短 `age_guidance`
- `POST /stories`：`keywords`、`values`、`development_focus`、`child_cast_role`、`recap`
- 风格档位（各 3 档，注入 `style_dials` 行为指令）：
  - `plot_drive`: mood | light | arc
  - `imagery`: sparse | balanced | rich
  - `wonder`: everyday | soft | fantasy
  - `wind_down`: deep | gentle | playful
  - `dialogue`: low | some | more
- 时长 → 篇幅（`length_target`，按语种分开估算，±12%）：
  - 中文：约 **230 字/分钟**（汉字）
  - 英文：约 **130 words/分钟**
- `keywords` 与孩子 `interests` 合并；`PATCH /children/{id}` 可改昵称/年龄/兴趣
- 发展焦点可覆盖；母题白名单只借鉴安心内核

## Adding a vendor

Implement `StoryProvider` and/or `TtsProvider` + `VoiceCloneProvider`, register in `factory.py`, extend allowlists in `provider_settings.py`.

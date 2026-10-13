# Provider profiles

`PROVIDER_PROFILE` selects the vendor stack (when `MOCK_PROVIDERS=0`):

| Profile | Story LLM | TTS / Clone |
|---------|-----------|-------------|
| `volc`（默认） | 豆包 Ark（`ARK_API_KEY`） | 火山豆包语音 openspeech（`VOLC_SPEECH_API_KEY`，缺省回退 `ARK_API_KEY`） |
| `openai` | OpenAI | ElevenLabs |
| （`MOCK_PROVIDERS=1`） | Mock | Mock |

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

## Swap / Runpod later

Implement `StoryProvider` / `TtsProvider` / `VoiceCloneProvider` and branch in `factory.py`.

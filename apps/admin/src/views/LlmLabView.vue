<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { api } from '@/api/client'

type AgentId = 'story_episode_plan' | 'story_series_outline' | 'story_draft'

interface DefaultsOut {
  agent_id: string
  label_zh: string
  description: string
  system_prompt: string
  user_prompt_template: string
  max_tokens: number | null
  timeout_seconds: number | null
  temperature: number | null
  provider: string | null
  model: string | null
  from_db: boolean
  enabled?: boolean
}

interface PreviewOut {
  agent_id: string
  stage: string
  user_payload: string
  system: string
  user: string
  extra_vars: Record<string, unknown>
  resolved_provider: string | null
  resolved_model: string | null
  max_tokens: number
  timeout_seconds: number
  temperature: number
  from_db: boolean
  raw_content?: string
  parsed?: Record<string, unknown> | null
  parse_error?: string | null
  ms?: number
  usage?: Record<string, unknown>
}

const AGENTS: { id: AgentId; label: string }[] = [
  { id: 'story_episode_plan', label: '单集构思 (plan)' },
  { id: 'story_series_outline', label: '软系列大纲 (outline)' },
  { id: 'story_draft', label: '正文润色 (draft)' },
]

const SAMPLE_PLAN = `{
  "title": "窗边的月亮",
  "theme": "一点暖光也能安心",
  "casts": [{"name": "豆豆", "desc": "爱踮脚看月亮的孩子"}],
  "beats": ["踮脚看月亮", "发现倒影", "靠着窗坐下"],
  "shape": "一点点靠近再安静"
}`

const agentId = ref<AgentId>('story_episode_plan')
const loadingDefaults = ref(false)
const previewing = ref(false)
const running = ref(false)
const savingVersion = ref(false)
const labVersionNote = ref('')

const theme = ref('我不想睡觉')
const themeMode = ref<'seed' | 'plot'>('seed')
const language = ref('zh')
const ageBand = ref('3-5')
const durationMinutes = ref(5)
const wonder = ref('soft')
const dialogue = ref('some')
const childNickname = ref('豆豆')
const childGender = ref('unspecified')
const childAgeYears = ref(4)
const softSeries = ref(false)
const episodeCount = ref(4)
const planJson = ref(SAMPLE_PLAN)

const systemPrompt = ref('')
const userTemplate = ref('')
const temperature = ref<number | undefined>(undefined)
const agentMeta = ref<DefaultsOut | null>(null)

const result = ref<PreviewOut | null>(null)
const activeTab = ref('payload')

const needsPlan = computed(() => agentId.value === 'story_draft')

function buildBody() {
  let plan: Record<string, unknown> | undefined
  if (needsPlan.value) {
    try {
      const parsed = JSON.parse(planJson.value) as unknown
      if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
        throw new Error('plan 必须是 JSON 对象')
      }
      plan = parsed as Record<string, unknown>
    } catch (e) {
      throw new Error(e instanceof Error ? e.message : 'plan JSON 无效')
    }
  }
  return {
    agent_id: agentId.value,
    theme: theme.value,
    theme_mode: themeMode.value,
    language: language.value,
    age_band: ageBand.value,
    duration_minutes: durationMinutes.value,
    wonder: wonder.value,
    dialogue: dialogue.value,
    child_nickname: childNickname.value,
    child_gender: childGender.value,
    child_age_years: childAgeYears.value,
    soft_series_mode: softSeries.value,
    episode_count: episodeCount.value,
    need_series_outline: agentId.value === 'story_series_outline',
    plan,
    system_prompt: systemPrompt.value,
    user_prompt_template: userTemplate.value,
    temperature: temperature.value,
  }
}

async function loadDefaults() {
  loadingDefaults.value = true
  try {
    const { data } = await api.get<DefaultsOut>('/admin/llm-lab/defaults', {
      params: { agent_id: agentId.value },
    })
    agentMeta.value = data
    systemPrompt.value = data.system_prompt
    userTemplate.value = data.user_prompt_template
    temperature.value = data.temperature ?? undefined
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '加载 Agent 默认失败')
  } finally {
    loadingDefaults.value = false
  }
}

async function preview() {
  previewing.value = true
  result.value = null
  try {
    const body = buildBody()
    const { data } = await api.post<PreviewOut>('/admin/llm-lab/preview', body)
    result.value = data
    activeTab.value = 'assembled'
    ElMessage.success('已组装提示词（未调用模型）')
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '组装失败')
  } finally {
    previewing.value = false
  }
}

async function run() {
  running.value = true
  result.value = null
  try {
    const body = buildBody()
    const { data } = await api.post<PreviewOut>('/admin/llm-lab/run', body, {
      timeout: 300_000,
    })
    result.value = data
    activeTab.value = data.parsed ? 'parsed' : 'raw'
    if (data.parse_error) {
      ElMessage.warning(`已返回，但解析告警：${data.parse_error}`)
    } else {
      ElMessage.success(`完成 ${data.ms ?? '?'} ms`)
    }
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '调用失败')
  } finally {
    running.value = false
  }
}

async function saveAsAgentVersion() {
  const label = AGENTS.find((a) => a.id === agentId.value)?.label || agentId.value
  try {
    await ElMessageBox.confirm(
      `将把试验台中的 system / user / temperature 写回「${label}」并立即生效（故事管线会用这份 Agent），同时插入一版 lab_save 历史。确定？`,
      '存为 Agent 新版本并生效',
      { type: 'warning', confirmButtonText: '写入并生效', cancelButtonText: '取消' },
    )
  } catch {
    return
  }
  savingVersion.value = true
  try {
    await api.post(`/admin/llm-agents/${agentId.value}/lab-save`, {
      system_prompt: systemPrompt.value,
      user_prompt_template: userTemplate.value,
      temperature: temperature.value ?? null,
      clear_temperature: temperature.value == null,
      version_note: labVersionNote.value.trim() || '试验台存为新版本',
    })
    labVersionNote.value = ''
    ElMessage.success('已写入 Agent 并落新版本')
    await loadDefaults()
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '保存失败')
  } finally {
    savingVersion.value = false
  }
}

watch(agentId, () => {
  result.value = null
  void loadDefaults()
})

onMounted(() => {
  void loadDefaults()
})
</script>

<template>
  <div class="lab">
    <div class="toolbar">
      <div>
        <h2>LLM 试验台</h2>
        <p class="hint">
          用真实 StoryRequest → 代码组装 user_payload → Agent 模板渲染。默认可改模板做对比；点「存为
          Agent 新版本」才会写回线上 Agent。
        </p>
      </div>
      <div class="actions">
        <el-button :loading="loadingDefaults" @click="loadDefaults">重载 Agent 默认</el-button>
        <el-button :loading="previewing" @click="preview">组装预览</el-button>
        <el-button type="primary" :loading="running" @click="run">调用 LLM</el-button>
        <el-button
          type="warning"
          :loading="savingVersion"
          @click="saveAsAgentVersion"
        >
          存为 Agent 新版本并生效
        </el-button>
      </div>
    </div>

    <el-row :gutter="16">
      <el-col :xs="24" :lg="10">
        <el-card shadow="never" class="panel">
          <template #header>阶段与输入</template>
          <el-form label-width="100px" size="small">
            <el-form-item label="Agent">
              <el-select v-model="agentId" style="width: 100%">
                <el-option
                  v-for="a in AGENTS"
                  :key="a.id"
                  :label="a.label"
                  :value="a.id"
                />
              </el-select>
              <div v-if="agentMeta" class="meta">
                {{ agentMeta.label_zh }}
                · {{ agentMeta.from_db ? 'DB' : 'code default' }}
                <span v-if="agentMeta.enabled === false"> · 已禁用（试验台仍读写库内文案）</span>
                <span v-if="agentMeta.provider || agentMeta.model">
                  · pin {{ agentMeta.provider || '—' }}/{{ agentMeta.model || '—' }}
                </span>
              </div>
            </el-form-item>
            <el-form-item label="theme">
              <el-input v-model="theme" type="textarea" :rows="2" maxlength="280" show-word-limit />
            </el-form-item>
            <el-form-item label="theme_mode">
              <el-radio-group v-model="themeMode">
                <el-radio-button value="seed">seed</el-radio-button>
                <el-radio-button value="plot">plot</el-radio-button>
              </el-radio-group>
            </el-form-item>
            <el-form-item label="language">
              <el-select v-model="language" style="width: 120px">
                <el-option label="zh" value="zh" />
                <el-option label="en" value="en" />
              </el-select>
            </el-form-item>
            <el-form-item label="age_band">
              <el-select v-model="ageBand" style="width: 140px">
                <el-option label="2-3" value="2-3" />
                <el-option label="3-5" value="3-5" />
                <el-option label="6-8" value="6-8" />
                <el-option label="9-12" value="9-12" />
              </el-select>
            </el-form-item>
            <el-form-item label="duration">
              <el-input-number v-model="durationMinutes" :min="2" :max="12" />
              <span class="muted"> 分钟</span>
            </el-form-item>
            <el-form-item label="wonder">
              <el-select v-model="wonder" style="width: 160px">
                <el-option label="everyday" value="everyday" />
                <el-option label="soft" value="soft" />
                <el-option label="fantasy" value="fantasy" />
              </el-select>
            </el-form-item>
            <el-form-item label="dialogue">
              <el-select v-model="dialogue" style="width: 160px">
                <el-option label="low" value="low" />
                <el-option label="some" value="some" />
                <el-option label="more" value="more" />
              </el-select>
            </el-form-item>
            <el-form-item label="昵称 / 年龄">
              <el-input v-model="childNickname" style="width: 120px" />
              <el-input-number
                v-model="childAgeYears"
                :min="0"
                :max="18"
                style="margin-left: 8px"
              />
            </el-form-item>
            <el-form-item label="gender">
              <el-select v-model="childGender" style="width: 160px">
                <el-option label="unspecified" value="unspecified" />
                <el-option label="boy" value="boy" />
                <el-option label="girl" value="girl" />
              </el-select>
            </el-form-item>
            <el-form-item v-if="agentId === 'story_series_outline'" label="集数">
              <el-input-number v-model="episodeCount" :min="2" :max="8" />
            </el-form-item>
            <el-form-item label="软系列">
              <el-switch v-model="softSeries" />
            </el-form-item>
            <el-form-item v-if="needsPlan" label="plan JSON">
              <el-input v-model="planJson" type="textarea" :rows="10" class="mono" />
            </el-form-item>
            <el-form-item label="temperature">
              <el-input-number
                v-model="temperature"
                :min="0"
                :max="2"
                :step="0.1"
                :controls="true"
              />
              <el-button link type="info" style="margin-left: 8px" @click="temperature = undefined">
                跟随 Agent
              </el-button>
            </el-form-item>
          </el-form>
        </el-card>

        <el-card shadow="never" class="panel">
          <template #header>提示词模板（可改；默认不落库）</template>
          <el-form label-position="top" size="small">
            <el-form-item label="system_prompt">
              <el-input v-model="systemPrompt" type="textarea" :rows="12" class="mono" />
            </el-form-item>
            <el-form-item label="user_prompt_template">
              <el-input v-model="userTemplate" type="textarea" :rows="6" class="mono" />
              <div class="hint">
                须保留 <code v-pre>{{user_payload}}</code>；outline 另可用
                <code v-pre>{{episode_count}}</code>
              </div>
            </el-form-item>
            <el-form-item label="版本备注（写回时）">
              <el-input
                v-model="labVersionNote"
                maxlength="256"
                show-word-limit
                placeholder="可选，随「存为 Agent 新版本」一起记录"
              />
            </el-form-item>
          </el-form>
        </el-card>
      </el-col>

      <el-col :xs="24" :lg="14">
        <el-card shadow="never" class="panel">
          <template #header>
            <div class="result-head">
              <span>结果</span>
              <span v-if="result" class="muted">
                {{ result.resolved_provider }}/{{ result.resolved_model }}
                · tokens {{ result.max_tokens }}
                · {{ result.timeout_seconds }}s
                <template v-if="result.ms != null"> · {{ result.ms }} ms</template>
              </span>
            </div>
          </template>

          <el-empty v-if="!result" description="先「组装预览」或「调用 LLM」" />
          <template v-else>
            <el-alert
              v-if="result.parse_error"
              type="warning"
              :title="result.parse_error"
              show-icon
              :closable="false"
              class="mb"
            />
            <el-tabs v-model="activeTab">
              <el-tab-pane label="user_payload" name="payload">
                <pre class="json">{{ result.user_payload }}</pre>
              </el-tab-pane>
              <el-tab-pane label="组装后 system" name="assembled">
                <pre class="json">{{ result.system }}</pre>
              </el-tab-pane>
              <el-tab-pane label="组装后 user" name="user">
                <pre class="json">{{ result.user }}</pre>
              </el-tab-pane>
              <el-tab-pane v-if="result.raw_content != null" label="模型原文" name="raw">
                <pre class="json">{{ result.raw_content }}</pre>
              </el-tab-pane>
              <el-tab-pane v-if="result.parsed" label="解析 JSON" name="parsed">
                <pre class="json">{{ JSON.stringify(result.parsed, null, 2) }}</pre>
              </el-tab-pane>
              <el-tab-pane label="usage / extra" name="meta">
                <pre class="json">{{
                  JSON.stringify(
                    { extra_vars: result.extra_vars, usage: result.usage || {} },
                    null,
                    2,
                  )
                }}</pre>
              </el-tab-pane>
            </el-tabs>
          </template>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<style scoped>
.lab {
  max-width: 1400px;
}
.toolbar {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  align-items: flex-start;
  margin-bottom: 12px;
}
.toolbar h2 {
  margin: 0 0 4px;
  font-size: 20px;
}
.hint {
  margin: 0;
  color: var(--el-text-color-secondary);
  font-size: 13px;
  line-height: 1.45;
}
.actions {
  display: flex;
  gap: 8px;
  flex-shrink: 0;
}
.panel {
  margin-bottom: 16px;
}
.meta {
  margin-top: 4px;
  font-size: 12px;
  color: var(--el-text-color-secondary);
}
.muted {
  color: var(--el-text-color-secondary);
  font-size: 12px;
}
.mono :deep(textarea) {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 12px;
  line-height: 1.45;
}
.json {
  margin: 0;
  padding: 12px;
  background: #0f1115;
  color: #e8e6df;
  border-radius: 8px;
  overflow: auto;
  max-height: 70vh;
  font-size: 12px;
  line-height: 1.45;
  white-space: pre-wrap;
  word-break: break-word;
}
.result-head {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  align-items: baseline;
  width: 100%;
}
.mb {
  margin-bottom: 12px;
}
</style>

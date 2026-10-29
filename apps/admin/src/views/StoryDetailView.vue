<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { api } from '@/api/client'
import type { AdminStoryDetailOut, AdminStoryTtsInputOut } from '@/api/types'
import { formatAdminTime } from '@/utils/datetime'

const route = useRoute()
const router = useRouter()
const loading = ref(false)
const story = ref<AdminStoryDetailOut | null>(null)
const recomputedTts = ref<AdminStoryTtsInputOut | null>(null)
const recomputingTts = ref(false)
const retrying = ref(false)

const canRetry = computed(() => {
  const s = story.value?.status
  return s === 'failed' || s === 'generating'
})

function prettyJson(raw: string | null | undefined): string {
  if (!raw) return ''
  try {
    return JSON.stringify(JSON.parse(raw), null, 2)
  } catch {
    return raw
  }
}

const episodePlanPretty = computed(() => prettyJson(story.value?.episode_plan_json))
const paramsPretty = computed(() => prettyJson(story.value?.params_json))
const metricsPretty = computed(() => prettyJson(story.value?.metrics_json))

const STAGE_LABELS: Record<string, string> = {
  series_outline: '系列大纲',
  episode_plan: '单集构思',
  draft: '正文',
}

const submittedPrompts = computed(() => {
  const raw = story.value?.prompts_json
  if (!raw) return []
  try {
    const data = JSON.parse(raw) as { stages?: unknown } | unknown[]
    const stages = Array.isArray(data) ? data : data.stages
    if (!Array.isArray(stages)) return []
    return stages
      .filter((row) => row && typeof row === 'object')
      .map((row) => {
        const o = row as Record<string, unknown>
        const stage = typeof o.stage === 'string' ? o.stage : 'stage'
        return {
          stage,
          label: STAGE_LABELS[stage] || stage,
          system: typeof o.system === 'string' ? o.system : '',
          user: typeof o.user === 'string' ? o.user : '',
        }
      })
  } catch {
    return []
  }
})
const seriesOutlinePretty = computed(() => prettyJson(story.value?.series?.outline_json))

const WONDER_LABELS: Record<string, string> = {
  everyday: '生活向',
  soft: '轻想象',
  fantasy: '更幻想',
}

const DIALOGUE_LABELS: Record<string, string> = {
  low: '少对话',
  some: '适量对话',
  more: '多对话',
}

const THEME_MODE_LABELS: Record<string, string> = {
  seed: '给灵感',
  plot: '按情节',
}

const THEME_SOURCE_LABELS: Record<string, string> = {
  user: '用户填写',
  hint: '留空·用了 hint 例子',
  fallback: '服务端兜底',
}

const createDialSummary = computed(() => {
  const raw = story.value?.params_json
  if (!raw) return null
  try {
    const p = JSON.parse(raw) as Record<string, unknown>
    const wonder = typeof p.wonder === 'string' ? p.wonder : null
    const dialogue = typeof p.dialogue === 'string' ? p.dialogue : null
    const themeMode = typeof p.theme_mode === 'string' ? p.theme_mode : null
    const themeSource = typeof p.theme_source === 'string' ? p.theme_source : null
    if (!wonder && !dialogue && !themeMode && !themeSource) return null
    return {
      wonder,
      wonderLabel: wonder ? WONDER_LABELS[wonder] || wonder : null,
      dialogue,
      dialogueLabel: dialogue ? DIALOGUE_LABELS[dialogue] || dialogue : null,
      themeMode,
      themeModeLabel: themeMode ? THEME_MODE_LABELS[themeMode] || themeMode : null,
      themeSource,
      themeSourceLabel: themeSource
        ? THEME_SOURCE_LABELS[themeSource] || themeSource
        : null,
    }
  } catch {
    return null
  }
})

const seriesEpisodeRows = computed(() => {
  const eps = story.value?.series?.episodes
  if (!Array.isArray(eps)) return []
  return eps.map((ep) => {
    const o = (ep && typeof ep === 'object' ? ep : {}) as Record<string, unknown>
    return {
      episode_no: o.ep ?? o.episode_no ?? '—',
      focus_id: o.focus ?? o.focus_id ?? '—',
      premise: o.premise ?? '—',
      soft_promise: o.hook ?? o.soft_promise ?? '—',
    }
  })
})

function fmtMs(ms: unknown): string {
  if (typeof ms !== 'number' || !Number.isFinite(ms)) return '—'
  if (ms < 1000) return `${Math.round(ms)} ms`
  return `${(ms / 1000).toFixed(1)} s`
}

function fmtTok(n: unknown): string {
  if (typeof n !== 'number' || !Number.isFinite(n)) return '—'
  return String(Math.round(n))
}

const metricsSummary = computed(() => {
  const raw = story.value?.metrics_json
  if (!raw) return null
  try {
    const m = JSON.parse(raw) as Record<string, unknown>
    const stages = Array.isArray(m.stages) ? (m.stages as Record<string, unknown>[]) : []
    return {
      total_ms: m.total_ms,
      llm_ms: m.llm_ms ?? m.pipeline_ms,
      tts_ms: m.tts_ms,
      storage_ms: m.storage_ms,
      prompt_tokens: m.prompt_tokens,
      completion_tokens: m.completion_tokens,
      reasoning_tokens: m.reasoning_tokens,
      total_tokens: m.total_tokens,
      stages,
    }
  } catch {
    return null
  }
})

/** Draft-stage provider/model from metrics (source of truth for routed LLM). */
const draftLlm = computed(() => {
  const stages = metricsSummary.value?.stages || []
  for (let i = stages.length - 1; i >= 0; i--) {
    const row = stages[i]
    if (row?.stage !== 'draft') continue
    return {
      provider: typeof row.provider === 'string' ? row.provider : null,
      model: typeof row.model === 'string' ? row.model : null,
      tier: typeof row.tier === 'string' ? row.tier : null,
    }
  }
  return {
    provider: null as string | null,
    model: (story.value?.story_model as string | null | undefined) || null,
    tier: null as string | null,
  }
})

const planHighlights = computed(() => {
  const raw = story.value?.episode_plan_json
  if (!raw) return null
  try {
    const p = JSON.parse(raw) as Record<string, unknown>
    const pick = (k: string) => {
      const v = p[k]
      return typeof v === 'string' && v.trim() ? v.trim() : null
    }
    const beats = Array.isArray(p.beats) ? p.beats : []
    const cast = Array.isArray(p.casts)
      ? p.casts
      : Array.isArray(p.cast)
        ? p.cast
        : []
    const castNames = cast
      .map((c) => (c && typeof c === 'object' ? String((c as Record<string, unknown>).name || '') : ''))
      .filter(Boolean)
      .join('、')
    return {
      story_shape: pick('shape') || pick('story_shape'),
      theme: pick('theme'),
      target_feeling: pick('feel') || pick('target_feeling'),
      setting: pick('setting'),
      cast: castNames || null,
      beats_count: beats.length || null,
      title_hint: pick('title') || pick('title_hint'),
      soft_promise: pick('hook') || pick('soft_promise'),
      opening_pattern: pick('open') || pick('opening_pattern'),
      cast_intro_mode: pick('intro') || pick('cast_intro_mode'),
      story_element_name: pick('ename') || pick('eid') || pick('story_element_name') || pick('story_element_id'),
    }
  } catch {
    return null
  }
})

async function load() {
  loading.value = true
  recomputedTts.value = null
  try {
    const { data } = await api.get<AdminStoryDetailOut>(`/admin/stories/${route.params.id}`)
    story.value = data
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '加载失败')
  } finally {
    loading.value = false
  }
}

async function recomputeTtsInput() {
  if (!story.value) return
  recomputingTts.value = true
  try {
    const { data } = await api.get<AdminStoryTtsInputOut>(
      `/admin/stories/${story.value.id}/tts-input`,
    )
    recomputedTts.value = data
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '后算失败')
  } finally {
    recomputingTts.value = false
  }
}

function openInTtsLab() {
  if (!story.value) return
  const text = (story.value.body || '').trim()
  router.push({
    name: 'tts-lab',
    query: {
      ...(text ? { text } : {}),
      ...(story.value.voice_id != null ? { voice_id: String(story.value.voice_id) } : {}),
    },
  })
}

async function retryGenerate(forceFull: boolean) {
  if (!story.value || !canRetry.value) return
  const id = story.value.id
  const title = forceFull ? '强制从头重新生成' : '重新生成故事'
  const msg = forceFull
    ? `将清空故事 #${id} 的正文/大纲检查点，从构思阶段重新跑完整管线（不扣用户额度）。确定？`
    : `将重新入队故事 #${id}（失败或卡住时可点；有检查点时可能只续跑 TTS/正文，不扣用户额度）。确定？`
  try {
    await ElMessageBox.confirm(msg, title, { type: 'warning' })
  } catch {
    return
  }
  retrying.value = true
  try {
    const { data } = await api.post<AdminStoryDetailOut>(
      `/admin/stories/${id}/retry`,
      { force_full: forceFull },
    )
    story.value = data
    ElMessage.success(forceFull ? '已强制重新入队' : '已重新入队生成')
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '重新生成失败')
  } finally {
    retrying.value = false
  }
}

onMounted(load)
</script>

<template>
  <div v-loading="loading">
    <el-page-header @back="router.push('/stories')">
      <template #content>
        <span>故事 #{{ story?.id }}</span>
      </template>
    </el-page-header>
    <template v-if="story">
      <div class="actions">
        <el-button
          type="warning"
          :disabled="!canRetry"
          :loading="retrying"
          @click="retryGenerate(false)"
        >
          重新生成
        </el-button>
        <el-button
          :disabled="!canRetry"
          :loading="retrying"
          @click="retryGenerate(true)"
        >
          强制从头生成
        </el-button>
        <span v-if="!canRetry" class="muted tiny">仅 failed / generating 可重新入队</span>
        <span v-else-if="story.error_message" class="muted tiny err">{{ story.error_message }}</span>
      </div>
      <el-descriptions :column="2" border class="block">
        <el-descriptions-item label="标题">{{ story.title || '—' }}</el-descriptions-item>
        <el-descriptions-item label="状态">{{ story.status }} / {{ story.progress || '—' }}</el-descriptions-item>
        <el-descriptions-item label="正文 LLM">
          <template v-if="draftLlm.model || story.story_model">
            <el-tag v-if="draftLlm.provider" type="warning">{{ draftLlm.provider }}</el-tag>
            <span class="model-id">{{ draftLlm.model || story.story_model }}</span>
            <el-tag v-if="draftLlm.tier" size="small" class="tier-tag">{{ draftLlm.tier }}</el-tag>
          </template>
          <template v-else>—</template>
        </el-descriptions-item>
        <el-descriptions-item label="语音（音色）">
          {{ story.voice_name || '—' }}
          <span v-if="story.voice_id != null" class="muted tiny"> (#{{ story.voice_id }})</span>
          <div v-if="story.speech_provider || story.speech_model" class="muted tiny">
            <el-tag type="success" size="small">{{ story.speech_provider || '—' }}</el-tag>
            <span v-if="story.speech_model"> · {{ story.speech_model }}</span>
          </div>
        </el-descriptions-item>
        <el-descriptions-item label="用户">
          <el-button link type="primary" @click="router.push(`/users/${story.user_id}`)">
            #{{ story.user_id }} {{ story.user_display_name || '' }}
          </el-button>
        </el-descriptions-item>
        <el-descriptions-item label="语言 / 时长">
          {{ story.language }} · {{ story.duration_minutes }} 分
        </el-descriptions-item>
        <el-descriptions-item label="创建时间">{{ formatAdminTime(story.created_at) }}</el-descriptions-item>
        <el-descriptions-item label="生活 / 想象">
          <template v-if="createDialSummary?.wonder">
            <el-tag>{{ createDialSummary.wonderLabel }}</el-tag>
            <span class="muted tiny"> {{ createDialSummary.wonder }}</span>
          </template>
          <template v-else>—</template>
        </el-descriptions-item>
        <el-descriptions-item label="对话多少">
          <template v-if="createDialSummary?.dialogue">
            <el-tag type="info">{{ createDialSummary.dialogueLabel }}</el-tag>
            <span class="muted tiny"> {{ createDialSummary.dialogue }}</span>
          </template>
          <template v-else>—</template>
        </el-descriptions-item>
        <el-descriptions-item label="主题" :span="2">{{ story.theme || '—' }}</el-descriptions-item>
        <el-descriptions-item label="主题模式">
          <template v-if="createDialSummary?.themeMode">
            <el-tag type="warning">{{ createDialSummary.themeModeLabel }}</el-tag>
            <span class="muted tiny"> {{ createDialSummary.themeMode }}</span>
          </template>
          <template v-else>—</template>
        </el-descriptions-item>
        <el-descriptions-item label="主题来源">
          <template v-if="createDialSummary?.themeSource">
            <el-tag :type="createDialSummary.themeSource === 'user' ? 'success' : 'info'">
              {{ createDialSummary.themeSourceLabel }}
            </el-tag>
            <span class="muted tiny"> {{ createDialSummary.themeSource }}</span>
          </template>
          <template v-else>—</template>
        </el-descriptions-item>
        <el-descriptions-item v-if="story.series_id" label="软系列">
          <el-button link type="primary" @click="router.push(`/series/${story.series_id}`)">
            #{{ story.series_id }}
          </el-button>
          · 第 {{ story.episode_no ?? '?' }} 集
        </el-descriptions-item>
        <el-descriptions-item v-if="story.error_message" label="错误" :span="2">
          <span class="err">{{ story.error_message }}</span>
        </el-descriptions-item>
      </el-descriptions>

      <template v-if="story.series">
        <h3>系列构思</h3>
        <el-descriptions :column="1" border size="small" class="block">
          <el-descriptions-item label="系列标题">
            <el-button link type="primary" @click="router.push(`/series/${story.series.id}`)">
              {{ story.series.title || `系列 #${story.series.id}` }}
            </el-button>
            <el-tag size="small" class="series-tag">{{ story.series.status }}</el-tag>
            · {{ story.series.episode_count }} 集
          </el-descriptions-item>
          <el-descriptions-item label="throughline">
            {{ story.series.throughline || '—' }}
          </el-descriptions-item>
        </el-descriptions>
        <el-table
          v-if="seriesEpisodeRows.length"
          :data="seriesEpisodeRows"
          size="small"
          stripe
          border
          class="block"
        >
          <el-table-column prop="episode_no" label="#" width="60" />
          <el-table-column prop="focus_id" label="focus" width="120" />
          <el-table-column prop="premise" label="premise" min-width="180" show-overflow-tooltip />
          <el-table-column prop="soft_promise" label="hook" min-width="160" show-overflow-tooltip />
        </el-table>
        <el-collapse v-if="seriesOutlinePretty" class="block">
          <el-collapse-item title="完整系列 outline_json" name="series-outline">
            <pre class="json">{{ seriesOutlinePretty }}</pre>
          </el-collapse-item>
        </el-collapse>
      </template>

      <template v-if="metricsSummary">
        <h3>各阶段实际 LLM / TTS · 耗时 / Tokens</h3>
        <el-descriptions :column="2" border size="small" class="block">
          <el-descriptions-item label="总耗时">{{ fmtMs(metricsSummary.total_ms) }}</el-descriptions-item>
          <el-descriptions-item label="LLM">{{ fmtMs(metricsSummary.llm_ms) }}</el-descriptions-item>
          <el-descriptions-item label="TTS">{{ fmtMs(metricsSummary.tts_ms) }}</el-descriptions-item>
          <el-descriptions-item label="存储">{{ fmtMs(metricsSummary.storage_ms) }}</el-descriptions-item>
          <el-descriptions-item label="Prompt tokens">{{ fmtTok(metricsSummary.prompt_tokens) }}</el-descriptions-item>
          <el-descriptions-item label="Completion tokens">
            {{ fmtTok(metricsSummary.completion_tokens) }}
          </el-descriptions-item>
          <el-descriptions-item label="Reasoning tokens">
            {{ fmtTok(metricsSummary.reasoning_tokens) }}
          </el-descriptions-item>
          <el-descriptions-item label="Total tokens">{{ fmtTok(metricsSummary.total_tokens) }}</el-descriptions-item>
        </el-descriptions>
        <el-table
          v-if="metricsSummary.stages.length"
          :data="metricsSummary.stages"
          size="small"
          stripe
          class="stage-table"
        >
          <el-table-column prop="stage" label="阶段" min-width="110" />
          <el-table-column label="Provider" min-width="100">
            <template #default="{ row }">{{ row.provider || '—' }}</template>
          </el-table-column>
          <el-table-column label="Model" min-width="140" show-overflow-tooltip>
            <template #default="{ row }">{{ row.model || '—' }}</template>
          </el-table-column>
          <el-table-column label="Tier" width="70">
            <template #default="{ row }">{{ row.tier || '—' }}</template>
          </el-table-column>
          <el-table-column label="路由原因" min-width="160" show-overflow-tooltip>
            <template #default="{ row }">{{ row.policy_reason || '—' }}</template>
          </el-table-column>
          <el-table-column label="耗时" width="90">
            <template #default="{ row }">{{ fmtMs(row.ms) }}</template>
          </el-table-column>
          <el-table-column label="prompt" width="80">
            <template #default="{ row }">{{ fmtTok(row.prompt_tokens) }}</template>
          </el-table-column>
          <el-table-column label="completion" width="90">
            <template #default="{ row }">{{ fmtTok(row.completion_tokens) }}</template>
          </el-table-column>
          <el-table-column label="reasoning" width="90">
            <template #default="{ row }">{{ fmtTok(row.reasoning_tokens) }}</template>
          </el-table-column>
          <el-table-column label="total" width="80">
            <template #default="{ row }">{{ fmtTok(row.total_tokens) }}</template>
          </el-table-column>
        </el-table>
        <el-collapse v-if="metricsPretty" class="metrics-raw">
          <el-collapse-item title="完整 metrics JSON" name="metrics">
            <pre class="json">{{ metricsPretty }}</pre>
          </el-collapse-item>
        </el-collapse>
      </template>
      <p v-else class="muted metrics-missing">本故事无 metrics（旧数据或生成于采集前）。</p>

      <h3>提交给模型的 Prompt</h3>
      <el-collapse v-if="submittedPrompts.length" class="block">
        <el-collapse-item
          v-for="(prompt, index) in submittedPrompts"
          :key="`${prompt.stage}-${index}`"
          :title="prompt.label"
          :name="String(index)"
        >
          <p class="prompt-label">system</p>
          <pre class="json prompt-body">{{ prompt.system }}</pre>
          <p class="prompt-label">user</p>
          <pre class="json prompt-body">{{ prompt.user }}</pre>
        </el-collapse-item>
      </el-collapse>
      <p v-else class="muted metrics-missing">本故事没有保存提交原文（旧数据，或生成于该功能上线前）。</p>

      <div v-if="story.audio_url" class="audio">
        <h3>音频</h3>
        <audio :src="story.audio_url" controls style="width: 100%" />
      </div>

      <h3>正文</h3>
      <el-input :model-value="story.body" type="textarea" :rows="16" readonly />

      <div class="tts-input-head">
        <h3>发给 TTS 的文案</h3>
        <el-button
          size="small"
          :loading="recomputingTts"
          :disabled="!(story.body || '').trim()"
          @click="recomputeTtsInput"
        >
          后算查看
        </el-button>
        <el-button size="small" :disabled="!(story.body || '').trim()" @click="openInTtsLab">
          打开 TTS 试验台
        </el-button>
      </div>
      <p class="muted tiny tts-input-hint">
        按当前停顿规则重算（可能与磁盘上旧音频不完全一致）。要换音色 / 算法试听请用试验台。
      </p>
      <template v-if="recomputedTts">
        <el-descriptions :column="2" border size="small" class="block">
          <el-descriptions-item v-if="recomputedTts.provider" label="provider">
            {{ recomputedTts.provider }}
          </el-descriptions-item>
          <el-descriptions-item v-if="recomputedTts.model" label="model">
            {{ recomputedTts.model }}
          </el-descriptions-item>
          <el-descriptions-item v-if="recomputedTts.prosody_mode" label="prosody">
            {{ recomputedTts.prosody_mode }}
          </el-descriptions-item>
          <el-descriptions-item label="used_ssml">
            {{ recomputedTts.used_ssml ? 'yes' : 'no' }}
          </el-descriptions-item>
        </el-descriptions>
        <p class="prompt-label">speak_text</p>
        <el-input :model-value="recomputedTts.speak_text" type="textarea" :rows="12" readonly />
        <template v-if="recomputedTts.ssml">
          <p class="prompt-label">ssml</p>
          <pre class="json prompt-body">{{ recomputedTts.ssml }}</pre>
        </template>
      </template>
      <p v-else class="muted metrics-missing">尚未后算。点「后算查看」查看当前注入后的 TTS 文案。</p>

      <h3>Episode Plan</h3>
      <template v-if="episodePlanPretty">
        <el-descriptions v-if="planHighlights" :column="2" border size="small" class="plan-hi">
          <el-descriptions-item v-if="planHighlights.title_hint" label="title_hint">
            {{ planHighlights.title_hint }}
          </el-descriptions-item>
          <el-descriptions-item v-if="planHighlights.story_shape" label="story_shape">
            {{ planHighlights.story_shape }}
          </el-descriptions-item>
          <el-descriptions-item v-if="planHighlights.theme" label="theme">
            {{ planHighlights.theme }}
          </el-descriptions-item>
          <el-descriptions-item v-if="planHighlights.target_feeling" label="target_feeling">
            {{ planHighlights.target_feeling }}
          </el-descriptions-item>
          <el-descriptions-item v-if="planHighlights.setting" label="setting" :span="2">
            {{ planHighlights.setting }}
          </el-descriptions-item>
          <el-descriptions-item v-if="planHighlights.cast" label="cast">
            {{ planHighlights.cast }}
          </el-descriptions-item>
          <el-descriptions-item v-if="planHighlights.beats_count" label="beats">
            {{ planHighlights.beats_count }} 拍
          </el-descriptions-item>
          <el-descriptions-item v-if="planHighlights.soft_promise" label="soft_promise" :span="2">
            {{ planHighlights.soft_promise }}
          </el-descriptions-item>
          <el-descriptions-item v-if="planHighlights.opening_pattern" label="opening">
            {{ planHighlights.opening_pattern }}
          </el-descriptions-item>
          <el-descriptions-item v-if="planHighlights.cast_intro_mode" label="cast_intro">
            {{ planHighlights.cast_intro_mode }}
          </el-descriptions-item>
          <el-descriptions-item v-if="planHighlights.story_element_name" label="element">
            {{ planHighlights.story_element_name }}
          </el-descriptions-item>
        </el-descriptions>
        <el-collapse>
          <el-collapse-item title="完整 episode_plan JSON" name="plan">
            <pre class="json">{{ episodePlanPretty }}</pre>
          </el-collapse-item>
        </el-collapse>
      </template>
      <p v-else class="muted">本故事无 plan 快照（旧数据，或失败发生在构思完成前）。</p>

      <h3>创建参数</h3>
      <el-collapse v-if="paramsPretty">
        <el-collapse-item title="params_json" name="params">
          <pre class="json">{{ paramsPretty }}</pre>
        </el-collapse-item>
      </el-collapse>
      <p v-else class="muted">无 params</p>
    </template>
  </div>
</template>

<style scoped>
.actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  margin: 12px 0 0;
}
.block {
  margin: 16px 0 24px;
}
.err {
  color: #c45656;
}
.audio {
  margin-bottom: 16px;
}
h3 {
  margin: 16px 0 8px;
}
.plan-hi {
  margin-bottom: 12px;
}
.json {
  margin: 0;
  padding: 12px;
  background: #f5f7fa;
  border-radius: 6px;
  font-size: 12px;
  line-height: 1.45;
  overflow: auto;
  max-height: 420px;
  white-space: pre-wrap;
  word-break: break-word;
}
.muted {
  color: var(--el-text-color-secondary);
  font-size: 13px;
}
.tiny {
  margin-left: 8px;
  font-size: 12px;
}
.model-id {
  margin-left: 8px;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 13px;
}
.tier-tag {
  margin-left: 8px;
}
.stage-table {
  margin: 8px 0 12px;
  width: 100%;
}
.metrics-raw {
  margin-bottom: 16px;
}
.metrics-missing {
  margin: 12px 0 16px;
}
.prompt-label {
  margin: 8px 0 4px;
  font-size: 12px;
  color: var(--el-text-color-secondary);
}
.prompt-body {
  max-height: 640px;
}
.series-tag {
  margin-left: 8px;
}
.tts-input-head {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-top: 16px;
}
.tts-input-head h3 {
  margin: 0;
}
.tts-input-hint {
  margin: 4px 0 12px;
}
</style>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { api } from '@/api/client'

export interface AdminVoiceRow {
  id: number
  user_id: number | null
  user_display_name: string | null
  name: string
  description: string | null
  kind: string
  language: string
  provider: string
  provider_voice_id: string
  speech_model: string | null
  speed_tier: string
  enabled: boolean
  sort_order: number
  preview_text: string | null
  preview_audio_url: string | null
  preview_generated_at: string | null
  created_at: string | null
}

const SPEED_OPTIONS = [
  { value: 'slow', label: '慢速 (0.85)' },
  { value: 'medium', label: '正常 (1.0)' },
  { value: 'fast', label: '偏快 (1.1)' },
] as const

const DEFAULT_PREVIEW_ZH =
  '夜深了，星星轻轻眨眼。我们听一个很软的故事，慢慢地，安心地，准备入睡。'

const route = useRoute()
const router = useRouter()

const loading = ref(false)
const saving = ref(false)
const items = ref<AdminVoiceRow[]>([])
const total = ref(0)
const page = ref(1)
const pageSize = ref(20)
const q = ref('')
const provider = ref('')
const kind = ref('')
const enabledFilter = ref<boolean | undefined>(undefined)
const userId = ref<number | undefined>(undefined)
const speechProviders = ref<string[]>([])
const envModels = ref<Record<string, string>>({})

const dialogOpen = ref(false)
const isCreate = ref(false)
const previewingId = ref<number | null>(null)
const generatingId = ref<number | null>(null)
const togglingId = ref<number | null>(null)
const previewingForm = ref(false)
const generatingForm = ref(false)
const form = ref({
  id: 0,
  user_id: undefined as number | undefined,
  name: '',
  description: '',
  kind: 'system',
  language: 'zh',
  provider: 'fishaudio',
  provider_voice_id: '',
  speech_model: '',
  speed_tier: 'medium',
  enabled: true,
  sort_order: 0,
  preview_text: DEFAULT_PREVIEW_ZH,
  preview_audio_url: null as string | null,
  preview_generated_at: null as string | null,
})

const envHint = computed(() => {
  const p = form.value.provider
  return envModels.value[p] || '—'
})

let previewAudio: HTMLAudioElement | null = null
let previewObjectUrl: string | null = null
/** Bumps so an older async preview cannot resume after interrupt. */
let previewGen = 0

function stopPreview() {
  previewGen += 1
  if (previewAudio) {
    previewAudio.pause()
    previewAudio.src = ''
    previewAudio = null
  }
  if (previewObjectUrl) {
    URL.revokeObjectURL(previewObjectUrl)
    previewObjectUrl = null
  }
  previewingId.value = null
  previewingForm.value = false
}

async function playUrl(url: string) {
  const gen = ++previewGen
  if (previewAudio) {
    previewAudio.pause()
    previewAudio.src = ''
    previewAudio = null
  }
  if (previewObjectUrl) {
    URL.revokeObjectURL(previewObjectUrl)
    previewObjectUrl = null
  }
  previewAudio = new Audio(url)
  previewAudio.onended = () => {
    if (gen === previewGen) stopPreview()
  }
  await previewAudio.play()
  if (gen !== previewGen) {
    previewAudio?.pause()
    return
  }
}

async function playPreviewBlob(blob: Blob) {
  const gen = ++previewGen
  if (previewAudio) {
    previewAudio.pause()
    previewAudio.src = ''
    previewAudio = null
  }
  if (previewObjectUrl) {
    URL.revokeObjectURL(previewObjectUrl)
    previewObjectUrl = null
  }
  previewObjectUrl = URL.createObjectURL(blob)
  previewAudio = new Audio(previewObjectUrl)
  previewAudio.onended = () => {
    if (gen === previewGen) stopPreview()
  }
  await previewAudio.play()
  if (gen !== previewGen) {
    previewAudio?.pause()
    return
  }
}

async function fetchLivePreview(path: string, body: Record<string, unknown>) {
  const res = await api.post(path, body, {
    responseType: 'blob',
    timeout: 120_000,
  })
  const ctype = String(res.headers['content-type'] || '')
  if (!ctype.includes('audio')) {
    const text = await (res.data as Blob).text()
    let detail = '试听失败'
    try {
      const parsed = JSON.parse(text) as { detail?: string }
      if (typeof parsed.detail === 'string' && parsed.detail) detail = parsed.detail
    } catch {
      if (text.trim()) detail = text.slice(0, 200)
    }
    throw new Error(detail)
  }
  await playPreviewBlob(res.data as Blob)
}

async function playStoredPreview(row: AdminVoiceRow) {
  // Interrupt current playback immediately when switching rows.
  if (previewAudio) {
    previewAudio.pause()
    previewAudio.src = ''
    previewAudio = null
  }
  previewingId.value = row.id
  try {
    if (row.preview_audio_url) {
      await playUrl(row.preview_audio_url)
      return
    }
    const res = await api.get(`/admin/voices/${row.id}/preview`, {
      responseType: 'blob',
      timeout: 60_000,
    })
    if (previewingId.value !== row.id) return
    await playPreviewBlob(res.data as Blob)
  } catch (e) {
    if (previewingId.value !== row.id) return
    ElMessage.error(e instanceof Error ? e.message : '暂无试听音频，请先生成')
  } finally {
    if (previewingId.value === row.id) previewingId.value = null
  }
}

async function generateStoredPreview(voiceId: number, text: string) {
  const { data } = await api.post<AdminVoiceRow>(
    `/admin/voices/${voiceId}/preview/generate`,
    { text: text.trim() || null },
    { timeout: 120_000 },
  )
  return data
}

async function previewRow(row: AdminVoiceRow) {
  if (!row.preview_audio_url) {
    ElMessage.warning('请先生成试听音频')
    openEdit(row)
    return
  }
  await playStoredPreview(row)
}

async function generateRow(row: AdminVoiceRow) {
  generatingId.value = row.id
  try {
    const text = row.preview_text || DEFAULT_PREVIEW_ZH
    const data = await generateStoredPreview(row.id, text)
    const idx = items.value.findIndex((x) => x.id === row.id)
    if (idx >= 0) items.value[idx] = { ...items.value[idx], ...data }
    ElMessage.success('试听已生成')
    if (data.preview_audio_url) await playUrl(data.preview_audio_url)
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '生成失败')
  } finally {
    generatingId.value = null
  }
}

async function toggleEnabled(row: AdminVoiceRow, enabled: boolean) {
  togglingId.value = row.id
  try {
    const { data } = await api.patch<AdminVoiceRow>(`/admin/voices/${row.id}`, { enabled })
    const idx = items.value.findIndex((x) => x.id === row.id)
    if (idx >= 0) items.value[idx] = { ...items.value[idx], ...data }
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '更新失败')
  } finally {
    togglingId.value = null
  }
}

async function saveSortOrder(row: AdminVoiceRow, value: number | undefined) {
  const next = Number.isFinite(value) ? Math.trunc(value as number) : 0
  if (next === (row.sort_order ?? 0)) return
  try {
    const { data } = await api.patch<AdminVoiceRow>(`/admin/voices/${row.id}`, {
      sort_order: next,
    })
    const idx = items.value.findIndex((x) => x.id === row.id)
    if (idx >= 0) items.value[idx] = { ...items.value[idx], ...data }
    ElMessage.success('排序已更新')
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '排序更新失败')
    await load()
  }
}

async function previewFormLive() {
  if (!form.value.provider || !form.value.provider_voice_id.trim()) {
    ElMessage.error('请先填写 Provider 与 Provider Voice ID')
    return
  }
  previewingForm.value = true
  try {
    await fetchLivePreview('/admin/voices/preview', {
      provider: form.value.provider,
      provider_voice_id: form.value.provider_voice_id.trim(),
      speech_model: form.value.speech_model.trim() || null,
      language: form.value.language || 'zh',
      speed_tier: form.value.speed_tier || 'medium',
      text: form.value.preview_text.trim() || null,
    })
    ElMessage.success('正在播放（未落库）')
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '试听失败')
  } finally {
    previewingForm.value = false
  }
}

async function generateFormPreview() {
  if (isCreate.value || !form.value.id) {
    ElMessage.error('请先保存音色，再生成落库试听')
    return
  }
  generatingForm.value = true
  try {
    const data = await generateStoredPreview(form.value.id, form.value.preview_text)
    form.value.preview_text = data.preview_text || form.value.preview_text
    form.value.preview_audio_url = data.preview_audio_url
    form.value.preview_generated_at = data.preview_generated_at
    ElMessage.success('试听已生成并落库')
    if (data.preview_audio_url) await playUrl(data.preview_audio_url)
    await load()
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '生成失败')
  } finally {
    generatingForm.value = false
  }
}

async function playFormStored() {
  if (!form.value.id) return
  previewingForm.value = true
  try {
    await playStoredPreview({
      id: form.value.id,
      preview_audio_url: form.value.preview_audio_url,
      preview_text: form.value.preview_text,
    } as AdminVoiceRow)
  } finally {
    previewingForm.value = false
  }
}

onBeforeUnmount(() => stopPreview())

async function load() {
  loading.value = true
  try {
    const { data } = await api.get<{
      items: AdminVoiceRow[]
      total: number
      speech_providers: string[]
      env_models: Record<string, string>
    }>('/admin/voices', {
      params: {
        page: page.value,
        page_size: pageSize.value,
        q: q.value || undefined,
        provider: provider.value || undefined,
        kind: kind.value || undefined,
        enabled: enabledFilter.value,
        user_id: userId.value,
      },
    })
    items.value = data.items
    total.value = data.total
    speechProviders.value = data.speech_providers
    envModels.value = data.env_models
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '加载失败')
  } finally {
    loading.value = false
  }
}

function syncFromQuery() {
  const uid = route.query.user_id
  if (typeof uid === 'string' && uid.trim()) {
    const n = Number(uid)
    userId.value = Number.isFinite(n) ? n : undefined
  } else {
    userId.value = undefined
  }
}

function openCreate() {
  isCreate.value = true
  form.value = {
    id: 0,
    user_id: undefined,
    name: '枕边柔声',
    description: '',
    kind: 'system',
    language: 'zh',
    provider: speechProviders.value[0] || 'fishaudio',
    provider_voice_id: '',
    speech_model: '',
    speed_tier: 'medium',
    enabled: true,
    sort_order: 0,
    preview_text: DEFAULT_PREVIEW_ZH,
    preview_audio_url: null,
    preview_generated_at: null,
  }
  dialogOpen.value = true
}

function openEdit(row: AdminVoiceRow) {
  isCreate.value = false
  form.value = {
    id: row.id,
    user_id: row.user_id ?? undefined,
    name: row.name,
    description: row.description || '',
    kind: row.kind,
    language: row.language,
    provider: row.provider,
    provider_voice_id: row.provider_voice_id,
    speech_model: row.speech_model || '',
    speed_tier: row.speed_tier || 'medium',
    enabled: row.enabled !== false,
    sort_order: row.sort_order ?? 0,
    preview_text: row.preview_text || DEFAULT_PREVIEW_ZH,
    preview_audio_url: row.preview_audio_url,
    preview_generated_at: row.preview_generated_at,
  }
  dialogOpen.value = true
}

async function save() {
  saving.value = true
  try {
    if (isCreate.value) {
      if (form.value.kind === 'clone' && !form.value.user_id) {
        ElMessage.error('克隆音色需要填写 User ID')
        return
      }
      await api.post('/admin/voices', {
        user_id: form.value.kind === 'clone' ? form.value.user_id : null,
        name: form.value.name.trim(),
        description: form.value.description.trim() || null,
        kind: form.value.kind,
        language: form.value.language,
        provider: form.value.provider,
        provider_voice_id: form.value.provider_voice_id.trim(),
        speech_model: form.value.speech_model.trim() || null,
        speed_tier: form.value.speed_tier || 'medium',
        enabled: form.value.enabled,
        sort_order: form.value.sort_order ?? 0,
      })
      ElMessage.success('已创建')
    } else {
      await api.patch(`/admin/voices/${form.value.id}`, {
        name: form.value.name.trim(),
        description: form.value.description.trim(),
        kind: form.value.kind,
        language: form.value.language,
        provider: form.value.provider,
        provider_voice_id: form.value.provider_voice_id.trim(),
        speech_model: form.value.speech_model.trim(),
        speed_tier: form.value.speed_tier || 'medium',
        enabled: form.value.enabled,
        sort_order: form.value.sort_order ?? 0,
      })
      ElMessage.success('已保存')
    }
    dialogOpen.value = false
    await load()
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '保存失败')
  } finally {
    saving.value = false
  }
}

async function remove(row: AdminVoiceRow) {
  try {
    await ElMessageBox.confirm(`删除音色「${row.name}」(#${row.id})？`, '确认删除', {
      type: 'warning',
    })
  } catch {
    return
  }
  try {
    await api.delete(`/admin/voices/${row.id}`)
    ElMessage.success('已删除')
    await load()
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '删除失败')
  }
}

function goUser(uid: number) {
  router.push(`/users/${uid}`)
}

watch(
  () => route.query.user_id,
  () => {
    syncFromQuery()
    page.value = 1
    load()
  },
)

onMounted(() => {
  syncFromQuery()
  load()
})
</script>

<template>
  <div>
    <h2>音色管理</h2>
    <p class="hint">
      <code>system</code> 音色为全局共享目录。关闭「启用」后 App 不可见。
      「排序」数字越小越靠前（App 列表与选择弹窗）；用户克隆默认 1000。
      试听音频落库后可直接播放；可改示例文本后重新生成覆盖。
    </p>
    <el-form inline class="toolbar" @submit.prevent>
      <el-form-item label="搜索">
        <el-input v-model="q" clearable placeholder="名称 / voice id / model" style="width: 200px" />
      </el-form-item>
      <el-form-item label="User">
        <el-input-number
          v-model="userId"
          :min="1"
          controls-position="right"
          placeholder="克隆所属"
        />
      </el-form-item>
      <el-form-item label="Provider">
        <el-select v-model="provider" clearable placeholder="全部" style="width: 140px">
          <el-option v-for="p in speechProviders" :key="p" :label="p" :value="p" />
        </el-select>
      </el-form-item>
      <el-form-item label="类型">
        <el-select v-model="kind" clearable placeholder="全部" style="width: 120px">
          <el-option label="system" value="system" />
          <el-option label="clone" value="clone" />
        </el-select>
      </el-form-item>
      <el-form-item label="启用">
        <el-select v-model="enabledFilter" clearable placeholder="全部" style="width: 110px">
          <el-option label="已启用" :value="true" />
          <el-option label="已停用" :value="false" />
        </el-select>
      </el-form-item>
      <el-button type="primary" @click="() => { page = 1; load() }">查询</el-button>
      <el-button @click="openCreate">新建</el-button>
    </el-form>

    <el-table v-loading="loading" :data="items" stripe>
      <el-table-column prop="id" label="ID" width="70" />
      <el-table-column label="排序" width="100">
        <template #default="{ row }">
          <el-input-number
            :model-value="row.sort_order ?? 0"
            :step="1"
            :controls="false"
            size="small"
            style="width: 72px"
            @change="(v: number | undefined) => saveSortOrder(row, v)"
          />
        </template>
      </el-table-column>
      <el-table-column label="启用" width="80">
        <template #default="{ row }">
          <el-switch
            :model-value="row.enabled !== false"
            :loading="togglingId === row.id"
            @change="(v: boolean) => toggleEnabled(row, v)"
          />
        </template>
      </el-table-column>
      <el-table-column label="归属" width="120">
        <template #default="{ row }">
          <span v-if="row.user_id == null" class="global-tag">全局</span>
          <el-button v-else link type="primary" @click="goUser(row.user_id)">
            #{{ row.user_id }}
          </el-button>
        </template>
      </el-table-column>
      <el-table-column prop="name" label="名称" min-width="110" show-overflow-tooltip />
      <el-table-column prop="description" label="介绍" min-width="140" show-overflow-tooltip>
        <template #default="{ row }">
          {{ row.description || '—' }}
        </template>
      </el-table-column>
      <el-table-column prop="provider" label="Provider" width="100" />
      <el-table-column prop="speech_model" label="Model" min-width="120" show-overflow-tooltip>
        <template #default="{ row }">
          {{ row.speech_model || '（默认）' }}
        </template>
      </el-table-column>
      <el-table-column prop="speed_tier" label="语速" width="80" />
      <el-table-column label="试听" width="90">
        <template #default="{ row }">
          <span v-if="row.preview_audio_url" class="global-tag">已生成</span>
          <span v-else class="muted">未生成</span>
        </template>
      </el-table-column>
      <el-table-column label="操作" width="260" fixed="right">
        <template #default="{ row }">
          <el-button
            link
            type="success"
            :loading="previewingId === row.id"
            :disabled="!row.preview_audio_url"
            @click="previewRow(row)"
          >
            播放
          </el-button>
          <el-button
            link
            type="warning"
            :loading="generatingId === row.id"
            @click="generateRow(row)"
          >
            生成
          </el-button>
          <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
          <el-button link type="danger" @click="remove(row)">删除</el-button>
        </template>
      </el-table-column>
    </el-table>

    <div class="pager">
      <el-pagination
        v-model:current-page="page"
        v-model:page-size="pageSize"
        :total="total"
        layout="total, prev, pager, next"
        @current-change="load"
        @size-change="() => { page = 1; load() }"
      />
    </div>

    <el-dialog v-model="dialogOpen" :title="isCreate ? '新建音色' : '编辑音色'" width="560px">
      <el-form label-width="130px">
        <el-form-item label="名称" required>
          <el-input v-model="form.name" />
        </el-form-item>
        <el-form-item label="介绍">
          <el-input
            v-model="form.description"
            type="textarea"
            :rows="2"
            maxlength="200"
            show-word-limit
            placeholder="声音特点，展示在 App 音色列表中"
          />
        </el-form-item>
        <el-form-item label="启用">
          <el-switch v-model="form.enabled" />
        </el-form-item>
        <el-form-item label="排序">
          <el-input-number v-model="form.sort_order" :step="1" controls-position="right" />
          <div class="field-hint">数字越小 App 列表越靠前</div>
        </el-form-item>
        <el-form-item label="类型">
          <el-select v-model="form.kind" style="width: 100%" :disabled="!isCreate">
            <el-option label="system（全局）" value="system" />
            <el-option label="clone（用户）" value="clone" />
          </el-select>
        </el-form-item>
        <el-form-item v-if="isCreate && form.kind === 'clone'" label="User ID" required>
          <el-input-number v-model="form.user_id" :min="1" controls-position="right" />
        </el-form-item>
        <el-form-item label="语言">
          <el-input v-model="form.language" />
        </el-form-item>
        <el-form-item label="Provider" required>
          <el-select v-model="form.provider" style="width: 100%">
            <el-option v-for="p in speechProviders" :key="p" :label="p" :value="p" />
          </el-select>
        </el-form-item>
        <el-form-item label="Provider Voice ID" required>
          <el-input v-model="form.provider_voice_id" placeholder="厂商音色 id" />
        </el-form-item>
        <el-form-item label="Speech Model">
          <el-input
            v-model="form.speech_model"
            clearable
            :placeholder="`空=用默认（${envHint}）`"
          />
        </el-form-item>
        <el-form-item label="默认语速">
          <el-select v-model="form.speed_tier" style="width: 100%">
            <el-option
              v-for="opt in SPEED_OPTIONS"
              :key="opt.value"
              :label="opt.label"
              :value="opt.value"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="试听文本">
          <el-input
            v-model="form.preview_text"
            type="textarea"
            :rows="3"
            maxlength="500"
            show-word-limit
            placeholder="用于生成落库试听的示例文案"
          />
        </el-form-item>
        <el-form-item label="试听音频">
          <div class="preview-actions">
            <el-button
              v-if="!isCreate"
              type="primary"
              :loading="generatingForm"
              @click="generateFormPreview"
            >
              {{ form.preview_audio_url ? '重新生成并落库' : '生成并落库' }}
            </el-button>
            <el-button
              v-if="!isCreate && form.preview_audio_url"
              :loading="previewingForm"
              @click="playFormStored"
            >
              播放已落库
            </el-button>
            <el-button :loading="previewingForm" @click="previewFormLive">
              临时试听（不落库）
            </el-button>
          </div>
          <div v-if="form.preview_generated_at" class="field-hint">
            上次生成：{{ form.preview_generated_at }}
          </div>
          <div v-else-if="isCreate" class="field-hint">保存音色后可生成落库试听。</div>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogOpen = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="save">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.hint {
  color: var(--el-text-color-secondary);
  font-size: 13px;
  margin: 0 0 12px;
  max-width: 720px;
  line-height: 1.5;
}
.toolbar {
  margin-bottom: 8px;
}
.pager {
  margin-top: 16px;
  display: flex;
  justify-content: flex-end;
}
.field-hint {
  color: var(--el-text-color-secondary);
  font-size: 12px;
  margin-top: 4px;
}
.global-tag {
  color: var(--el-color-success);
  font-size: 13px;
}
.muted {
  color: var(--el-text-color-secondary);
  font-size: 13px;
}
.preview-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
</style>

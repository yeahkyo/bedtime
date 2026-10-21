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
  kind: string
  language: string
  provider: string
  provider_voice_id: string
  speech_model: string | null
  speed_tier: string
  created_at: string | null
}

const SPEED_OPTIONS = [
  { value: 'slow', label: '慢速 (0.85)' },
  { value: 'medium', label: '正常 (1.0)' },
  { value: 'fast', label: '偏快 (1.1)' },
] as const

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
const userId = ref<number | undefined>(undefined)
const speechProviders = ref<string[]>([])
const envModels = ref<Record<string, string>>({})

const dialogOpen = ref(false)
const isCreate = ref(false)
const previewingId = ref<number | null>(null)
const previewingForm = ref(false)
const form = ref({
  id: 0,
  user_id: undefined as number | undefined,
  name: '',
  kind: 'system',
  language: 'zh',
  provider: 'fishaudio',
  provider_voice_id: '',
  speech_model: '',
  speed_tier: 'medium',
})

const envHint = computed(() => {
  const p = form.value.provider
  return envModels.value[p] || '—'
})

let previewAudio: HTMLAudioElement | null = null
let previewObjectUrl: string | null = null

function stopPreview() {
  if (previewAudio) {
    previewAudio.pause()
    previewAudio.src = ''
    previewAudio = null
  }
  if (previewObjectUrl) {
    URL.revokeObjectURL(previewObjectUrl)
    previewObjectUrl = null
  }
}

async function playPreviewBlob(blob: Blob) {
  stopPreview()
  previewObjectUrl = URL.createObjectURL(blob)
  previewAudio = new Audio(previewObjectUrl)
  previewAudio.onended = () => stopPreview()
  try {
    await previewAudio.play()
  } catch (e) {
    stopPreview()
    throw e
  }
}

async function fetchPreview(path: string, body: Record<string, unknown>) {
  try {
    const res = await api.post(path, body, {
      responseType: 'blob',
      timeout: 120_000,
    })
    const ctype = String(res.headers['content-type'] || '')
    if (!ctype.includes('audio')) {
      // Error payloads may arrive as JSON blob when responseType=blob.
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
    ElMessage.success('正在播放试听')
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '试听失败')
  }
}

async function previewRow(row: AdminVoiceRow) {
  previewingId.value = row.id
  try {
    await fetchPreview(`/admin/voices/${row.id}/preview`, {})
  } finally {
    previewingId.value = null
  }
}

async function previewForm() {
  if (!form.value.provider || !form.value.provider_voice_id.trim()) {
    ElMessage.error('请先填写 Provider 与 Provider Voice ID')
    return
  }
  previewingForm.value = true
  try {
    const body = {
      provider: form.value.provider,
      provider_voice_id: form.value.provider_voice_id.trim(),
      speech_model: form.value.speech_model.trim() || null,
      language: form.value.language || 'zh',
      speed_tier: form.value.speed_tier || 'medium',
    }
    if (!isCreate.value && form.value.id) {
      await fetchPreview(`/admin/voices/${form.value.id}/preview`, body)
    } else {
      await fetchPreview('/admin/voices/preview', body)
    }
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
    kind: 'system',
    language: 'zh',
    provider: speechProviders.value[0] || 'fishaudio',
    provider_voice_id: '',
    speech_model: '',
    speed_tier: 'medium',
  }
  dialogOpen.value = true
}

function openEdit(row: AdminVoiceRow) {
  isCreate.value = false
  form.value = {
    id: row.id,
    user_id: row.user_id ?? undefined,
    name: row.name,
    kind: row.kind,
    language: row.language,
    provider: row.provider,
    provider_voice_id: row.provider_voice_id,
    speech_model: row.speech_model || '',
    speed_tier: row.speed_tier || 'medium',
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
        kind: form.value.kind,
        language: form.value.language,
        provider: form.value.provider,
        provider_voice_id: form.value.provider_voice_id.trim(),
        speech_model: form.value.speech_model.trim() || null,
        speed_tier: form.value.speed_tier || 'medium',
      })
      ElMessage.success('已创建')
    } else {
      await api.patch(`/admin/voices/${form.value.id}`, {
        name: form.value.name.trim(),
        kind: form.value.kind,
        language: form.value.language,
        provider: form.value.provider,
        provider_voice_id: form.value.provider_voice_id.trim(),
        speech_model: form.value.speech_model.trim(),
        speed_tier: form.value.speed_tier || 'medium',
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
      <code>system</code> 音色为全局共享目录（所有用户可见）。
      Provider / Model / 默认语速绑定在音色上；生成故事时优先使用该语速。
      <code>clone</code> 仍归属单个用户。
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
      <el-button type="primary" @click="() => { page = 1; load() }">查询</el-button>
      <el-button @click="openCreate">新建</el-button>
    </el-form>

    <el-table v-loading="loading" :data="items" stripe>
      <el-table-column prop="id" label="ID" width="70" />
      <el-table-column label="归属" width="140">
        <template #default="{ row }">
          <span v-if="row.user_id == null" class="global-tag">全局</span>
          <el-button v-else link type="primary" @click="goUser(row.user_id)">
            #{{ row.user_id }} {{ row.user_display_name || '' }}
          </el-button>
        </template>
      </el-table-column>
      <el-table-column prop="name" label="名称" min-width="120" show-overflow-tooltip />
      <el-table-column prop="kind" label="类型" width="90" />
      <el-table-column prop="provider" label="Provider" width="110" />
      <el-table-column prop="speech_model" label="Model" min-width="140" show-overflow-tooltip>
        <template #default="{ row }">
          {{ row.speech_model || '（默认）' }}
        </template>
      </el-table-column>
      <el-table-column prop="speed_tier" label="语速" width="90">
        <template #default="{ row }">
          {{ row.speed_tier || 'medium' }}
        </template>
      </el-table-column>
      <el-table-column prop="provider_voice_id" label="Provider Voice ID" min-width="160" show-overflow-tooltip />
      <el-table-column label="操作" width="200" fixed="right">
        <template #default="{ row }">
          <el-button
            link
            type="success"
            :loading="previewingId === row.id"
            @click="previewRow(row)"
          >
            试听
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

    <el-dialog v-model="dialogOpen" :title="isCreate ? '新建音色' : '编辑音色'" width="520px">
      <el-form label-width="130px">
        <el-form-item label="名称" required>
          <el-input v-model="form.name" />
        </el-form-item>
        <el-form-item label="类型">
          <el-select v-model="form.kind" style="width: 100%" :disabled="!isCreate">
            <el-option label="system（全局）" value="system" />
            <el-option label="clone（用户）" value="clone" />
          </el-select>
          <div v-if="isCreate && form.kind === 'system'" class="field-hint">
            系统音色写入全局目录，所有用户可用，无需指定用户。
          </div>
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
          <div class="field-hint">Env 默认：{{ envHint }}</div>
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
          <div class="field-hint">按音色特质设置；所有用户使用该音色讲故事时生效，试听也会用此语速。</div>
        </el-form-item>
        <el-form-item label="试听">
          <el-button :loading="previewingForm" @click="previewForm">用当前表单试听</el-button>
          <div class="field-hint">合成一句短样例（不落库）；保存前可先验证 Provider / Model / Voice ID / 语速。</div>
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
code {
  font-size: 12px;
}
</style>

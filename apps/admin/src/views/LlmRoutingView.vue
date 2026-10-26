<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { api } from '@/api/client'
import { formatAdminTime } from '@/utils/datetime'

interface ModelBrief {
  id: number
  provider: string
  model_id: string
  tier: string
  label_zh: string
  enabled: boolean
}

interface RuleRow {
  id: number
  stage: string
  priority: number
  match_json: string
  target_llm_model_id: number | null
  target_model: ModelBrief | null
  enabled: boolean
  label_zh: string
  updated_at: string | null
}

const loading = ref(false)
const saving = ref(false)
const items = ref<RuleRow[]>([])
const models = ref<ModelBrief[]>([])
const stages = ref<string[]>(['story_draft'])
const priorityHint = ref('')
const dialogOpen = ref(false)
const isCreate = ref(false)
const form = ref<{
  id?: number
  stage: string
  priority: number
  match_json: string
  target_llm_model_id: number | null
  enabled: boolean
  label_zh: string
} | null>(null)

const modelOptions = computed(() =>
  models.value.map((m) => ({
    value: m.id,
    label: `#${m.id} ${m.label_zh || m.model_id} · ${m.provider}/${m.tier}${
      m.enabled ? '' : ' (停用)'
    }`,
  })),
)

function modelLabel(row: RuleRow): string {
  const m = row.target_model
  if (!m) return row.target_llm_model_id ? `#${row.target_llm_model_id}` : '—'
  return `#${m.id} ${m.label_zh || m.model_id} (${m.provider}/${m.tier})`
}

async function load() {
  loading.value = true
  try {
    const { data } = await api.get<{
      items: RuleRow[]
      total: number
      stages: string[]
      models: ModelBrief[]
      priority_hint: string
    }>('/admin/llm-routing-rules')
    items.value = data.items
    models.value = data.models || []
    if (data.stages?.length) stages.value = data.stages
    priorityHint.value = data.priority_hint || ''
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '加载失败')
  } finally {
    loading.value = false
  }
}

function openCreate() {
  if (!models.value.length) {
    ElMessage.warning('请先在「LLM 模型」登记至少一条模型，再配置路由')
    return
  }
  isCreate.value = true
  form.value = {
    stage: 'story_draft',
    priority: 50,
    match_json: '{"duration_minutes_max": 5}',
    target_llm_model_id: models.value.find((m) => m.enabled)?.id ?? models.value[0].id,
    enabled: true,
    label_zh: '',
  }
  dialogOpen.value = true
}

function openEdit(row: RuleRow) {
  isCreate.value = false
  form.value = {
    id: row.id,
    stage: row.stage,
    priority: row.priority,
    match_json: row.match_json,
    target_llm_model_id: row.target_llm_model_id,
    enabled: row.enabled,
    label_zh: row.label_zh,
  }
  dialogOpen.value = true
}

async function save() {
  if (!form.value) return
  const stage = (form.value.stage || '').trim()
  const modelId = form.value.target_llm_model_id
  const matchJson = (form.value.match_json || '').trim() || '{}'
  if (!stage || !modelId) {
    ElMessage.warning('stage / 目标模型 必填')
    return
  }
  try {
    JSON.parse(matchJson)
  } catch {
    ElMessage.warning('match_json 必须是合法 JSON 对象')
    return
  }
  saving.value = true
  try {
    const payload = {
      stage,
      priority: Number(form.value.priority) || 0,
      match_json: matchJson,
      target_llm_model_id: Number(modelId),
      enabled: !!form.value.enabled,
      label_zh: (form.value.label_zh || '').trim(),
    }
    if (isCreate.value) {
      await api.post('/admin/llm-routing-rules', payload)
      ElMessage.success('已创建')
    } else {
      await api.patch(`/admin/llm-routing-rules/${form.value.id}`, payload)
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

async function remove(row: RuleRow) {
  try {
    await ElMessageBox.confirm(`删除规则「${row.label_zh || row.id}」？`, '确认', {
      type: 'warning',
    })
  } catch {
    return
  }
  try {
    await api.delete(`/admin/llm-routing-rules/${row.id}`)
    ElMessage.success('已删除')
    await load()
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '删除失败')
  }
}

onMounted(load)
</script>

<template>
  <div v-loading="loading">
    <div class="head">
      <h2>LLM 路由</h2>
      <el-button type="primary" @click="openCreate">新增</el-button>
    </div>
    <p class="hint">
      条件匹配后直接绑定「LLM 模型」实例（含 provider + model_id），可跨厂商。例如
      <code>story_draft</code> +
      <code>{"duration_minutes_max": 5}</code> → 某条 mini 实例；空
      <code>{}</code> 作兜底。priority 越小越先匹配。选型优先级：{{
        priorityHint || 'force > Agent > 路由实例 > env'
      }}。
    </p>
    <el-table :data="items" stripe style="width: 100%">
      <el-table-column prop="stage" label="Stage" min-width="150" />
      <el-table-column prop="priority" label="Priority" width="90" />
      <el-table-column prop="label_zh" label="名称" min-width="120" />
      <el-table-column prop="match_json" label="Match" min-width="180" />
      <el-table-column label="目标模型" min-width="220">
        <template #default="{ row }">{{ modelLabel(row) }}</template>
      </el-table-column>
      <el-table-column label="启用" width="80">
        <template #default="{ row }">
          <el-tag :type="row.enabled ? 'success' : 'info'" size="small">
            {{ row.enabled ? '是' : '否' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="更新" width="170">
        <template #default="{ row }">{{ formatAdminTime(row.updated_at) }}</template>
      </el-table-column>
      <el-table-column label="操作" width="140" fixed="right">
        <template #default="{ row }">
          <el-button type="primary" link @click="openEdit(row)">编辑</el-button>
          <el-button type="danger" link @click="remove(row)">删除</el-button>
        </template>
      </el-table-column>
    </el-table>

    <el-dialog
      v-model="dialogOpen"
      :title="isCreate ? '新增规则' : '编辑规则'"
      width="560px"
      destroy-on-close
    >
      <el-form v-if="form" label-width="110px">
        <el-form-item label="Stage" required>
          <el-select v-model="form.stage" style="width: 100%" filterable allow-create>
            <el-option v-for="s in stages" :key="s" :label="s" :value="s" />
          </el-select>
        </el-form-item>
        <el-form-item label="Priority">
          <el-input-number v-model="form.priority" :step="10" />
        </el-form-item>
        <el-form-item label="名称">
          <el-input v-model="form.label_zh" placeholder="如：短故事" />
        </el-form-item>
        <el-form-item label="Match JSON" required>
          <el-input
            v-model="form.match_json"
            type="textarea"
            :rows="3"
            class="mono"
            placeholder='{"duration_minutes_max": 5} 或 {}'
          />
        </el-form-item>
        <el-form-item label="目标模型" required>
          <el-select
            v-model="form.target_llm_model_id"
            style="width: 100%"
            filterable
            placeholder="选择 llm_models 实例"
          >
            <el-option
              v-for="opt in modelOptions"
              :key="opt.value"
              :label="opt.label"
              :value="opt.value"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="启用">
          <el-switch v-model="form.enabled" />
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
.head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
.hint {
  color: var(--el-text-color-secondary);
  margin: 0 0 16px;
  max-width: 760px;
  line-height: 1.5;
}
.mono :deep(textarea) {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 12px;
}
</style>

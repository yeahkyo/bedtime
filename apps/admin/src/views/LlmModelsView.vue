<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { api } from '@/api/client'
import { formatAdminTime } from '@/utils/datetime'

interface LlmModelRow {
  id: number
  provider: string
  model_id: string
  tier: string
  label_zh: string
  enabled: boolean
  sort_order: number
  notes: string | null
  updated_at: string | null
}

const loading = ref(false)
const saving = ref(false)
const items = ref<LlmModelRow[]>([])
const tiers = ref<string[]>(['mini', 'lite', 'pro'])
const providers = ref<string[]>(['doubao', 'openai', 'deepseek', 'mock'])
const dialogOpen = ref(false)
const isCreate = ref(false)
const form = ref<Partial<LlmModelRow> | null>(null)

async function load() {
  loading.value = true
  try {
    const { data } = await api.get<{
      items: LlmModelRow[]
      total: number
      tiers: string[]
      providers: string[]
    }>('/admin/llm-models')
    items.value = data.items
    if (data.tiers?.length) tiers.value = data.tiers
    if (data.providers?.length) providers.value = data.providers
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '加载失败')
  } finally {
    loading.value = false
  }
}

function openCreate() {
  isCreate.value = true
  form.value = {
    provider: providers.value[0] || 'doubao',
    model_id: '',
    tier: 'lite',
    label_zh: '',
    enabled: true,
    sort_order: 0,
    notes: '',
  }
  dialogOpen.value = true
}

function openEdit(row: LlmModelRow) {
  isCreate.value = false
  form.value = { ...row, notes: row.notes || '' }
  dialogOpen.value = true
}

async function save() {
  if (!form.value) return
  const provider = (form.value.provider || '').trim()
  const modelId = (form.value.model_id || '').trim()
  const tier = (form.value.tier || '').trim()
  if (!provider || !modelId || !tier) {
    ElMessage.warning('provider / model_id / tier 必填')
    return
  }
  saving.value = true
  try {
    if (isCreate.value) {
      await api.post('/admin/llm-models', {
        provider,
        model_id: modelId,
        tier,
        label_zh: (form.value.label_zh || '').trim(),
        enabled: !!form.value.enabled,
        sort_order: Number(form.value.sort_order) || 0,
        notes: (form.value.notes || '').trim() || null,
      })
      ElMessage.success('已创建')
    } else {
      await api.patch(`/admin/llm-models/${form.value.id}`, {
        provider,
        model_id: modelId,
        tier,
        label_zh: (form.value.label_zh || '').trim(),
        enabled: !!form.value.enabled,
        sort_order: Number(form.value.sort_order) || 0,
        notes: (form.value.notes || '').trim() || null,
        clear_notes: !(form.value.notes || '').trim(),
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

async function remove(row: LlmModelRow) {
  try {
    await ElMessageBox.confirm(`删除模型「${row.label_zh || row.model_id}」？`, '确认', {
      type: 'warning',
    })
  } catch {
    return
  }
  try {
    await api.delete(`/admin/llm-models/${row.id}`)
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
      <h2>LLM 模型</h2>
      <el-button type="primary" @click="openCreate">新增</el-button>
    </div>
    <p class="hint">
      自行登记可用的 provider + model_id，并挂内部档位
      <code>mini</code> / <code>lite</code> / <code>pro</code>（不会自动灌模型）。路由只选档位；未登记时回退
      env 默认模型。同 provider+tier 多行时取 <code>sort_order</code> 最小且启用的一条。
    </p>
    <el-table :data="items" stripe style="width: 100%">
      <el-table-column prop="provider" label="Provider" width="110" />
      <el-table-column prop="tier" label="Tier" width="90" />
      <el-table-column prop="model_id" label="Model ID" min-width="180" />
      <el-table-column prop="label_zh" label="名称" min-width="140" />
      <el-table-column prop="sort_order" label="排序" width="80" />
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
      :title="isCreate ? '新增模型' : '编辑模型'"
      width="560px"
      destroy-on-close
    >
      <el-form v-if="form" label-width="100px">
        <el-form-item label="Provider" required>
          <el-select v-model="form.provider" style="width: 100%">
            <el-option v-for="p in providers" :key="p" :label="p" :value="p" />
          </el-select>
        </el-form-item>
        <el-form-item label="Tier" required>
          <el-select v-model="form.tier" style="width: 100%">
            <el-option v-for="t in tiers" :key="t" :label="t" :value="t" />
          </el-select>
        </el-form-item>
        <el-form-item label="Model ID" required>
          <el-input v-model="form.model_id" placeholder="服务商真实模型 id" />
        </el-form-item>
        <el-form-item label="名称">
          <el-input v-model="form.label_zh" />
        </el-form-item>
        <el-form-item label="排序">
          <el-input-number v-model="form.sort_order" :step="10" />
        </el-form-item>
        <el-form-item label="启用">
          <el-switch v-model="form.enabled" />
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="form.notes" type="textarea" :rows="2" />
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
  max-width: 720px;
  line-height: 1.5;
}
</style>

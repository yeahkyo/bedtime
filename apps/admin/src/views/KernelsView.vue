<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { api } from '@/api/client'

interface KernelRow {
  id: string
  axis: string
  axis_label?: string | null
  name: string
  soft_guidance: string
  age_stage: string
  age_stage_label_zh?: string | null
  focus_id: string
  enabled: boolean
  sort_order: number
}

interface AgeStage {
  id: string
  label_zh: string
  theory_hint?: string
}

interface AxisOpt {
  id: string
  label_zh: string
  theory_brief?: string
  default_focus_id?: string
}

const AGE_STAGES = [
  { id: 'toddler_2_3', label: '幼儿期 2–3' },
  { id: 'preschool_3_5', label: '学前期 3–5' },
  { id: 'early_school_6_8', label: '学龄初 6–8' },
  { id: 'late_school_9_12', label: '学龄中 9–12' },
]

const LS_PROVIDER = 'bedtime.admin.kernelGen.provider'
const LS_MODEL = 'bedtime.admin.kernelGen.model'

const loading = ref(false)
const saving = ref(false)
const generating = ref(false)
const items = ref<KernelRow[]>([])
const total = ref(0)
const page = ref(1)
const pageSize = ref(50)
const filterStage = ref('')
const filterAxis = ref('')
const filterEnabled = ref<boolean | ''>('')
const filterQ = ref('')

const dialogOpen = ref(false)
const isCreate = ref(false)
const form = ref({
  id: '',
  axis: 'courage',
  name: '',
  soft_guidance: '',
  age_stage: 'preschool_3_5',
  focus_id: '',
  enabled: true,
  sort_order: 0,
})

const genOpen = ref(false)
const genProvider = ref('deepseek')
const genModel = ref('')
const genCount = ref(10)
const genAgeStage = ref('preschool_3_5')
const genAxis = ref('courage')
const modelDefaults = ref<Record<string, string>>({})
const ageStagesApi = ref<AgeStage[]>([])
const axesApi = ref<AxisOpt[]>([])

const genAxisBrief = computed(() => {
  const a = axesApi.value.find((x) => x.id === genAxis.value)
  return a?.theory_brief || ''
})

const genStageHint = computed(() => {
  const s = ageStagesApi.value.find((x) => x.id === genAgeStage.value)
  return s?.theory_hint || ''
})

const genStageOptions = computed(() => {
  if (ageStagesApi.value.length) {
    return ageStagesApi.value.map((s) => ({ id: s.id, label: s.label_zh }))
  }
  return AGE_STAGES.map((s) => ({ id: s.id, label: s.label }))
})

async function load() {
  loading.value = true
  try {
    const params: Record<string, string | number | boolean> = {
      limit: pageSize.value,
      offset: (page.value - 1) * pageSize.value,
    }
    if (filterStage.value) params.age_stage = filterStage.value
    if (filterAxis.value.trim()) params.axis = filterAxis.value.trim()
    if (filterEnabled.value !== '') params.enabled = filterEnabled.value
    if (filterQ.value.trim()) params.q = filterQ.value.trim()
    const { data } = await api.get<{ items: KernelRow[]; total: number }>('/admin/kernels', {
      params,
    })
    items.value = data.items
    total.value = data.total
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '加载失败')
  } finally {
    loading.value = false
  }
}

function search() {
  page.value = 1
  load()
}

async function seed() {
  try {
    const { data } = await api.post<{ upserted: number }>('/admin/kernels/seed')
    ElMessage.success(`已同步 canonical ${data.upserted} 条`)
    await load()
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '同步失败')
  }
}

async function loadDefaults() {
  try {
    const { data } = await api.get<{
      providers: string[]
      defaults: Record<string, string>
      age_stages?: AgeStage[]
      axes?: AxisOpt[]
    }>('/admin/kernels/generate-defaults')
    modelDefaults.value = data.defaults || {}
    ageStagesApi.value = data.age_stages || []
    axesApi.value = data.axes || []
    const savedP = localStorage.getItem(LS_PROVIDER)
    if (savedP && data.providers.includes(savedP)) genProvider.value = savedP
    const savedM = localStorage.getItem(LS_MODEL)
    if (savedM) genModel.value = savedM
    else genModel.value = modelDefaults.value[genProvider.value] || ''
    if (axesApi.value.length && !axesApi.value.some((a) => a.id === genAxis.value)) {
      genAxis.value = axesApi.value[0].id
    }
  } catch {
    /* ignore */
  }
}

function openGenerate() {
  if (!genModel.value) genModel.value = modelDefaults.value[genProvider.value] || ''
  genOpen.value = true
}

watch(genProvider, (p) => {
  const def = modelDefaults.value[p]
  if (def && (!genModel.value || Object.values(modelDefaults.value).includes(genModel.value))) {
    genModel.value = def
  }
})

async function runGenerate() {
  if (!genAxis.value || !genAgeStage.value) {
    ElMessage.warning('请选择发展阶段与主题轴')
    return
  }
  if (!genModel.value.trim() && genProvider.value !== 'mock') {
    ElMessage.warning('请填写 model')
    return
  }
  generating.value = true
  try {
    localStorage.setItem(LS_PROVIDER, genProvider.value)
    localStorage.setItem(LS_MODEL, genModel.value.trim())
    const { data } = await api.post<{
      created: number
      updated: number
      total: number
      axis_label?: string
    }>(
      '/admin/kernels/generate',
      {
        age_stage: genAgeStage.value,
        axis: genAxis.value,
        provider: genProvider.value,
        model: genModel.value.trim() || 'mock',
        count: genCount.value,
      },
      { timeout: 320_000 },
    )
    ElMessage.success(
      `已生成 ${data.total} 条（新建 ${data.created} / 更新 ${data.updated}），均为未启用待审`,
    )
    genOpen.value = false
    filterEnabled.value = false
    filterStage.value = genAgeStage.value
    filterAxis.value = genAxis.value
    page.value = 1
    await load()
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '生成失败')
  } finally {
    generating.value = false
  }
}

function openCreate() {
  isCreate.value = true
  form.value = {
    id: '',
    axis: 'courage',
    name: '',
    soft_guidance: '',
    age_stage: 'preschool_3_5',
    focus_id: '',
    enabled: true,
    sort_order: 0,
  }
  dialogOpen.value = true
}

function openEdit(row: KernelRow) {
  isCreate.value = false
  form.value = {
    id: row.id,
    axis: row.axis,
    name: row.name,
    soft_guidance: row.soft_guidance,
    age_stage: row.age_stage,
    focus_id: row.focus_id,
    enabled: row.enabled,
    sort_order: row.sort_order,
  }
  dialogOpen.value = true
}

async function save() {
  saving.value = true
  try {
    const payload = {
      axis: form.value.axis.trim(),
      name: form.value.name.trim(),
      soft_guidance: form.value.soft_guidance.trim(),
      age_stage: form.value.age_stage,
      focus_id: form.value.focus_id.trim(),
      enabled: form.value.enabled,
      sort_order: form.value.sort_order,
    }
    if (isCreate.value) {
      await api.post('/admin/kernels', { id: form.value.id.trim(), ...payload })
      ElMessage.success('已创建')
    } else {
      await api.patch(`/admin/kernels/${form.value.id}`, payload)
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

async function toggleEnabled(row: KernelRow, enabled: string | number | boolean) {
  try {
    await api.patch(`/admin/kernels/${row.id}`, { enabled: Boolean(enabled) })
    await load()
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '更新失败')
    await load()
  }
}

async function remove(row: KernelRow) {
  try {
    await ElMessageBox.confirm(`删除内核「${row.name}」(${row.id})？`, '确认删除', {
      type: 'warning',
    })
  } catch {
    return
  }
  try {
    await api.delete(`/admin/kernels/${row.id}`)
    ElMessage.success('已删除')
    await load()
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '删除失败')
  }
}

onMounted(async () => {
  await loadDefaults()
  await load()
})
</script>

<template>
  <div>
    <div class="toolbar">
      <h2>故事内核</h2>
      <div class="actions">
        <el-button @click="openGenerate">LLM 生成</el-button>
        <el-button @click="seed">同步 canonical</el-button>
        <el-button type="primary" @click="openCreate">新建</el-button>
      </div>
    </div>
    <p class="hint">
      发展性主题轴（勇气、自我、好奇等）——故事引力，不是情节种子，也不是品德口号。可按发展心理学理论 LLM
      批量导入（默认未启用，请审核后开启）。与客观「故事元素」分工不同。
    </p>

    <div class="filters">
      <el-select v-model="filterStage" clearable placeholder="发展阶段" style="width: 180px" @change="search">
        <el-option v-for="s in AGE_STAGES" :key="s.id" :label="s.label" :value="s.id" />
      </el-select>
      <el-input
        v-model="filterAxis"
        clearable
        placeholder="axis（如 courage）"
        style="width: 160px"
        @keyup.enter="search"
        @clear="search"
      />
      <el-select v-model="filterEnabled" clearable placeholder="启用" style="width: 120px" @change="search">
        <el-option label="启用" :value="true" />
        <el-option label="未启用" :value="false" />
      </el-select>
      <el-input
        v-model="filterQ"
        clearable
        placeholder="搜索 name / id"
        style="width: 200px"
        @keyup.enter="search"
        @clear="search"
      />
      <el-button @click="search">筛选</el-button>
    </div>

    <el-table v-loading="loading" :data="items" stripe>
      <el-table-column prop="id" label="ID" width="180" show-overflow-tooltip />
      <el-table-column label="轴" width="110">
        <template #default="{ row }">{{ row.axis_label || row.axis }}</template>
      </el-table-column>
      <el-table-column prop="name" label="名称" min-width="120" show-overflow-tooltip />
      <el-table-column label="阶段" width="140" show-overflow-tooltip>
        <template #default="{ row }">{{ row.age_stage_label_zh || row.age_stage }}</template>
      </el-table-column>
      <el-table-column prop="focus_id" label="focus" width="130" show-overflow-tooltip />
      <el-table-column label="启用" width="80">
        <template #default="{ row }">
          <el-switch :model-value="row.enabled" @change="(v) => toggleEnabled(row, v)" />
        </template>
      </el-table-column>
      <el-table-column label="操作" width="140" fixed="right">
        <template #default="{ row }">
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
        :page-sizes="[20, 50, 100]"
        layout="total, sizes, prev, pager, next"
        background
        @current-change="load"
        @size-change="search"
      />
    </div>

    <el-dialog
      v-model="dialogOpen"
      :title="isCreate ? '新建内核' : `编辑 ${form.id}`"
      width="720px"
      destroy-on-close
    >
      <el-form label-width="110px">
        <el-form-item v-if="isCreate" label="ID">
          <el-input v-model="form.id" placeholder="snake_case" />
        </el-form-item>
        <el-form-item label="轴 axis">
          <el-input v-model="form.axis" placeholder="courage / self / curiosity…" />
        </el-form-item>
        <el-form-item label="名称">
          <el-input v-model="form.name" />
        </el-form-item>
        <el-form-item label="轻触指引">
          <el-input
            v-model="form.soft_guidance"
            type="textarea"
            :rows="4"
            placeholder="如何轻触为故事引力；禁止说教"
          />
        </el-form-item>
        <el-form-item label="发展阶段">
          <el-select v-model="form.age_stage" style="width: 100%">
            <el-option v-for="s in AGE_STAGES" :key="s.id" :label="s.label" :value="s.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="focus_id">
          <el-input v-model="form.focus_id" placeholder="对接 beat 的 focus id" />
        </el-form-item>
        <el-form-item label="排序">
          <el-input-number v-model="form.sort_order" :min="0" />
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

    <el-dialog
      v-model="genOpen"
      title="LLM 批量生成内核"
      width="680px"
      destroy-on-close
      :close-on-click-modal="!generating"
    >
      <el-form label-width="110px">
        <el-form-item label="发展阶段" required>
          <el-select v-model="genAgeStage" style="width: 100%">
            <el-option v-for="s in genStageOptions" :key="s.id" :label="s.label" :value="s.id" />
          </el-select>
          <p class="brief">{{ genStageHint }}</p>
        </el-form-item>
        <el-form-item label="主题轴" required>
          <el-select v-model="genAxis" style="width: 100%">
            <el-option
              v-for="a in axesApi"
              :key="a.id"
              :label="`${a.label_zh} (${a.id})`"
              :value="a.id"
            />
          </el-select>
          <p class="brief">{{ genAxisBrief }}</p>
        </el-form-item>
        <el-form-item label="Provider" required>
          <el-select v-model="genProvider" style="width: 100%">
            <el-option label="deepseek" value="deepseek" />
            <el-option label="openai" value="openai" />
            <el-option label="doubao" value="doubao" />
            <el-option label="mock（测试）" value="mock" />
          </el-select>
        </el-form-item>
        <el-form-item label="Model" required>
          <el-input
            v-model="genModel"
            :placeholder="modelDefaults[genProvider] || '模型 id'"
            :disabled="genProvider === 'mock'"
          />
        </el-form-item>
        <el-form-item label="数量">
          <el-input-number v-model="genCount" :min="1" :max="30" />
        </el-form-item>
        <p class="muted">
          按 Erikson / 依恋 / 情绪教练等理论生成一般主题轴条目。结果一律未启用，请人工审核后打开开关。
        </p>
      </el-form>
      <template #footer>
        <el-button :disabled="generating" @click="genOpen = false">取消</el-button>
        <el-button type="primary" :loading="generating" @click="runGenerate">开始生成</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 8px;
}
.actions {
  display: flex;
  gap: 8px;
}
.hint {
  color: var(--el-text-color-secondary);
  font-size: 13px;
  margin: 0 0 16px;
}
.filters {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  align-items: center;
  margin-bottom: 16px;
}
.pager {
  display: flex;
  justify-content: flex-end;
  margin-top: 16px;
}
.brief {
  margin: 6px 0 0;
  color: var(--el-text-color-regular);
  font-size: 13px;
  line-height: 1.5;
  white-space: pre-wrap;
}
.muted {
  color: var(--el-text-color-secondary);
  font-size: 13px;
}
</style>

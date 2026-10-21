<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { api } from '@/api/client'

interface Category {
  id: string
  label_zh: string
  label_en: string
  sort_order: number
  enabled: boolean
}

interface Subcategory {
  id: string
  category_id: string
  label_zh: string
  label_en: string
  generation_brief?: string | null
  id_prefix?: string | null
  sort_order: number
  enabled: boolean
}

interface AgeStage {
  id: string
  label_zh: string
  label_en: string
  min_age_years: number
  max_age_years: number
  target_share: number
  theory_hint: string
}

interface ElementRow {
  id: string
  category_id: string
  subcategory_id: string
  name: string
  description: string
  age_stage: string
  age_stage_label_zh?: string | null
  enabled: boolean
  category_label_zh?: string | null
  subcategory_label_zh?: string | null
}

interface Inventory {
  subcategory_id: string
  target_total: number
  targets: Record<string, number>
  counts: Record<string, number>
  gaps: Record<string, number>
  total: number
}

const LS_PROVIDER = 'bedtime.admin.elementGen.provider'
const LS_MODEL = 'bedtime.admin.elementGen.model'

const loading = ref(false)
const saving = ref(false)
const generating = ref(false)
const categories = ref<Category[]>([])
const subcategories = ref<Subcategory[]>([])
const ageStages = ref<AgeStage[]>([])
const items = ref<ElementRow[]>([])
const total = ref(0)
const page = ref(1)
const pageSize = ref(50)
const inventory = ref<Inventory | null>(null)

const filterCategory = ref<string>('')
const filterSubcategory = ref<string>('')
const filterEnabled = ref<boolean | ''>(false)
const filterStage = ref<string>('')
const filterQ = ref('')

const dialogOpen = ref(false)
const isCreate = ref(false)
const form = ref({
  id: '',
  category_id: '',
  subcategory_id: '',
  name: '',
  description: '',
  age_stage: 'preschool_3_5',
  enabled: true,
})

const genOpen = ref(false)
const genProvider = ref('deepseek')
const genModel = ref('')
const genCount = ref(25)
const genCategoryId = ref('')
const genSubcategoryId = ref('')
const genAgeStage = ref('preschool_3_5')
const modelDefaults = ref<Record<string, string>>({})

const filteredSubs = computed(() => {
  const cid = form.value.category_id || filterCategory.value
  if (!cid) return subcategories.value
  return subcategories.value.filter((s) => s.category_id === cid)
})

const filterSubs = computed(() => {
  if (!filterCategory.value) return subcategories.value
  return subcategories.value.filter((s) => s.category_id === filterCategory.value)
})

const canonicalSubs = computed(() =>
  subcategories.value.filter((s) => s.generation_brief && s.id_prefix),
)

const genSubs = computed(() => {
  if (!genCategoryId.value) return canonicalSubs.value
  return canonicalSubs.value.filter((s) => s.category_id === genCategoryId.value)
})

const genBrief = computed(() => {
  const sub = canonicalSubs.value.find((s) => s.id === genSubcategoryId.value)
  return sub?.generation_brief || ''
})

const genStageHint = computed(() => {
  const s = ageStages.value.find((x) => x.id === genAgeStage.value)
  return s?.theory_hint || ''
})

const inventoryLine = computed(() => {
  if (!inventory.value) return ''
  return ageStages.value
    .map((s) => {
      const c = inventory.value!.counts[s.id] ?? 0
      const t = inventory.value!.targets[s.id] ?? 0
      return `${s.label_zh}: ${c}/${t}`
    })
    .join(' · ')
})

async function loadTaxonomy() {
  const [cats, subs] = await Promise.all([
    api.get<{ items: Category[] }>('/admin/element-categories'),
    api.get<{ items: Subcategory[] }>('/admin/element-subcategories'),
  ])
  categories.value = cats.data.items
  subcategories.value = subs.data.items
}

async function loadDefaults() {
  try {
    const { data } = await api.get<{
      providers: string[]
      defaults: Record<string, string>
      age_stages?: AgeStage[]
    }>('/admin/elements/generate-defaults')
    modelDefaults.value = data.defaults || {}
    ageStages.value = data.age_stages || []
    const savedP = localStorage.getItem(LS_PROVIDER)
    if (savedP && data.providers.includes(savedP)) genProvider.value = savedP
    const savedM = localStorage.getItem(LS_MODEL)
    if (savedM) {
      genModel.value = savedM
    } else {
      genModel.value = modelDefaults.value[genProvider.value] || ''
    }
    if (ageStages.value.length && !ageStages.value.some((s) => s.id === genAgeStage.value)) {
      genAgeStage.value = ageStages.value[0].id
    }
  } catch {
    /* ignore */
  }
}

async function loadInventory() {
  if (!filterSubcategory.value) {
    inventory.value = null
    return
  }
  try {
    const { data } = await api.get<Inventory>('/admin/elements/inventory', {
      params: { subcategory_id: filterSubcategory.value },
    })
    inventory.value = data
  } catch {
    inventory.value = null
  }
}

async function load() {
  loading.value = true
  try {
    const params: Record<string, string | number | boolean> = {
      limit: pageSize.value,
      offset: (page.value - 1) * pageSize.value,
    }
    if (filterCategory.value) params.category_id = filterCategory.value
    if (filterSubcategory.value) params.subcategory_id = filterSubcategory.value
    if (filterEnabled.value !== '') params.enabled = filterEnabled.value
    if (filterStage.value) params.age_stage = filterStage.value
    if (filterQ.value.trim()) params.q = filterQ.value.trim()
    const { data } = await api.get<{ items: ElementRow[]; total: number }>('/admin/elements', {
      params,
    })
    items.value = data.items
    total.value = data.total
    const maxPage = Math.max(1, Math.ceil((data.total || 0) / pageSize.value) || 1)
    if (page.value > maxPage) {
      page.value = maxPage
      loading.value = false
      await load()
      return
    }
    await loadInventory()
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

function openCreate() {
  isCreate.value = true
  form.value = {
    id: '',
    category_id: categories.value[0]?.id || '',
    subcategory_id: '',
    name: '',
    description: '',
    age_stage: 'preschool_3_5',
    enabled: true,
  }
  const firstSub = filteredSubs.value[0]
  if (firstSub) form.value.subcategory_id = firstSub.id
  dialogOpen.value = true
}

function openEdit(row: ElementRow) {
  isCreate.value = false
  form.value = {
    id: row.id,
    category_id: row.category_id,
    subcategory_id: row.subcategory_id,
    name: row.name,
    description: row.description,
    age_stage: row.age_stage,
    enabled: row.enabled,
  }
  dialogOpen.value = true
}

function openGenerate() {
  genCategoryId.value = categories.value[0]?.id || ''
  const first = genSubs.value[0]
  genSubcategoryId.value = first?.id || ''
  if (!genModel.value) {
    genModel.value = modelDefaults.value[genProvider.value] || ''
  }
  // Prefer stage with largest inventory gap when subcategory known.
  if (inventory.value && ageStages.value.length) {
    let best = genAgeStage.value
    let bestGap = -1
    for (const s of ageStages.value) {
      const g = inventory.value.gaps[s.id] ?? 0
      if (g > bestGap) {
        bestGap = g
        best = s.id
      }
    }
    genAgeStage.value = best
    const gap = inventory.value.gaps[best] ?? genCount.value
    if (gap > 0) genCount.value = Math.min(50, Math.max(1, gap))
  }
  genOpen.value = true
}

watch(
  () => form.value.category_id,
  (cid) => {
    const ok = subcategories.value.some(
      (s) => s.id === form.value.subcategory_id && s.category_id === cid,
    )
    if (!ok) {
      const first = subcategories.value.find((s) => s.category_id === cid)
      form.value.subcategory_id = first?.id || ''
    }
  },
)

watch(genCategoryId, () => {
  const ok = genSubs.value.some((s) => s.id === genSubcategoryId.value)
  if (!ok) genSubcategoryId.value = genSubs.value[0]?.id || ''
})

watch(genProvider, (p) => {
  const def = modelDefaults.value[p]
  if (def && (!genModel.value || Object.values(modelDefaults.value).includes(genModel.value))) {
    genModel.value = def
  }
})

async function save() {
  saving.value = true
  try {
    const payload = {
      category_id: form.value.category_id,
      subcategory_id: form.value.subcategory_id,
      name: form.value.name.trim(),
      description: form.value.description.trim(),
      age_stage: form.value.age_stage,
      enabled: form.value.enabled,
    }
    if (isCreate.value) {
      await api.post('/admin/elements', { id: form.value.id.trim(), ...payload })
      ElMessage.success('已创建')
    } else {
      await api.patch(`/admin/elements/${form.value.id}`, payload)
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

async function runGenerate() {
  if (!genSubcategoryId.value) {
    ElMessage.warning('请选择子类')
    return
  }
  if (!genAgeStage.value) {
    ElMessage.warning('请选择发展年龄阶段')
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
      provider: string
      model: string
      age_stage: string
      inventory?: Inventory
    }>(
      '/admin/elements/generate',
      {
        subcategory_id: genSubcategoryId.value,
        age_stage: genAgeStage.value,
        provider: genProvider.value,
        model: genModel.value.trim() || 'mock',
        count: genCount.value,
      },
      { timeout: 320_000 },
    )
    ElMessage.success(
      `已生成 ${data.total} 条（新建 ${data.created} / 更新 ${data.updated}）；新建默认启用，可按条关闭`,
    )
    if (data.inventory) inventory.value = data.inventory
    genOpen.value = false
    filterEnabled.value = true
    filterCategory.value = genCategoryId.value
    filterSubcategory.value = genSubcategoryId.value
    filterStage.value = genAgeStage.value
    page.value = 1
    await load()
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '生成失败')
  } finally {
    generating.value = false
  }
}

async function toggleEnabled(row: ElementRow, enabled: string | number | boolean) {
  try {
    await api.patch(`/admin/elements/${row.id}`, { enabled: Boolean(enabled) })
    await load()
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '更新失败')
    await load()
  }
}

async function remove(row: ElementRow) {
  try {
    await ElMessageBox.confirm(`删除元素「${row.name}」(${row.id})？`, '确认删除', {
      type: 'warning',
    })
  } catch {
    return
  }
  try {
    await api.delete(`/admin/elements/${row.id}`)
    ElMessage.success('已删除')
    await load()
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '删除失败')
  }
}

onMounted(async () => {
  try {
    await loadTaxonomy()
    await loadDefaults()
    await load()
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '加载失败')
  }
})
</script>

<template>
  <div>
    <div class="toolbar">
      <h2>故事元素</h2>
      <div class="actions">
        <el-button @click="openGenerate">LLM 生成</el-button>
        <el-button type="primary" @click="openCreate">新建</el-button>
      </div>
    </div>
    <p class="hint">
      客观认知目录（name / description / 发展年龄阶段）。条目不是故事主题或寓意。LLM
      按阶段生成，新建默认启用（可关闭）；推荐只取已启用条目，按阶段过滤。
    </p>

    <div class="filters">
      <el-select
        v-model="filterCategory"
        clearable
        placeholder="类别"
        style="width: 180px"
        @change="
          filterSubcategory = '';
          search()
        "
      >
        <el-option v-for="c in categories" :key="c.id" :label="c.label_zh" :value="c.id" />
      </el-select>
      <el-select
        v-model="filterSubcategory"
        clearable
        placeholder="子类"
        style="width: 180px"
        @change="search"
      >
        <el-option v-for="s in filterSubs" :key="s.id" :label="s.label_zh" :value="s.id" />
      </el-select>
      <el-select
        v-model="filterStage"
        clearable
        placeholder="发展阶段"
        style="width: 200px"
        @change="search"
      >
        <el-option v-for="s in ageStages" :key="s.id" :label="s.label_zh" :value="s.id" />
      </el-select>
      <el-select
        v-model="filterEnabled"
        clearable
        placeholder="启用"
        style="width: 140px"
        @change="search"
      >
        <el-option label="启用" :value="true" />
        <el-option label="未启用（待审）" :value="false" />
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
    <p v-if="inventoryLine" class="inventory">库存分布 · {{ inventoryLine }}</p>

    <el-table v-loading="loading" :data="items" stripe>
      <el-table-column prop="id" label="ID" width="120" show-overflow-tooltip />
      <el-table-column label="类别" width="120" show-overflow-tooltip>
        <template #default="{ row }">{{ row.category_label_zh || row.category_id }}</template>
      </el-table-column>
      <el-table-column label="子类" width="130" show-overflow-tooltip>
        <template #default="{ row }">{{ row.subcategory_label_zh || row.subcategory_id }}</template>
      </el-table-column>
      <el-table-column prop="name" label="名称" min-width="140" show-overflow-tooltip />
      <el-table-column label="发展阶段" width="160" show-overflow-tooltip>
        <template #default="{ row }">{{ row.age_stage_label_zh || row.age_stage }}</template>
      </el-table-column>
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
        :page-sizes="[20, 50, 100, 200]"
        layout="total, sizes, prev, pager, next"
        background
        @current-change="load"
        @size-change="search"
      />
    </div>

    <el-dialog
      v-model="dialogOpen"
      :title="isCreate ? '新建元素' : `编辑 ${form.id}`"
      width="720px"
      destroy-on-close
    >
      <el-form label-width="110px">
        <el-form-item v-if="isCreate" label="ID">
          <el-input v-model="form.id" placeholder="snake_case" />
        </el-form-item>
        <el-form-item label="类别">
          <el-select v-model="form.category_id" style="width: 100%">
            <el-option v-for="c in categories" :key="c.id" :label="c.label_zh" :value="c.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="子类">
          <el-select v-model="form.subcategory_id" style="width: 100%">
            <el-option v-for="s in filteredSubs" :key="s.id" :label="s.label_zh" :value="s.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="名称">
          <el-input v-model="form.name" placeholder="客观事物/现象名称" />
        </el-form-item>
        <el-form-item label="描述">
          <el-input
            v-model="form.description"
            type="textarea"
            :rows="4"
            placeholder="中性、可观察的客观介绍（非寓意）"
          />
        </el-form-item>
        <el-form-item label="发展阶段">
          <el-select v-model="form.age_stage" style="width: 100%">
            <el-option v-for="s in ageStages" :key="s.id" :label="s.label_zh" :value="s.id" />
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

    <el-dialog
      v-model="genOpen"
      title="LLM 批量生成"
      width="680px"
      destroy-on-close
      :close-on-click-modal="!generating"
    >
      <el-form label-width="110px">
        <el-form-item label="大类">
          <el-select v-model="genCategoryId" style="width: 100%">
            <el-option v-for="c in categories" :key="c.id" :label="c.label_zh" :value="c.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="子类">
          <el-select v-model="genSubcategoryId" style="width: 100%">
            <el-option
              v-for="s in genSubs"
              :key="s.id"
              :label="`${s.label_zh} (${s.id_prefix})`"
              :value="s.id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="发展阶段" required>
          <el-select v-model="genAgeStage" style="width: 100%">
            <el-option
              v-for="s in ageStages"
              :key="s.id"
              :label="`${s.label_zh}（目标约 ${Math.round((s.target_share || 0) * 100)}%）`"
              :value="s.id"
            />
          </el-select>
          <p class="brief">{{ genStageHint }}</p>
        </el-form-item>
        <el-form-item label="生成方向">
          <p class="brief">{{ genBrief || '—' }}</p>
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
            :placeholder="modelDefaults[genProvider] || '填写模型 id，如 deepseek-reasoner'"
            :disabled="genProvider === 'mock'"
          />
        </el-form-item>
        <el-form-item label="数量">
          <el-input-number v-model="genCount" :min="1" :max="50" />
        </el-form-item>
        <p class="muted">
          每次只生成一个发展阶段的客观条目。建议按库存缺口补齐（幼儿 20% / 学前 40% /
          学龄初 25% / 学龄中 15%）。新建默认启用；更新不改动已有启用状态。
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
  margin-bottom: 8px;
}
.inventory {
  color: var(--el-text-color-secondary);
  font-size: 12px;
  margin: 0 0 12px;
}
.pager {
  display: flex;
  justify-content: flex-end;
  margin-top: 16px;
}
.muted {
  color: var(--el-text-color-secondary);
  font-size: 13px;
}
.brief {
  margin: 6px 0 0;
  color: var(--el-text-color-regular);
  font-size: 13px;
  line-height: 1.5;
  white-space: pre-wrap;
}
</style>

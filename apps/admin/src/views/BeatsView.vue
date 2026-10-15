<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { api } from '@/api/client'

export interface BeatPattern {
  id: string
  label: string
  lineage: string
  theme_tags: string[]
  slots: string
  instruction: string
  escalation: string | null
  focus_ids: string[]
  enabled: boolean
  sort_order: number
}

const loading = ref(false)
const saving = ref(false)
const items = ref<BeatPattern[]>([])
const dialogOpen = ref(false)
const isCreate = ref(false)

const form = ref({
  id: '',
  label: '',
  lineage: '',
  theme_tags_text: '',
  focus_ids_text: '',
  slots: 'wish, snag, try_1, try_2, turn_ok',
  instruction: '',
  escalation: '',
  enabled: true,
  sort_order: 0,
})

async function load() {
  loading.value = true
  try {
    const { data } = await api.get<{ items: BeatPattern[]; total: number }>('/admin/beats')
    items.value = data.items
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '加载失败')
  } finally {
    loading.value = false
  }
}

function openCreate() {
  isCreate.value = true
  form.value = {
    id: '',
    label: '',
    lineage: 'fairy',
    theme_tags_text: '',
    focus_ids_text: '',
    slots: 'wish, snag, try_1, try_2, turn_ok',
    instruction: '',
    escalation: '',
    enabled: true,
    sort_order: (items.value.at(-1)?.sort_order ?? 0) + 10,
  }
  dialogOpen.value = true
}

function openEdit(row: BeatPattern) {
  isCreate.value = false
  form.value = {
    id: row.id,
    label: row.label,
    lineage: row.lineage,
    theme_tags_text: row.theme_tags.join('、'),
    focus_ids_text: row.focus_ids.join(', '),
    slots: row.slots,
    instruction: row.instruction,
    escalation: row.escalation || '',
    enabled: row.enabled,
    sort_order: row.sort_order,
  }
  dialogOpen.value = true
}

function splitTags(raw: string): string[] {
  return raw
    .split(/[,，、\n]+/)
    .map((s) => s.trim())
    .filter(Boolean)
}

async function save() {
  saving.value = true
  try {
    const payload = {
      label: form.value.label.trim(),
      lineage: form.value.lineage.trim(),
      theme_tags: splitTags(form.value.theme_tags_text),
      focus_ids: splitTags(form.value.focus_ids_text),
      slots: form.value.slots.trim(),
      instruction: form.value.instruction.trim(),
      escalation: form.value.escalation.trim() || null,
      enabled: form.value.enabled,
      sort_order: form.value.sort_order,
    }
    if (isCreate.value) {
      await api.post('/admin/beats', { id: form.value.id.trim(), ...payload })
      ElMessage.success('已创建')
    } else {
      await api.patch(`/admin/beats/${form.value.id}`, payload)
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

async function toggleEnabled(row: BeatPattern, enabled: string | number | boolean) {
  try {
    await api.patch(`/admin/beats/${row.id}`, { enabled: Boolean(enabled) })
    await load()
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '更新失败')
    await load()
  }
}

async function remove(row: BeatPattern) {
  try {
    await ElMessageBox.confirm(`删除节奏框「${row.label}」(${row.id})？`, '确认删除', {
      type: 'warning',
    })
  } catch {
    return
  }
  try {
    await api.delete(`/admin/beats/${row.id}`)
    ElMessage.success('已删除')
    await load()
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '删除失败')
  }
}

onMounted(load)
</script>

<template>
  <div>
    <div class="toolbar">
      <h2>节奏框</h2>
      <el-button type="primary" @click="openCreate">新建</el-button>
    </div>
    <p class="hint">
      控制故事 Plan 阶段选用的叙事节奏（童话 / 寓言 / 戏剧等）。保存后立即作用于新生成；代码常量仅作空库种子。
    </p>
    <el-table v-loading="loading" :data="items" stripe>
      <el-table-column prop="id" label="ID" width="140" />
      <el-table-column prop="label" label="名称" min-width="120" />
      <el-table-column prop="lineage" label="渊源" width="90" />
      <el-table-column label="主题词" min-width="160" show-overflow-tooltip>
        <template #default="{ row }">{{ row.theme_tags.join('、') }}</template>
      </el-table-column>
      <el-table-column label="焦点" min-width="140" show-overflow-tooltip>
        <template #default="{ row }">{{ row.focus_ids.join(', ') || '—' }}</template>
      </el-table-column>
      <el-table-column prop="sort_order" label="排序" width="70" />
      <el-table-column label="启用" width="80">
        <template #default="{ row }">
          <el-switch :model-value="row.enabled" @change="(v) => toggleEnabled(row, v)" />
        </template>
      </el-table-column>
      <el-table-column label="操作" width="160" fixed="right">
        <template #default="{ row }">
          <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
          <el-button link type="danger" @click="remove(row)">删除</el-button>
        </template>
      </el-table-column>
    </el-table>

    <el-dialog
      v-model="dialogOpen"
      :title="isCreate ? '新建节奏框' : `编辑 ${form.id}`"
      width="720px"
      destroy-on-close
    >
      <el-form label-width="100px">
        <el-form-item v-if="isCreate" label="ID">
          <el-input v-model="form.id" placeholder="snake_case，如 two_gates" />
        </el-form-item>
        <el-form-item label="名称">
          <el-input v-model="form.label" />
        </el-form-item>
        <el-form-item label="渊源">
          <el-input v-model="form.lineage" placeholder="fairy / fable / drama / folk / ritual" />
        </el-form-item>
        <el-form-item label="主题词">
          <el-input
            v-model="form.theme_tags_text"
            type="textarea"
            :rows="2"
            placeholder="逗号或顿号分隔，匹配故事主题"
          />
        </el-form-item>
        <el-form-item label="发展焦点">
          <el-input
            v-model="form.focus_ids_text"
            type="textarea"
            :rows="2"
            placeholder="如 tiny_brave, emotion_held"
          />
        </el-form-item>
        <el-form-item label="slots">
          <el-input v-model="form.slots" />
        </el-form-item>
        <el-form-item label="instruction">
          <el-input v-model="form.instruction" type="textarea" :rows="8" />
        </el-form-item>
        <el-form-item label="escalation">
          <el-input v-model="form.escalation" type="textarea" :rows="3" />
        </el-form-item>
        <el-form-item label="排序">
          <el-input-number v-model="form.sort_order" :step="10" />
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
.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 8px;
}
.hint {
  color: var(--el-text-color-secondary);
  font-size: 13px;
  margin: 0 0 16px;
}
</style>

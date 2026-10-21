<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { api } from '@/api/client'

export interface StoryShapeRow {
  id: string
  label_zh: string
  guidance: string
  effect: string
  beat_min: number
  beat_max: number
  enabled: boolean
  sort_order: number
}

const loading = ref(false)
const saving = ref(false)
const items = ref<StoryShapeRow[]>([])
const dialogOpen = ref(false)
const isCreate = ref(false)

const form = ref({
  id: '',
  label_zh: '',
  guidance: '',
  effect: '',
  beat_min: 3,
  beat_max: 5,
  enabled: true,
  sort_order: 0,
})

async function load() {
  loading.value = true
  try {
    const { data } = await api.get<{ items: StoryShapeRow[]; total: number }>('/admin/shapes')
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
    label_zh: '',
    guidance: '',
    effect: '',
    beat_min: 3,
    beat_max: 5,
    enabled: true,
    sort_order: (items.value.at(-1)?.sort_order ?? 0) + 10,
  }
  dialogOpen.value = true
}

function openEdit(row: StoryShapeRow) {
  isCreate.value = false
  form.value = {
    id: row.id,
    label_zh: row.label_zh,
    guidance: row.guidance,
    effect: row.effect || '',
    beat_min: row.beat_min,
    beat_max: row.beat_max,
    enabled: row.enabled,
    sort_order: row.sort_order,
  }
  dialogOpen.value = true
}

async function save() {
  saving.value = true
  try {
    const payload = {
      label_zh: form.value.label_zh.trim(),
      guidance: form.value.guidance.trim(),
      effect: form.value.effect.trim(),
      beat_min: form.value.beat_min,
      beat_max: form.value.beat_max,
      enabled: form.value.enabled,
      sort_order: form.value.sort_order,
    }
    if (isCreate.value) {
      await api.post('/admin/shapes', { id: form.value.id.trim(), ...payload })
      ElMessage.success('已创建')
    } else {
      await api.patch(`/admin/shapes/${form.value.id}`, payload)
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

async function toggleEnabled(row: StoryShapeRow, enabled: string | number | boolean) {
  try {
    await api.patch(`/admin/shapes/${row.id}`, { enabled: Boolean(enabled) })
    await load()
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '更新失败')
    await load()
  }
}

async function remove(row: StoryShapeRow) {
  try {
    await ElMessageBox.confirm(`删除结构「${row.label_zh}」(${row.id})？`, '确认删除', {
      type: 'warning',
    })
  } catch {
    return
  }
  try {
    await api.delete(`/admin/shapes/${row.id}`)
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
      <h2>故事结构</h2>
      <el-button type="primary" @click="openCreate">新建</el-button>
    </div>
    <p class="hint">
      系统从本表选题，并避开最近两集用过的结构。guidance 是结构功能与睡前边界，会注入构思；
      节拍数量只限制在 beat_min～beat_max，不再使用示例拍。
    </p>
    <el-table v-loading="loading" :data="items" stripe>
      <el-table-column prop="id" label="ID" width="140" />
      <el-table-column prop="label_zh" label="名称" min-width="120" />
      <el-table-column label="节拍数量" width="100">
        <template #default="{ row }">{{ row.beat_min }}–{{ row.beat_max }}</template>
      </el-table-column>
      <el-table-column prop="effect" label="预期效果" min-width="180" show-overflow-tooltip />
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
      :title="isCreate ? '新建故事结构' : `编辑 ${form.id}`"
      width="720px"
      destroy-on-close
    >
      <el-form label-width="110px">
        <el-form-item v-if="isCreate" label="ID">
          <el-input v-model="form.id" placeholder="snake_case，如 binary_op" />
        </el-form-item>
        <el-form-item label="名称">
          <el-input v-model="form.label_zh" />
        </el-form-item>
        <el-form-item label="节拍区间">
          <div class="range">
            <el-input-number v-model="form.beat_min" :min="1" :max="12" />
            <span>–</span>
            <el-input-number v-model="form.beat_max" :min="1" :max="12" />
          </div>
        </el-form-item>
        <el-form-item label="预期效果">
          <el-input v-model="form.effect" placeholder="如：微小张力，最后和解归静" />
        </el-form-item>
        <el-form-item label="guidance">
          <el-input
            v-model="form.guidance"
            type="textarea"
            :rows="8"
            placeholder="结构功能 + 睡前限制，注入给构思模型"
          />
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
.range {
  display: flex;
  align-items: center;
  gap: 8px;
}
</style>

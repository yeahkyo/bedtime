<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { api } from '@/api/client'

interface ThemeSparkRow {
  id: number
  language: string
  text: string
  enabled: boolean
  sort_order: number
}

const loading = ref(false)
const saving = ref(false)
const items = ref<ThemeSparkRow[]>([])
const filterLang = ref('')
const dialogOpen = ref(false)
const isCreate = ref(false)

const form = ref({
  id: 0,
  language: 'zh',
  text: '',
  enabled: true,
  sort_order: 0,
})

async function load() {
  loading.value = true
  try {
    const { data } = await api.get<{ items: ThemeSparkRow[]; total: number }>(
      '/admin/theme-sparks',
      {
        params: {
          ...(filterLang.value ? { language: filterLang.value } : {}),
        },
      },
    )
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
    id: 0,
    language: filterLang.value || 'zh',
    text: '',
    enabled: true,
    sort_order: (items.value.at(-1)?.sort_order ?? 0) + 10,
  }
  dialogOpen.value = true
}

function openEdit(row: ThemeSparkRow) {
  isCreate.value = false
  form.value = {
    id: row.id,
    language: row.language,
    text: row.text,
    enabled: row.enabled,
    sort_order: row.sort_order,
  }
  dialogOpen.value = true
}

async function save() {
  saving.value = true
  try {
    const payload = {
      language: form.value.language,
      text: form.value.text.trim(),
      enabled: form.value.enabled,
      sort_order: form.value.sort_order,
    }
    if (!payload.text) {
      ElMessage.warning('请填写灵感文案')
      return
    }
    if (isCreate.value) {
      await api.post('/admin/theme-sparks', payload)
      ElMessage.success('已创建')
    } else {
      await api.patch(`/admin/theme-sparks/${form.value.id}`, payload)
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

async function toggleEnabled(row: ThemeSparkRow, enabled: string | number | boolean) {
  try {
    await api.patch(`/admin/theme-sparks/${row.id}`, { enabled: Boolean(enabled) })
    await load()
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '更新失败')
    await load()
  }
}

async function remove(row: ThemeSparkRow) {
  try {
    await ElMessageBox.confirm(`删除灵感「${row.text}」？`, '确认删除', {
      type: 'warning',
    })
  } catch {
    return
  }
  try {
    await api.delete(`/admin/theme-sparks/${row.id}`)
    ElMessage.success('已删除')
    await load()
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '删除失败')
  }
}

async function seedDefaults() {
  try {
    const { data } = await api.post<{ inserted: number; already_present: boolean }>(
      '/admin/theme-sparks/seed',
    )
    if (data.already_present) {
      ElMessage.info('库中已有数据，未覆盖')
    } else {
      ElMessage.success(`已写入 ${data.inserted} 条默认灵感`)
    }
    await load()
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '种子写入失败')
  }
}

onMounted(load)
</script>

<template>
  <div>
    <div class="toolbar">
      <h2>灵感火花</h2>
      <div class="actions">
        <el-select
          v-model="filterLang"
          clearable
          placeholder="语言"
          style="width: 120px"
          @change="load"
        >
          <el-option label="中文" value="zh" />
          <el-option label="English" value="en" />
        </el-select>
        <el-button @click="seedDefaults">写入默认</el-button>
        <el-button type="primary" @click="openCreate">新建</el-button>
      </div>
    </div>
    <p class="hint">
      创作页「一句话灵感」hint 里的例子从此表下发到客户端本地池；空表启动时会自动种子。请写主题/情绪短句，不要写完整情节。
    </p>
    <el-table v-loading="loading" :data="items" stripe>
      <el-table-column prop="id" label="ID" width="80" />
      <el-table-column prop="language" label="语言" width="90" />
      <el-table-column prop="text" label="文案" min-width="220" />
      <el-table-column prop="sort_order" label="排序" width="90" />
      <el-table-column label="启用" width="90">
        <template #default="{ row }">
          <el-switch
            :model-value="row.enabled"
            @change="(v: string | number | boolean) => toggleEnabled(row, v)"
          />
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
      :title="isCreate ? '新建灵感火花' : '编辑灵感火花'"
      width="480px"
    >
      <el-form label-width="80px">
        <el-form-item label="语言">
          <el-select v-model="form.language" style="width: 160px">
            <el-option label="中文" value="zh" />
            <el-option label="English" value="en" />
          </el-select>
        </el-form-item>
        <el-form-item label="文案">
          <el-input v-model="form.text" maxlength="64" show-word-limit placeholder="例如：我不想睡觉" />
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
  gap: 12px;
  margin-bottom: 8px;
}
.toolbar h2 {
  margin: 0;
  font-size: 20px;
}
.actions {
  display: flex;
  gap: 8px;
  align-items: center;
}
.hint {
  color: var(--el-text-color-secondary);
  font-size: 13px;
  margin: 0 0 16px;
  line-height: 1.5;
}
</style>

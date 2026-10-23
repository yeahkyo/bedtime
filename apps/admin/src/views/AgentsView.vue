<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { api } from '@/api/client'
import { formatAdminTime } from '@/utils/datetime'

export interface Placeholder {
  name: string
  description: string
}

export interface LlmAgent {
  id: string
  label_zh: string
  description: string
  provider: string | null
  model: string | null
  system_prompt: string
  user_prompt_template: string
  max_tokens: number | null
  timeout_seconds: number | null
  temperature: number | null
  placeholders: Placeholder[]
  enabled: boolean
  updated_at: string | null
}

const loading = ref(false)
const saving = ref(false)
const items = ref<LlmAgent[]>([])
const priorityHint = ref('')
const dialogOpen = ref(false)
const form = ref<LlmAgent | null>(null)
/** Avoid `{{ ... }}` inside Vue mustache (parser closes at first `}}`). */
const placeholderExample = '{{name}}'

function formatPlaceholder(name: string): string {
  return `{{${name}}}`
}

async function load() {
  loading.value = true
  try {
    const { data } = await api.get<{
      items: LlmAgent[]
      total: number
      priority_hint: string
    }>('/admin/llm-agents')
    items.value = data.items
    priorityHint.value = data.priority_hint || ''
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '加载失败')
  } finally {
    loading.value = false
  }
}

function openEdit(row: LlmAgent) {
  form.value = {
    ...row,
    placeholders: [...(row.placeholders || [])],
    system_prompt: row.system_prompt,
    user_prompt_template: row.user_prompt_template,
  }
  dialogOpen.value = true
}

async function save() {
  if (!form.value) return
  saving.value = true
  try {
    const f = form.value
    const provider = (f.provider || '').trim()
    const model = (f.model || '').trim()
    const { data } = await api.patch<LlmAgent>(`/admin/llm-agents/${f.id}`, {
      label_zh: f.label_zh.trim(),
      description: f.description,
      provider: provider || null,
      model: model || null,
      clear_provider: !provider,
      clear_model: !model,
      system_prompt: f.system_prompt,
      user_prompt_template: f.user_prompt_template,
      max_tokens: f.max_tokens,
      timeout_seconds: f.timeout_seconds,
      temperature: f.temperature,
      clear_max_tokens: f.max_tokens == null,
      clear_timeout_seconds: f.timeout_seconds == null,
      clear_temperature: f.temperature == null,
      enabled: f.enabled,
    })
    const idx = items.value.findIndex((x) => x.id === data.id)
    if (idx >= 0) items.value[idx] = data
    form.value = data
    ElMessage.success('已保存')
    dialogOpen.value = false
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '保存失败')
  } finally {
    saving.value = false
  }
}

async function resetToDefault() {
  if (!form.value) return
  try {
    await ElMessageBox.confirm(
      `将「${form.value.label_zh}」恢复为代码默认 prompt / 参数？运营修改会丢失。`,
      '恢复默认',
      { type: 'warning' },
    )
  } catch {
    return
  }
  saving.value = true
  try {
    const { data } = await api.post<LlmAgent>(`/admin/llm-agents/${form.value.id}/reset`)
    const idx = items.value.findIndex((x) => x.id === data.id)
    if (idx >= 0) items.value[idx] = data
    form.value = data
    ElMessage.success('已恢复代码默认')
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '恢复失败')
  } finally {
    saving.value = false
  }
}

onMounted(load)
</script>

<template>
  <div v-loading="loading">
    <h2>LLM Agents</h2>
    <p class="hint">
      配置故事流水线与目录编撰的 system / user 模板。占位符语法
      <code>{{ placeholderExample }}</code>。优先级：{{ priorityHint || '调用方覆盖 > Agent 配置 > 全局/env' }}。
      全局默认 Provider 仍在「Provider 设置」。禁用 Agent 时运行时强制用代码 fallback。
    </p>
    <el-table :data="items" stripe style="width: 100%">
      <el-table-column prop="id" label="ID" min-width="160" />
      <el-table-column prop="label_zh" label="职责" min-width="120" />
      <el-table-column label="Provider" width="110">
        <template #default="{ row }">{{ row.provider || '—' }}</template>
      </el-table-column>
      <el-table-column label="Model" min-width="140">
        <template #default="{ row }">{{ row.model || '—' }}</template>
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
      <el-table-column label="操作" width="100" fixed="right">
        <template #default="{ row }">
          <el-button type="primary" link @click="openEdit(row)">编辑</el-button>
        </template>
      </el-table-column>
    </el-table>

    <el-dialog
      v-model="dialogOpen"
      :title="form ? `编辑 · ${form.label_zh}` : '编辑'"
      width="820px"
      destroy-on-close
    >
      <template v-if="form">
        <p class="desc">{{ form.description }}</p>
        <el-form label-width="120px">
          <el-form-item label="启用">
            <el-switch v-model="form.enabled" />
            <span class="field-hint">关闭后运行时用代码默认，不读本行 prompt</span>
          </el-form-item>
          <el-form-item label="Provider">
            <el-input
              v-model="form.provider"
              placeholder="空 = 用 Provider 设置页；填写则本阶段覆盖"
              clearable
            />
          </el-form-item>
          <el-form-item label="Model">
            <el-input
              v-model="form.model"
              placeholder="空 = 用全局/该 provider 默认；填写则本阶段覆盖"
              clearable
            />
          </el-form-item>
          <el-form-item label="max_tokens">
            <el-input-number v-model="form.max_tokens" :min="1" :max="128000" :controls="true" />
            <el-button
              v-if="form.max_tokens != null"
              link
              type="info"
              style="margin-left: 8px"
              @click="form.max_tokens = null"
            >
              清空（代码默认）
            </el-button>
          </el-form-item>
          <el-form-item label="timeout (s)">
            <el-input-number
              v-model="form.timeout_seconds"
              :min="1"
              :max="3600"
              :controls="true"
            />
            <el-button
              v-if="form.timeout_seconds != null"
              link
              type="info"
              style="margin-left: 8px"
              @click="form.timeout_seconds = null"
            >
              清空（代码默认）
            </el-button>
          </el-form-item>
          <el-form-item label="temperature">
            <el-input-number
              v-model="form.temperature"
              :min="0"
              :max="2"
              :step="0.1"
              :precision="2"
              :controls="true"
            />
            <el-button
              v-if="form.temperature != null"
              link
              type="info"
              style="margin-left: 8px"
              @click="form.temperature = null"
            >
              清空（默认 0.7）
            </el-button>
            <span class="field-hint">空则请求用 0.7</span>
          </el-form-item>
          <el-form-item label="System">
            <el-input
              v-model="form.system_prompt"
              type="textarea"
              :rows="12"
              class="mono"
            />
          </el-form-item>
          <el-form-item label="User 模板">
            <el-input
              v-model="form.user_prompt_template"
              type="textarea"
              :rows="4"
              class="mono"
            />
          </el-form-item>
          <el-form-item label="可用变量">
            <p class="field-hint" style="margin: 0 0 6px; margin-left: 0">
              只读说明：可在上方 System / User 模板中书写的占位符；运行时由代码替换，保存表单不会提交此项。
            </p>
            <ul class="placeholders">
              <li v-for="p in form.placeholders" :key="p.name">
                <code>{{ formatPlaceholder(p.name) }}</code>
                — {{ p.description }}
              </li>
            </ul>
          </el-form-item>
        </el-form>
      </template>
      <template #footer>
        <el-button :disabled="saving" @click="resetToDefault">恢复代码默认</el-button>
        <el-button @click="dialogOpen = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="save">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.hint {
  color: var(--el-text-color-secondary);
  margin: 0 0 16px;
  max-width: 720px;
  line-height: 1.5;
}
.desc {
  color: var(--el-text-color-secondary);
  margin: 0 0 12px;
}
.field-hint {
  margin-left: 12px;
  color: var(--el-text-color-secondary);
  font-size: 12px;
}
.placeholders {
  margin: 0;
  padding-left: 18px;
  color: var(--el-text-color-regular);
  line-height: 1.7;
}
.mono :deep(textarea) {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 12px;
}
</style>

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

interface VersionSummary {
  version: number
  note: string
  source: string
  created_by: string
  created_at: string | null
  system_prompt_preview: string
  temperature: number | null
  max_tokens: number | null
  timeout_seconds: number | null
}

interface VersionDetail {
  agent_id: string
  version: number
  note: string
  source: string
  created_by: string
  created_at: string | null
  system_prompt: string
  user_prompt_template: string
  temperature: number | null
  max_tokens: number | null
  timeout_seconds: number | null
}

const SOURCE_LABEL: Record<string, string> = {
  admin_save: 'Admin 保存',
  lab_save: '试验台',
  restore: '回滚',
  reset_code: '代码默认',
}

const loading = ref(false)
const saving = ref(false)
const items = ref<LlmAgent[]>([])
const priorityHint = ref('')
const dialogOpen = ref(false)
const form = ref<LlmAgent | null>(null)
const versionNote = ref('')
/** Avoid `{{ ... }}` inside Vue mustache (parser closes at first `}}`). */
const placeholderExample = '{{name}}'

const historyOpen = ref(false)
const historyLoading = ref(false)
const versions = ref<VersionSummary[]>([])
const viewOpen = ref(false)
const viewDetail = ref<VersionDetail | null>(null)
const compareOpen = ref(false)
const compareDetail = ref<VersionDetail | null>(null)
const restoring = ref(false)

function formatPlaceholder(name: string): string {
  return `{{${name}}}`
}

function sourceLabel(source: string): string {
  return SOURCE_LABEL[source] || source
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
  versionNote.value = ''
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
      version_note: versionNote.value.trim() || null,
    })
    const idx = items.value.findIndex((x) => x.id === data.id)
    if (idx >= 0) items.value[idx] = data
    form.value = data
    versionNote.value = ''
    ElMessage.success('已保存（新版本已记录）')
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
      `将「${form.value.label_zh}」恢复为代码默认 prompt / 参数？会新增一版 reset_code 记录。`,
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

async function openHistory() {
  if (!form.value) return
  historyOpen.value = true
  historyLoading.value = true
  versions.value = []
  try {
    const { data } = await api.get<{ items: VersionSummary[]; total: number }>(
      `/admin/llm-agents/${form.value.id}/versions`,
    )
    versions.value = data.items
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '加载版本失败')
  } finally {
    historyLoading.value = false
  }
}

async function viewVersion(v: VersionSummary) {
  if (!form.value) return
  try {
    const { data } = await api.get<VersionDetail>(
      `/admin/llm-agents/${form.value.id}/versions/${v.version}`,
    )
    viewDetail.value = data
    viewOpen.value = true
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '加载版本详情失败')
  }
}

async function compareVersion(v: VersionSummary) {
  if (!form.value) return
  try {
    const { data } = await api.get<VersionDetail>(
      `/admin/llm-agents/${form.value.id}/versions/${v.version}`,
    )
    compareDetail.value = data
    compareOpen.value = true
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '加载版本失败')
  }
}

async function restoreVersion(v: VersionSummary) {
  if (!form.value) return
  try {
    await ElMessageBox.confirm(
      `将 v${v.version} 写回当前生效 Agent，并新增一版 restore 审计记录？`,
      '回滚版本',
      { type: 'warning' },
    )
  } catch {
    return
  }
  restoring.value = true
  try {
    const { data } = await api.post<LlmAgent>(
      `/admin/llm-agents/${form.value.id}/versions/${v.version}/restore`,
      { note: `回滚至 v${v.version}` },
    )
    const idx = items.value.findIndex((x) => x.id === data.id)
    if (idx >= 0) items.value[idx] = data
    form.value = data
    ElMessage.success(`已回滚至 v${v.version}`)
    await openHistory()
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '回滚失败')
  } finally {
    restoring.value = false
  }
}

onMounted(load)
</script>

<template>
  <div v-loading="loading">
    <h2>LLM Agents</h2>
    <p class="hint">
      配置故事流水线与目录编撰的 system / user 模板。占位符语法
      <code>{{ placeholderExample }}</code>。优先级：{{
        priorityHint || 'force > Agent > 路由 > 注册表 > env'
      }}。
      某阶段要走「LLM 路由」时，请将该 Agent 的 Provider/Model
      <strong>留空</strong>。全局强制模型在「Provider 设置」；实例在「LLM 模型」，条件绑定在「LLM
      路由」。禁用 Agent 时用代码 fallback prompt。每次保存会自动落一版历史。
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
              placeholder="空 = 走路由/注册表/env；填写则本阶段钉死"
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
          <el-form-item label="版本备注">
            <el-input
              v-model="versionNote"
              maxlength="256"
              show-word-limit
              placeholder="可选，如「去掉叠词软软」"
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
        <el-button :disabled="saving" @click="openHistory">版本历史</el-button>
        <el-button :disabled="saving" @click="resetToDefault">恢复代码默认</el-button>
        <el-button @click="dialogOpen = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="save">保存</el-button>
      </template>
    </el-dialog>

    <el-drawer v-model="historyOpen" title="版本历史" size="520px" destroy-on-close>
      <div v-loading="historyLoading">
        <el-empty v-if="!versions.length && !historyLoading" description="尚无版本记录" />
        <el-table v-else :data="versions" size="small" stripe>
          <el-table-column prop="version" label="#" width="56" />
          <el-table-column label="来源" width="100">
            <template #default="{ row }">{{ sourceLabel(row.source) }}</template>
          </el-table-column>
          <el-table-column label="备注" min-width="120">
            <template #default="{ row }">{{ row.note || '—' }}</template>
          </el-table-column>
          <el-table-column label="时间" width="150">
            <template #default="{ row }">{{ formatAdminTime(row.created_at) }}</template>
          </el-table-column>
          <el-table-column label="操作" width="160" fixed="right">
            <template #default="{ row }">
              <el-button type="primary" link @click="viewVersion(row)">查看</el-button>
              <el-button type="primary" link @click="compareVersion(row)">对比</el-button>
              <el-button
                type="warning"
                link
                :loading="restoring"
                @click="restoreVersion(row)"
              >
                回滚
              </el-button>
            </template>
          </el-table-column>
        </el-table>
      </div>
    </el-drawer>

    <el-dialog
      v-model="viewOpen"
      :title="viewDetail ? `版本 v${viewDetail.version}` : '版本详情'"
      width="720px"
      destroy-on-close
    >
      <template v-if="viewDetail">
        <p class="desc">
          {{ sourceLabel(viewDetail.source) }}
          · {{ viewDetail.created_by || '—' }}
          · {{ formatAdminTime(viewDetail.created_at) }}
          <template v-if="viewDetail.note"> · {{ viewDetail.note }}</template>
        </p>
        <p class="field-hint" style="margin-left: 0">
          temp={{ viewDetail.temperature ?? '—' }} · max_tokens={{
            viewDetail.max_tokens ?? '—'
          }}
          · timeout={{ viewDetail.timeout_seconds ?? '—' }}
        </p>
        <h4>System</h4>
        <pre class="prompt-block">{{ viewDetail.system_prompt }}</pre>
        <h4>User 模板</h4>
        <pre class="prompt-block">{{ viewDetail.user_prompt_template }}</pre>
      </template>
    </el-dialog>

    <el-dialog
      v-model="compareOpen"
      :title="
        compareDetail && form
          ? `对比 · v${compareDetail.version} vs 当前稿`
          : '对比'
      "
      width="960px"
      destroy-on-close
    >
      <template v-if="compareDetail && form">
        <el-row :gutter="16">
          <el-col :span="12">
            <h4>v{{ compareDetail.version }}</h4>
            <p class="field-hint" style="margin-left: 0">
              temp={{ compareDetail.temperature ?? '—' }} · max={{
                compareDetail.max_tokens ?? '—'
              }}
            </p>
            <h5>System</h5>
            <pre class="prompt-block">{{ compareDetail.system_prompt }}</pre>
            <h5>User</h5>
            <pre class="prompt-block">{{ compareDetail.user_prompt_template }}</pre>
          </el-col>
          <el-col :span="12">
            <h4>当前稿</h4>
            <p class="field-hint" style="margin-left: 0">
              temp={{ form.temperature ?? '—' }} · max={{ form.max_tokens ?? '—' }}
            </p>
            <h5>System</h5>
            <pre class="prompt-block">{{ form.system_prompt }}</pre>
            <h5>User</h5>
            <pre class="prompt-block">{{ form.user_prompt_template }}</pre>
          </el-col>
        </el-row>
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
.prompt-block {
  margin: 0 0 12px;
  padding: 10px 12px;
  background: var(--el-fill-color-light);
  border-radius: 6px;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 12px;
  line-height: 1.45;
  white-space: pre-wrap;
  word-break: break-word;
  max-height: 40vh;
  overflow: auto;
}
h4,
h5 {
  margin: 8px 0 6px;
  font-weight: 600;
}
</style>

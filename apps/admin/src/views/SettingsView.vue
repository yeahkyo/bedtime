<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { api } from '@/api/client'
import type { ProvidersSettingsOut } from '@/api/types'

const loading = ref(false)
const saving = ref(false)
const data = ref<ProvidersSettingsOut | null>(null)
const storyProvider = ref('')
const speechProvider = ref('')
const storyModel = ref('')
const speechModel = ref('')

const storyEnvModel = computed(() => {
  const p = data.value?.available.story_providers.find((x) => x.id === storyProvider.value)
  return p?.env_model || data.value?.env_story_model || ''
})

const speechEnvModel = computed(() => {
  const p = data.value?.available.speech_providers.find((x) => x.id === speechProvider.value)
  return p?.env_model || data.value?.env_speech_model || ''
})

watch(storyProvider, (next, prev) => {
  if (!data.value || !prev || next === prev) return
  // Switching provider: snap model to that provider's env default.
  storyModel.value = storyEnvModel.value
})

watch(speechProvider, (next, prev) => {
  if (!data.value || !prev || next === prev) return
  speechModel.value = speechEnvModel.value
})

async function load() {
  loading.value = true
  try {
    const res = await api.get<ProvidersSettingsOut>('/admin/settings/providers')
    data.value = res.data
    storyProvider.value = res.data.story_provider
    speechProvider.value = res.data.speech_provider
    storyModel.value = res.data.story_model
    speechModel.value = res.data.speech_model
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '加载失败')
  } finally {
    loading.value = false
  }
}

async function save() {
  saving.value = true
  try {
    const res = await api.patch<ProvidersSettingsOut>('/admin/settings/providers', {
      story_provider: storyProvider.value,
      speech_provider: speechProvider.value,
      story_model: storyModel.value.trim(),
      speech_model: speechModel.value.trim(),
    })
    data.value = res.data
    storyModel.value = res.data.story_model
    speechModel.value = res.data.speech_model
    ElMessage.success('已保存运行时默认 Provider / 模型')
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '保存失败')
  } finally {
    saving.value = false
  }
}

onMounted(load)
</script>

<template>
  <div v-loading="loading">
    <h2>Provider 设置</h2>
    <p class="hint">
      运行时覆盖写入 Redis，优先于环境变量。模型请直接填写服务商 id（无固定列表）。
      App 创建故事不暴露选择器；语音供应商与模型优先看所选音色的
      <code>Voice.provider</code> / <code>Voice.speech_model</code>（可在「音色」页管理）。
      本页 Speech Model 仅作音色未设置 model 时的全局回退。
      Agent 行上若填写了 provider / model，该阶段会覆盖本页全局配置。
    </p>
    <template v-if="data">
      <el-form label-width="140px" style="max-width: 560px">
        <el-form-item label="Story Provider">
          <el-select v-model="storyProvider" style="width: 280px">
            <el-option
              v-for="p in data.available.story_providers"
              :key="p.id"
              :label="`${p.id}${p.configured ? '' : ' (未配置 key)'}`"
              :value="p.id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="Story Model">
          <el-input
            v-model="storyModel"
            clearable
            style="width: 280px"
            placeholder="如 doubao-seed-1.6-250615"
          />
          <div class="field-hint">Env 默认：{{ storyEnvModel || '—' }}</div>
        </el-form-item>
        <el-form-item label="Speech Provider">
          <el-select v-model="speechProvider" style="width: 280px">
            <el-option
              v-for="p in data.available.speech_providers"
              :key="p.id"
              :label="`${p.id}${p.configured ? '' : ' (未配置 key)'}`"
              :value="p.id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="Speech Model">
          <el-input
            v-model="speechModel"
            clearable
            style="width: 280px"
            placeholder="如 s2-pro / seed-tts-2.0"
          />
          <div class="field-hint">
            Env 默认：{{ speechEnvModel || '—' }}
            <span v-if="speechProvider === 'volc'">（Volc 填 resource id）</span>
          </div>
        </el-form-item>
        <el-form-item label="Env 默认">
          <span
            >{{ data.env_story_provider }} / {{ data.env_story_model }} ·
            {{ data.env_speech_provider }} / {{ data.env_speech_model }}</span
          >
        </el-form-item>
        <el-form-item label="当前覆盖">
          <span>{{ Object.keys(data.overrides).length ? JSON.stringify(data.overrides) : '无' }}</span>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :loading="saving" @click="save">保存</el-button>
          <el-button @click="load">刷新</el-button>
        </el-form-item>
      </el-form>
    </template>
  </div>
</template>

<style scoped>
.hint {
  color: #606266;
  max-width: 640px;
  line-height: 1.6;
}
.field-hint {
  margin-top: 4px;
  font-size: 12px;
  color: #909399;
  line-height: 1.4;
}
</style>

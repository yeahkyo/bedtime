<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { api } from '@/api/client'
import type { ProvidersSettingsOut } from '@/api/types'

const loading = ref(false)
const saving = ref(false)
const data = ref<ProvidersSettingsOut | null>(null)
const storyProvider = ref('')
const storyModel = ref('')

const storyEnvModel = computed(() => {
  const p = data.value?.available.story_providers.find((x) => x.id === storyProvider.value)
  return p?.env_model || data.value?.env_story_model || ''
})

watch(storyProvider, (next, prev) => {
  if (!data.value || !prev || next === prev) return
  // Switching provider: snap model to that provider's env default.
  storyModel.value = storyEnvModel.value
})

async function load() {
  loading.value = true
  try {
    const res = await api.get<ProvidersSettingsOut>('/admin/settings/providers')
    data.value = res.data
    storyProvider.value = res.data.story_provider
    // Only show Redis force override; empty = routing/env applies.
    storyModel.value = res.data.overrides?.story_model || ''
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
      story_model: storyModel.value.trim(),
    })
    data.value = res.data
    storyModel.value = res.data.overrides?.story_model || ''
    ElMessage.success('已保存运行时 Story Provider / 强制模型')
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
      运行时覆盖写入 Redis。Story Model 留空则走「LLM 路由」+「LLM 模型」注册表（再回退
      env）；填写则为全站强制钉死（kill-switch，优先级最高）。日常分档请用 LLM 路由，勿在此填
      模型。TTS 看音色页的 <code>Voice.provider</code> /
      <code>speech_model</code>。Agent 显式 model 亦会覆盖路由。
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
        <el-form-item label="强制 Story Model">
          <el-input
            v-model="storyModel"
            clearable
            style="width: 280px"
            placeholder="空 = 不强制，走路由/注册表/env"
          />
          <div class="field-hint">Env 默认：{{ storyEnvModel || '—' }}</div>
        </el-form-item>
        <el-form-item label="Env 默认">
          <span>{{ data.env_story_provider }} / {{ data.env_story_model }}</span>
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
  color: var(--el-text-color-secondary);
  margin-bottom: 16px;
  max-width: 640px;
  line-height: 1.5;
}
.field-hint {
  margin-top: 4px;
  font-size: 12px;
  color: var(--el-text-color-secondary);
}
</style>

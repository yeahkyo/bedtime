<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { api } from '@/api/client'
import type { ProvidersSettingsOut } from '@/api/types'

const loading = ref(false)
const saving = ref(false)
const data = ref<ProvidersSettingsOut | null>(null)
const storyProvider = ref('')
const speechProvider = ref('')

async function load() {
  loading.value = true
  try {
    const res = await api.get<ProvidersSettingsOut>('/admin/settings/providers')
    data.value = res.data
    storyProvider.value = res.data.story_provider
    speechProvider.value = res.data.speech_provider
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
    })
    data.value = res.data
    ElMessage.success('已保存运行时默认 Provider')
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
      运行时覆盖写入 Redis，优先于环境变量。App 创建故事不暴露选择器，一律走此处默认值；
      语音由所选音色的 <code>Voice.provider</code> 决定。
    </p>
    <template v-if="data">
      <el-form label-width="140px" style="max-width: 520px">
        <el-form-item label="Story Provider">
          <el-select v-model="storyProvider" style="width: 240px">
            <el-option
              v-for="p in data.available.story_providers"
              :key="p.id"
              :label="`${p.id}${p.configured ? '' : ' (未配置 key)'}`"
              :value="p.id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="Speech Provider">
          <el-select v-model="speechProvider" style="width: 240px">
            <el-option
              v-for="p in data.available.speech_providers"
              :key="p.id"
              :label="`${p.id}${p.configured ? '' : ' (未配置 key)'}`"
              :value="p.id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="Env 默认">
          <span>{{ data.env_story_provider }} / {{ data.env_speech_provider }}</span>
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
</style>

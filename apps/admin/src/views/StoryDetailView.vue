<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { api } from '@/api/client'
import type { AdminStoryDetailOut } from '@/api/types'
import { formatAdminTime } from '@/utils/datetime'

const route = useRoute()
const router = useRouter()
const loading = ref(false)
const story = ref<AdminStoryDetailOut | null>(null)

function prettyJson(raw: string | null | undefined): string {
  if (!raw) return ''
  try {
    return JSON.stringify(JSON.parse(raw), null, 2)
  } catch {
    return raw
  }
}

const episodePlanPretty = computed(() => prettyJson(story.value?.episode_plan_json))
const paramsPretty = computed(() => prettyJson(story.value?.params_json))

const planHighlights = computed(() => {
  const raw = story.value?.episode_plan_json
  if (!raw) return null
  try {
    const p = JSON.parse(raw) as Record<string, unknown>
    const pick = (k: string) => {
      const v = p[k]
      return typeof v === 'string' && v.trim() ? v.trim() : null
    }
    return {
      wish: pick('wish'),
      snag: pick('snag'),
      try_1: pick('try_1'),
      try_2: pick('try_2'),
      turn_ok: pick('turn_ok'),
      sleep_beat: pick('sleep_beat'),
      opening_lines: pick('opening_lines'),
      title_hint: pick('title_hint'),
      soft_hook_hint: pick('soft_hook_hint'),
    }
  } catch {
    return null
  }
})

async function load() {
  loading.value = true
  try {
    const { data } = await api.get<AdminStoryDetailOut>(`/admin/stories/${route.params.id}`)
    story.value = data
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '加载失败')
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<template>
  <div v-loading="loading">
    <el-page-header @back="router.push('/stories')">
      <template #content>
        <span>故事 #{{ story?.id }}</span>
      </template>
    </el-page-header>
    <template v-if="story">
      <el-descriptions :column="2" border class="block">
        <el-descriptions-item label="标题">{{ story.title || '—' }}</el-descriptions-item>
        <el-descriptions-item label="状态">{{ story.status }} / {{ story.progress || '—' }}</el-descriptions-item>
        <el-descriptions-item label="Story Provider">
          <el-tag>{{ story.story_provider || '—' }}</el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="Speech Provider">
          <el-tag type="success">{{ story.speech_provider || '—' }}</el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="用户">
          <el-button link type="primary" @click="router.push(`/users/${story.user_id}`)">
            #{{ story.user_id }} {{ story.user_display_name || '' }}
          </el-button>
        </el-descriptions-item>
        <el-descriptions-item label="音色">
          {{ story.voice_name || '—' }} (#{{ story.voice_id ?? '—' }})
        </el-descriptions-item>
        <el-descriptions-item label="语言 / 时长">
          {{ story.language }} · {{ story.duration_minutes }} 分
        </el-descriptions-item>
        <el-descriptions-item label="创建时间">{{ formatAdminTime(story.created_at) }}</el-descriptions-item>
        <el-descriptions-item label="主题" :span="2">{{ story.theme || '—' }}</el-descriptions-item>
        <el-descriptions-item v-if="story.error_message" label="错误" :span="2">
          <span class="err">{{ story.error_message }}</span>
        </el-descriptions-item>
      </el-descriptions>

      <div v-if="story.audio_url" class="audio">
        <h3>音频</h3>
        <audio :src="story.audio_url" controls style="width: 100%" />
      </div>

      <h3>正文</h3>
      <el-input :model-value="story.body" type="textarea" :rows="16" readonly />

      <h3>Episode Plan</h3>
      <template v-if="episodePlanPretty">
        <el-descriptions v-if="planHighlights" :column="1" border size="small" class="plan-hi">
          <el-descriptions-item v-if="planHighlights.title_hint" label="title_hint">
            {{ planHighlights.title_hint }}
          </el-descriptions-item>
          <el-descriptions-item v-if="planHighlights.opening_lines" label="opening_lines">
            {{ planHighlights.opening_lines }}
          </el-descriptions-item>
          <el-descriptions-item v-if="planHighlights.wish" label="wish">{{ planHighlights.wish }}</el-descriptions-item>
          <el-descriptions-item v-if="planHighlights.snag" label="snag">{{ planHighlights.snag }}</el-descriptions-item>
          <el-descriptions-item v-if="planHighlights.try_1" label="try_1">{{ planHighlights.try_1 }}</el-descriptions-item>
          <el-descriptions-item v-if="planHighlights.try_2" label="try_2">{{ planHighlights.try_2 }}</el-descriptions-item>
          <el-descriptions-item v-if="planHighlights.turn_ok" label="turn_ok">
            {{ planHighlights.turn_ok }}
          </el-descriptions-item>
          <el-descriptions-item v-if="planHighlights.sleep_beat" label="sleep_beat">
            {{ planHighlights.sleep_beat }}
          </el-descriptions-item>
          <el-descriptions-item v-if="planHighlights.soft_hook_hint" label="soft_hook_hint">
            {{ planHighlights.soft_hook_hint }}
          </el-descriptions-item>
        </el-descriptions>
        <el-collapse>
          <el-collapse-item title="完整 episode_plan JSON" name="plan">
            <pre class="json">{{ episodePlanPretty }}</pre>
          </el-collapse-item>
        </el-collapse>
      </template>
      <p v-else class="muted">本故事无 plan 快照（旧数据或生成失败于 plan 之前）。</p>

      <h3>创建参数</h3>
      <el-collapse v-if="paramsPretty">
        <el-collapse-item title="params_json" name="params">
          <pre class="json">{{ paramsPretty }}</pre>
        </el-collapse-item>
      </el-collapse>
      <p v-else class="muted">无 params</p>
    </template>
  </div>
</template>

<style scoped>
.block {
  margin: 16px 0 24px;
}
.err {
  color: #c45656;
}
.audio {
  margin-bottom: 16px;
}
h3 {
  margin: 16px 0 8px;
}
.plan-hi {
  margin-bottom: 12px;
}
.json {
  margin: 0;
  padding: 12px;
  background: #f5f7fa;
  border-radius: 6px;
  font-size: 12px;
  line-height: 1.45;
  overflow: auto;
  max-height: 420px;
  white-space: pre-wrap;
  word-break: break-word;
}
.muted {
  color: var(--el-text-color-secondary);
  font-size: 13px;
}
</style>

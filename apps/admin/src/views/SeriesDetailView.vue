<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { api } from '@/api/client'
import type { AdminSeriesDetailOut } from '@/api/types'
import { formatAdminTime } from '@/utils/datetime'

const route = useRoute()
const router = useRouter()
const loading = ref(false)
const series = ref<AdminSeriesDetailOut | null>(null)

function prettyJson(raw: string | null | undefined): string {
  if (!raw) return ''
  try {
    return JSON.stringify(JSON.parse(raw), null, 2)
  } catch {
    return raw
  }
}

const outlinePretty = computed(() => prettyJson(series.value?.outline_json))

const castRows = computed(() => {
  const spine = series.value?.cast_spine
  if (!Array.isArray(spine)) return []
  return spine.map((item, idx) => {
    if (typeof item === 'string') {
      return { name: item, move: '—', catchphrase: '—' }
    }
    if (item && typeof item === 'object') {
      const o = item as Record<string, unknown>
      return {
        name: String(o.name ?? `角色${idx + 1}`),
        move: String(o.move ?? '—'),
        catchphrase: String(o.line ?? o.catchphrase ?? '—'),
      }
    }
    return { name: String(item), move: '—', catchphrase: '—' }
  })
})

const episodeRows = computed(() => {
  const eps = series.value?.episodes
  if (!Array.isArray(eps)) return []
  return eps.map((ep) => {
    const o = (ep && typeof ep === 'object' ? ep : {}) as Record<string, unknown>
    return {
      episode_no: o.ep ?? o.episode_no ?? '—',
      focus_id: o.focus ?? o.focus_id ?? '—',
      premise: o.premise ?? '—',
      soft_promise: o.hook ?? o.soft_promise ?? '—',
      focus_how: o.how ?? o.focus_how ?? '',
      sleep_note: o.sleep ?? o.sleep_note ?? '',
    }
  })
})

async function load() {
  loading.value = true
  try {
    const { data } = await api.get<AdminSeriesDetailOut>(
      `/admin/story-series/${route.params.id}`,
    )
    series.value = data
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
    <el-page-header @back="router.push('/series')">
      <template #content>
        <span>系列 #{{ series?.id }}</span>
      </template>
    </el-page-header>
    <template v-if="series">
      <el-descriptions :column="2" border class="block">
        <el-descriptions-item label="标题">{{ series.title || '—' }}</el-descriptions-item>
        <el-descriptions-item label="状态">{{ series.status }}</el-descriptions-item>
        <el-descriptions-item label="主线 throughline" :span="2">
          {{ series.throughline || '—' }}
        </el-descriptions-item>
        <el-descriptions-item label="主题">{{ series.theme || '—' }}</el-descriptions-item>
        <el-descriptions-item label="计划集数">{{ series.episode_count }}</el-descriptions-item>
        <el-descriptions-item label="用户">
          <el-button link type="primary" @click="router.push(`/users/${series.user_id}`)">
            #{{ series.user_id }} {{ series.user_display_name || '' }}
          </el-button>
        </el-descriptions-item>
        <el-descriptions-item label="孩子">
          {{ series.child_nickname || '—' }}
          <span v-if="series.child_id"> (#{{ series.child_id }})</span>
        </el-descriptions-item>
        <el-descriptions-item label="创建时间">
          {{ formatAdminTime(series.created_at) }}
        </el-descriptions-item>
        <el-descriptions-item label="语言">{{ series.language }}</el-descriptions-item>
      </el-descriptions>

      <h3>角色脊骨 cast_spine</h3>
      <el-table v-if="castRows.length" :data="castRows" size="small" stripe border class="block">
        <el-table-column prop="name" label="名字" width="140" />
        <el-table-column prop="move" label="标志动作" min-width="160" />
        <el-table-column prop="catchphrase" label="口头禅" min-width="160" />
      </el-table>
      <p v-else class="muted">无 cast_spine</p>

      <h3>各集梗概 episodes</h3>
      <el-table v-if="episodeRows.length" :data="episodeRows" size="small" stripe border class="block">
        <el-table-column prop="episode_no" label="#" width="60" />
        <el-table-column prop="focus_id" label="focus" width="120" />
        <el-table-column prop="premise" label="premise" min-width="200" show-overflow-tooltip />
        <el-table-column prop="soft_promise" label="soft_promise" min-width="180" show-overflow-tooltip />
      </el-table>
      <p v-else class="muted">大纲中无 episodes 数组</p>

      <h3>已生成故事</h3>
      <el-table
        v-if="series.stories.length"
        :data="series.stories"
        size="small"
        stripe
        class="block"
        @row-click="(row) => router.push(`/stories/${row.story_id}`)"
      >
        <el-table-column prop="episode_no" label="集" width="70" />
        <el-table-column prop="story_id" label="故事 ID" width="100" />
        <el-table-column prop="title" label="标题" min-width="180" show-overflow-tooltip />
        <el-table-column prop="status" label="状态" width="100" />
      </el-table>
      <p v-else class="muted">尚未关联故事</p>

      <el-collapse v-if="outlinePretty">
        <el-collapse-item title="完整 outline_json" name="outline">
          <pre class="json">{{ outlinePretty }}</pre>
        </el-collapse-item>
      </el-collapse>
    </template>
  </div>
</template>

<style scoped>
.block {
  margin: 16px 0 20px;
}
h3 {
  margin: 16px 0 8px;
}
.muted {
  color: var(--el-text-color-secondary);
  font-size: 13px;
  margin: 0 0 16px;
}
.json {
  margin: 0;
  padding: 12px;
  background: #f5f7fa;
  border-radius: 6px;
  font-size: 12px;
  line-height: 1.45;
  overflow: auto;
  max-height: 480px;
  white-space: pre-wrap;
  word-break: break-word;
}
</style>

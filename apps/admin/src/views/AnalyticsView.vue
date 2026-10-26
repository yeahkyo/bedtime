<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { api } from '@/api/client'
import type { AnalyticsSummaryOut } from '@/api/types'

function todayIso(): string {
  const d = new Date()
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

function daysAgoIso(n: number): string {
  const d = new Date()
  d.setDate(d.getDate() - n)
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

const loading = ref(false)
const fromDate = ref(daysAgoIso(6))
const toDate = ref(todayIso())
const summary = ref<AnalyticsSummaryOut | null>(null)

const eventLabels: Record<string, string> = {
  register_success: '注册成功',
  login_success: '登录成功',
  app_open: '打开 App',
  create_open: '打开创建页',
  generate_tap: '点击生成',
  story_ready: '故事就绪',
  story_failed: '故事失败',
  player_open: '打开播放器',
  playback_complete: '听完',
  quota_hit: '触达配额',
}

async function load() {
  loading.value = true
  try {
    const { data } = await api.get<AnalyticsSummaryOut>('/admin/analytics/summary', {
      params: { from: fromDate.value, to: toDate.value },
    })
    summary.value = data
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '加载失败')
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<template>
  <div>
    <div class="toolbar">
      <h2>试用分析</h2>
    </div>
    <el-form inline @submit.prevent="load">
      <el-form-item label="从">
        <el-date-picker v-model="fromDate" type="date" value-format="YYYY-MM-DD" />
      </el-form-item>
      <el-form-item label="到">
        <el-date-picker v-model="toDate" type="date" value-format="YYYY-MM-DD" />
      </el-form-item>
      <el-button type="primary" :loading="loading" @click="load">查询</el-button>
    </el-form>

    <template v-if="summary">
      <el-row :gutter="12" class="cards">
        <el-col :xs="12" :sm="8" :md="6">
          <el-card shadow="never">
            <div class="metric-label">注册</div>
            <div class="metric-value">{{ summary.event_counts.register_success ?? 0 }}</div>
          </el-card>
        </el-col>
        <el-col :xs="12" :sm="8" :md="6">
          <el-card shadow="never">
            <div class="metric-label">生成点击</div>
            <div class="metric-value">{{ summary.event_counts.generate_tap ?? 0 }}</div>
          </el-card>
        </el-col>
        <el-col :xs="12" :sm="8" :md="6">
          <el-card shadow="never">
            <div class="metric-label">故事就绪</div>
            <div class="metric-value">{{ summary.event_counts.story_ready ?? 0 }}</div>
          </el-card>
        </el-col>
        <el-col :xs="12" :sm="8" :md="6">
          <el-card shadow="never">
            <div class="metric-label">听完率</div>
            <div class="metric-value">
              {{
                summary.listen_rate == null
                  ? '—'
                  : `${(summary.listen_rate * 100).toFixed(1)}%`
              }}
            </div>
          </el-card>
        </el-col>
      </el-row>

      <h3 class="section-title">事件计数</h3>
      <el-table :data="Object.keys(eventLabels).map((k) => ({ name: k, count: summary.event_counts[k] ?? 0 }))" stripe>
        <el-table-column label="事件" min-width="160">
          <template #default="{ row }">{{ eventLabels[row.name] || row.name }}</template>
        </el-table-column>
        <el-table-column prop="name" label="code" min-width="140" />
        <el-table-column prop="count" label="次数" width="100" />
      </el-table>

      <h3 class="section-title">同窗口故事 status（DB）</h3>
      <el-table
        :data="Object.entries(summary.story_status_counts).map(([status, count]) => ({ status, count }))"
        stripe
        empty-text="无故事"
      >
        <el-table-column prop="status" label="status" min-width="120" />
        <el-table-column prop="count" label="数量" width="100" />
      </el-table>
    </template>
  </div>
</template>

<style scoped>
.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
}
.cards {
  margin: 16px 0 8px;
}
.metric-label {
  color: var(--el-text-color-secondary);
  font-size: 13px;
}
.metric-value {
  font-size: 24px;
  font-weight: 700;
  margin-top: 4px;
}
.section-title {
  margin: 24px 0 12px;
  font-size: 16px;
}
</style>

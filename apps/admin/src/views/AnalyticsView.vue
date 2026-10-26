<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { api } from '@/api/client'
import type { AnalyticsEngagementOut, AnalyticsSummaryOut } from '@/api/types'

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

function pct(rate: number | null | undefined): string {
  if (rate == null) return '—'
  return `${(rate * 100).toFixed(1)}%`
}

function num(n: number | null | undefined, digits = 1): string {
  if (n == null) return '—'
  return n.toFixed(digits)
}

/** Keep in sync with apps/api MAX_ENGAGEMENT_RANGE_DAYS. */
const MAX_RANGE_DAYS = 90

function parseIsoDay(iso: string): Date {
  const [y, m, d] = iso.split('-').map(Number)
  return new Date(y, m - 1, d)
}

function toIsoDay(d: Date): string {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

/** Clamp [from, to] to at most MAX_RANGE_DAYS (inclusive), matching API. */
function clampRange(from: string, to: string): { from: string; to: string; clamped: boolean } {
  let a = parseIsoDay(from)
  let b = parseIsoDay(to)
  if (b < a) {
    const tmp = a
    a = b
    b = tmp
  }
  const span = Math.floor((b.getTime() - a.getTime()) / 86400000) + 1
  if (span <= MAX_RANGE_DAYS) {
    return { from: toIsoDay(a), to: toIsoDay(b), clamped: from !== toIsoDay(a) || to !== toIsoDay(b) }
  }
  const clampedFrom = new Date(b)
  clampedFrom.setDate(clampedFrom.getDate() - (MAX_RANGE_DAYS - 1))
  return { from: toIsoDay(clampedFrom), to: toIsoDay(b), clamped: true }
}

const loading = ref(false)
const fromDate = ref(daysAgoIso(13))
const toDate = ref(todayIso())
const summary = ref<AnalyticsSummaryOut | null>(null)
const engagement = ref<AnalyticsEngagementOut | null>(null)

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
    const range = clampRange(fromDate.value, toDate.value)
    if (range.clamped) {
      fromDate.value = range.from
      toDate.value = range.to
      ElMessage.info(`区间已限制为最近 ${MAX_RANGE_DAYS} 天`)
    }
    const params = { from: range.from, to: range.to }
    const [summaryRes, engagementRes] = await Promise.all([
      api.get<AnalyticsSummaryOut>('/admin/analytics/summary', { params }),
      api.get<AnalyticsEngagementOut>('/admin/analytics/engagement', { params }),
    ])
    summary.value = summaryRes.data
    engagement.value = engagementRes.data
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
    <p class="hint">
      事件汇总与 DAU / 留存共用同一 UTC 日期窗口；活跃 = 当日有任意产品埋点。未到期的 D7/D30
      显示为 —。最长 {{ MAX_RANGE_DAYS }} 天。
    </p>

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
            <div class="metric-value">{{ pct(summary.listen_rate) }}</div>
          </el-card>
        </el-col>
      </el-row>
    </template>

    <template v-if="engagement">
      <h3 class="section-title">活跃与留存</h3>
      <el-row :gutter="12" class="cards">
        <el-col :xs="12" :sm="8" :md="6">
          <el-card shadow="never">
            <div class="metric-label">平均 DAU</div>
            <div class="metric-value">{{ num(engagement.avg_dau, 1) }}</div>
          </el-card>
        </el-col>
        <el-col :xs="12" :sm="8" :md="6">
          <el-card shadow="never">
            <div class="metric-label">平均次日留存</div>
            <div class="metric-value">{{ pct(engagement.avg_d1) }}</div>
          </el-card>
        </el-col>
        <el-col :xs="12" :sm="8" :md="6">
          <el-card shadow="never">
            <div class="metric-label">平均 7 日留存</div>
            <div class="metric-value">{{ pct(engagement.avg_d7) }}</div>
          </el-card>
        </el-col>
        <el-col :xs="12" :sm="8" :md="6">
          <el-card shadow="never">
            <div class="metric-label">平均 30 日留存</div>
            <div class="metric-value">{{ pct(engagement.avg_d30) }}</div>
          </el-card>
        </el-col>
      </el-row>

      <h3 class="section-title">每日 DAU</h3>
      <el-table :data="engagement.dau" stripe max-height="320" empty-text="无活跃">
        <el-table-column prop="date" label="日期" min-width="120" />
        <el-table-column prop="users" label="DAU" width="100" />
      </el-table>

      <h3 class="section-title">按日留存 cohort</h3>
      <el-table :data="engagement.retention" stripe max-height="420" empty-text="无数据">
        <el-table-column prop="cohort_date" label="cohort 日" min-width="120" />
        <el-table-column prop="cohort_size" label="当日活跃" width="100" />
        <el-table-column label="次日" width="90">
          <template #default="{ row }">{{ pct(row.d1) }}</template>
        </el-table-column>
        <el-table-column label="7 日" width="90">
          <template #default="{ row }">{{ pct(row.d7) }}</template>
        </el-table-column>
        <el-table-column label="30 日" width="90">
          <template #default="{ row }">{{ pct(row.d30) }}</template>
        </el-table-column>
      </el-table>
    </template>

    <template v-if="summary">
      <h3 class="section-title">事件计数</h3>
      <el-table
        :data="Object.keys(eventLabels).map((k) => ({ name: k, count: summary.event_counts[k] ?? 0 }))"
        stripe
      >
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
.hint {
  margin: 0 0 8px;
  color: var(--el-text-color-secondary);
  font-size: 13px;
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

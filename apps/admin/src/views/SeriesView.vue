<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { api } from '@/api/client'
import type { AdminSeriesListOut } from '@/api/types'
import { formatAdminTime } from '@/utils/datetime'

const router = useRouter()
const loading = ref(false)
const page = ref(1)
const pageSize = ref(20)
const total = ref(0)
const status = ref('')
const userId = ref('')
const items = ref<AdminSeriesListOut['items']>([])

async function load() {
  loading.value = true
  try {
    const { data } = await api.get<AdminSeriesListOut>('/admin/story-series', {
      params: {
        page: page.value,
        page_size: pageSize.value,
        status: status.value || undefined,
        user_id: userId.value ? Number(userId.value) : undefined,
      },
    })
    items.value = data.items
    total.value = data.total
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '加载失败')
  } finally {
    loading.value = false
  }
}

function search() {
  page.value = 1
  load()
}

onMounted(load)
</script>

<template>
  <div>
    <div class="toolbar">
      <h2>软系列</h2>
    </div>
    <p class="hint">软系列大纲（throughline / cast_spine / 各集 premise）。点击行查看完整构思。</p>
    <el-form inline @submit.prevent="search">
      <el-form-item label="用户 ID">
        <el-input v-model="userId" clearable style="width: 100px" />
      </el-form-item>
      <el-form-item label="状态">
        <el-select v-model="status" clearable placeholder="全部" style="width: 120px">
          <el-option label="active" value="active" />
          <el-option label="completed" value="completed" />
        </el-select>
      </el-form-item>
      <el-button type="primary" @click="search">查询</el-button>
    </el-form>
    <el-table
      v-loading="loading"
      :data="items"
      stripe
      @row-click="(row) => router.push(`/series/${row.id}`)"
    >
      <el-table-column prop="id" label="ID" width="70" />
      <el-table-column prop="title" label="标题" min-width="160" show-overflow-tooltip />
      <el-table-column prop="throughline" label="主线" min-width="200" show-overflow-tooltip />
      <el-table-column prop="status" label="状态" width="100" />
      <el-table-column label="集数" width="90">
        <template #default="{ row }">{{ row.stories_count }} / {{ row.episode_count }}</template>
      </el-table-column>
      <el-table-column label="孩子" width="100">
        <template #default="{ row }">{{ row.child_nickname || '—' }}</template>
      </el-table-column>
      <el-table-column label="用户" min-width="120">
        <template #default="{ row }">
          #{{ row.user_id }} {{ row.user_display_name || '' }}
        </template>
      </el-table-column>
      <el-table-column label="创建时间" min-width="160">
        <template #default="{ row }">{{ formatAdminTime(row.created_at) }}</template>
      </el-table-column>
    </el-table>
    <div class="pager">
      <el-pagination
        v-model:current-page="page"
        v-model:page-size="pageSize"
        layout="total, prev, pager, next"
        :total="total"
        @current-change="load"
      />
    </div>
  </div>
</template>

<style scoped>
.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 8px;
}
.hint {
  color: var(--el-text-color-secondary);
  font-size: 13px;
  margin: 0 0 12px;
}
.pager {
  margin-top: 16px;
  display: flex;
  justify-content: flex-end;
}
</style>

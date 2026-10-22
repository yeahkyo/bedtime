<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { api } from '@/api/client'
import type { AdminUserListOut } from '@/api/types'
import { formatAdminTime } from '@/utils/datetime'

const router = useRouter()
const loading = ref(false)
const page = ref(1)
const pageSize = ref(20)
const total = ref(0)
const q = ref('')
const items = ref<AdminUserListOut['items']>([])

async function load() {
  loading.value = true
  try {
    const { data } = await api.get<AdminUserListOut>('/admin/users', {
      params: { page: page.value, page_size: pageSize.value, q: q.value.trim() || undefined },
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
      <h2>用户</h2>
    </div>
    <el-form inline @submit.prevent="search">
      <el-form-item label="搜索">
        <el-input v-model="q" placeholder="昵称 / 手机 / apple_sub" clearable style="width: 240px" />
      </el-form-item>
      <el-button type="primary" @click="search">查询</el-button>
    </el-form>
    <el-table v-loading="loading" :data="items" stripe @row-click="(row) => router.push(`/users/${row.id}`)">
      <el-table-column prop="id" label="ID" width="80" />
      <el-table-column prop="display_name" label="昵称" min-width="120" />
      <el-table-column prop="phone" label="手机" width="120" />
      <el-table-column prop="apple_sub" label="Subject" min-width="160" show-overflow-tooltip />
      <el-table-column label="状态" width="90">
        <template #default="{ row }">{{ row.disabled ? '已禁用' : '正常' }}</template>
      </el-table-column>
      <el-table-column label="配额" min-width="140">
        <template #default="{ row }">
          故事 {{ row.story_used }}/{{ row.story_limit }} · 克隆 {{ row.clone_used }}/{{ row.clone_limit }}
        </template>
      </el-table-column>
      <el-table-column prop="children_count" label="孩子" width="80" />
      <el-table-column prop="stories_count" label="故事数" width="90" />
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
  margin-bottom: 12px;
}
.pager {
  margin-top: 16px;
  display: flex;
  justify-content: flex-end;
}
:deep(.el-table__row) {
  cursor: pointer;
}
</style>

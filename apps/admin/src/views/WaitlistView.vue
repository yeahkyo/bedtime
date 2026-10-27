<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { api } from '@/api/client'
import type { WaitlistLeadOut, WaitlistListOut } from '@/api/types'
import { formatAdminTime } from '@/utils/datetime'

const loading = ref(false)
const page = ref(1)
const pageSize = ref(20)
const total = ref(0)
const items = ref<WaitlistLeadOut[]>([])

async function load() {
  loading.value = true
  try {
    const { data } = await api.get<WaitlistListOut>('/admin/waitlist', {
      params: {
        page: page.value,
        page_size: pageSize.value,
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

function deviceLabel(d: string) {
  return ({ ios: 'iOS', android: 'Android', both: '双系统' } as Record<string, string>)[d] || d
}

onMounted(load)
</script>

<template>
  <div>
    <div class="toolbar">
      <h2>内测留资</h2>
      <el-button @click="load">刷新</el-button>
    </div>

    <el-table v-loading="loading" :data="items" stripe>
      <el-table-column prop="id" label="ID" width="80" />
      <el-table-column prop="email" label="邮箱" min-width="200" />
      <el-table-column label="设备" width="120">
        <template #default="{ row }">{{ deviceLabel(row.device) }}</template>
      </el-table-column>
      <el-table-column prop="note" label="备注" min-width="180" show-overflow-tooltip />
      <el-table-column label="提交时间" width="180">
        <template #default="{ row }">{{ formatAdminTime(row.created_at) }}</template>
      </el-table-column>
      <el-table-column label="更新时间" width="180">
        <template #default="{ row }">{{ formatAdminTime(row.updated_at) }}</template>
      </el-table-column>
    </el-table>

    <div class="pager">
      <el-pagination
        v-model:current-page="page"
        v-model:page-size="pageSize"
        layout="total, prev, pager, next"
        :total="total"
        @current-change="load"
        @size-change="
          () => {
            page = 1
            load()
          }
        "
      />
    </div>
  </div>
</template>

<style scoped>
.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 16px;
}
.toolbar h2 {
  margin: 0;
  font-size: 18px;
}
.pager {
  margin-top: 16px;
  display: flex;
  justify-content: flex-end;
}
</style>

<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { api } from '@/api/client'
import type { AdminStoryListOut } from '@/api/types'
import { formatAdminTime } from '@/utils/datetime'

const route = useRoute()
const router = useRouter()
const loading = ref(false)
const page = ref(1)
const pageSize = ref(20)
const total = ref(0)
const status = ref('')
const storyModel = ref('')
const speechProvider = ref('')
const userId = ref('')
const items = ref<AdminStoryListOut['items']>([])

async function load() {
  loading.value = true
  try {
    const { data } = await api.get<AdminStoryListOut>('/admin/stories', {
      params: {
        page: page.value,
        page_size: pageSize.value,
        status: status.value || undefined,
        story_model: storyModel.value.trim() || undefined,
        speech_provider: speechProvider.value || undefined,
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

onMounted(() => {
  if (route.query.user_id) userId.value = String(route.query.user_id)
  load()
})

watch(
  () => route.query.user_id,
  (v) => {
    userId.value = v ? String(v) : ''
    search()
  },
)
</script>

<template>
  <div>
    <div class="toolbar">
      <h2>故事</h2>
    </div>
    <el-form inline @submit.prevent="search">
      <el-form-item label="用户 ID">
        <el-input v-model="userId" clearable style="width: 100px" />
      </el-form-item>
      <el-form-item label="状态">
        <el-select v-model="status" clearable placeholder="全部" style="width: 120px">
          <el-option label="generating" value="generating" />
          <el-option label="ready" value="ready" />
          <el-option label="failed" value="failed" />
        </el-select>
      </el-form-item>
      <el-form-item label="正文模型">
        <el-input
          v-model="storyModel"
          clearable
          placeholder="story_model 子串"
          style="width: 160px"
        />
      </el-form-item>
      <el-form-item label="语音">
        <el-select v-model="speechProvider" clearable placeholder="全部" style="width: 130px">
          <el-option label="fishaudio" value="fishaudio" />
          <el-option label="volc" value="volc" />
          <el-option label="elevenlabs" value="elevenlabs" />
          <el-option label="aliyun" value="aliyun" />
          <el-option label="mock" value="mock" />
        </el-select>
      </el-form-item>
      <el-button type="primary" @click="search">查询</el-button>
    </el-form>
    <el-table
      v-loading="loading"
      :data="items"
      stripe
      @row-click="(row) => router.push(`/stories/${row.id}`)"
    >
      <el-table-column prop="id" label="ID" width="80" />
      <el-table-column prop="title" label="标题" min-width="160" show-overflow-tooltip />
      <el-table-column prop="status" label="状态" width="100" />
      <el-table-column label="正文模型" min-width="160" show-overflow-tooltip>
        <template #default="{ row }">{{ row.story_model || '—' }}</template>
      </el-table-column>
      <el-table-column label="语音" min-width="160" show-overflow-tooltip>
        <template #default="{ row }">
          <span v-if="row.voice_name">{{ row.voice_name }}</span>
          <span v-else>—</span>
          <span v-if="row.speech_provider" class="muted tiny">
            · {{ row.speech_provider }}{{ row.speech_model ? ` / ${row.speech_model}` : '' }}
          </span>
        </template>
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
  margin-bottom: 12px;
}
.pager {
  margin-top: 16px;
  display: flex;
  justify-content: flex-end;
}
.muted {
  color: var(--el-text-color-secondary);
}
.tiny {
  font-size: 12px;
}
:deep(.el-table__row) {
  cursor: pointer;
}
</style>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { api } from '@/api/client'
import type { AdminQuotaOut, AdminUserDetailOut } from '@/api/types'
import { formatAdminTime } from '@/utils/datetime'

const route = useRoute()
const router = useRouter()
const loading = ref(false)
const resetting = ref(false)
const user = ref<AdminUserDetailOut | null>(null)

async function load() {
  loading.value = true
  try {
    const id = route.params.id
    const { data } = await api.get<AdminUserDetailOut>(`/admin/users/${id}`)
    user.value = data
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '加载失败')
  } finally {
    loading.value = false
  }
}

async function disableUser() {
  if (!user.value) return
  try {
    await ElMessageBox.confirm('禁用后该用户无法登录，现有会话立即失效。确定？', '禁用用户', {
      type: 'warning',
    })
  } catch {
    return
  }
  try {
    const { data } = await api.post<AdminUserDetailOut>(`/admin/users/${user.value.id}/disable`)
    user.value = data
    ElMessage.success('已禁用')
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '操作失败')
  }
}

async function enableUser() {
  if (!user.value) return
  try {
    const { data } = await api.post<AdminUserDetailOut>(`/admin/users/${user.value.id}/enable`)
    user.value = data
    ElMessage.success('已启用')
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '操作失败')
  }
}

async function forceLogout() {
  if (!user.value) return
  try {
    await ElMessageBox.confirm('将吊销该用户全部 refresh token，需重新登录。确定？', '强制下线', {
      type: 'warning',
    })
  } catch {
    return
  }
  try {
    const { data } = await api.post<AdminUserDetailOut>(
      `/admin/users/${user.value.id}/force-logout`,
    )
    user.value = data
    ElMessage.success('已强制下线')
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '操作失败')
  }
}

async function resetQuota(kinds: ('story' | 'clone')[] | null) {
  if (!user.value) return
  const label =
    kinds == null
      ? '故事 + 克隆'
      : kinds.includes('story') && kinds.includes('clone')
        ? '故事 + 克隆'
        : kinds[0] === 'story'
          ? '故事'
          : '克隆'
  try {
    await ElMessageBox.confirm(
      `将清空该用户本月「${label}」配额计数，使其可再次创建。确定？`,
      '重置配额',
      { type: 'warning', confirmButtonText: '重置', cancelButtonText: '取消' },
    )
  } catch {
    return
  }
  resetting.value = true
  try {
    const { data } = await api.post<AdminQuotaOut>(
      `/admin/users/${user.value.id}/quota/reset`,
      kinds ? { kinds } : {},
    )
    user.value.story_used = data.story_used
    user.value.story_limit = data.story_limit
    user.value.clone_used = data.clone_used
    user.value.clone_limit = data.clone_limit
    user.value.quota_month = data.month
    ElMessage.success(`已重置（${data.month}）`)
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '重置失败')
  } finally {
    resetting.value = false
  }
}

onMounted(load)
</script>

<template>
  <div v-loading="loading">
    <el-page-header @back="router.push('/users')">
      <template #content>
        <span>用户 #{{ user?.id }}</span>
      </template>
    </el-page-header>
    <template v-if="user">
      <el-descriptions :column="2" border class="block">
        <el-descriptions-item label="昵称">{{ user.display_name || '—' }}</el-descriptions-item>
        <el-descriptions-item label="语言">{{ user.preferred_language }}</el-descriptions-item>
        <el-descriptions-item label="手机">{{ user.phone || '—' }}</el-descriptions-item>
        <el-descriptions-item label="状态">
          {{ user.disabled_at ? `已禁用（${formatAdminTime(user.disabled_at)}）` : '正常' }}
        </el-descriptions-item>
        <el-descriptions-item label="Subject">{{ user.apple_sub }}</el-descriptions-item>
        <el-descriptions-item label="创建时间">{{ formatAdminTime(user.created_at) }}</el-descriptions-item>
        <el-descriptions-item label="故事配额">
          {{ user.story_used }} / {{ user.story_limit }}
          <span v-if="user.quota_month" class="muted">（{{ user.quota_month }}）</span>
        </el-descriptions-item>
        <el-descriptions-item label="克隆配额">
          {{ user.clone_used }} / {{ user.clone_limit }}
        </el-descriptions-item>
        <el-descriptions-item label="故事总数">{{ user.stories_count }}</el-descriptions-item>
        <el-descriptions-item label="保留月数">{{ user.story_retention_months }}</el-descriptions-item>
      </el-descriptions>

      <div class="quota-actions">
        <el-button type="warning" :loading="resetting" @click="resetQuota(['story'])">
          重置故事配额
        </el-button>
        <el-button :loading="resetting" @click="resetQuota(['clone'])">重置克隆配额</el-button>
        <el-button type="danger" plain :loading="resetting" @click="resetQuota(null)">
          重置全部配额
        </el-button>
        <el-button v-if="!user.disabled_at" type="danger" @click="disableUser">禁用</el-button>
        <el-button v-else type="success" @click="enableUser">启用</el-button>
        <el-button @click="forceLogout">强制下线</el-button>
      </div>

      <h3>孩子</h3>
      <el-table :data="user.children" size="small">
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="nickname" label="昵称" />
        <el-table-column prop="gender" label="性别" width="90" />
        <el-table-column prop="birth_date" label="生日" width="120" />
        <el-table-column prop="age_band" label="年龄档" width="90" />
        <el-table-column prop="intro" label="介绍" min-width="160" show-overflow-tooltip />
      </el-table>

      <h3>音色</h3>
      <el-table :data="user.voices" size="small">
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="name" label="名称" />
        <el-table-column prop="kind" label="类型" width="100" />
        <el-table-column prop="provider" label="Provider" width="120" />
        <el-table-column prop="speech_model" label="Model" min-width="120" show-overflow-tooltip>
          <template #default="{ row }">{{ row.speech_model || '（默认）' }}</template>
        </el-table-column>
        <el-table-column prop="provider_voice_id" label="Voice ID" min-width="140" show-overflow-tooltip />
      </el-table>

      <div class="actions">
        <el-button type="primary" @click="router.push({ path: '/stories', query: { user_id: String(user.id) } })">
          查看该用户故事
        </el-button>
        <el-button @click="router.push({ path: '/voices', query: { user_id: String(user.id) } })">
          管理音色
        </el-button>
      </div>
    </template>
  </div>
</template>

<style scoped>
.block {
  margin: 16px 0 24px;
}
h3 {
  margin: 20px 0 8px;
}
.actions {
  margin-top: 20px;
}
.quota-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin: -8px 0 20px;
}
.muted {
  color: var(--el-text-color-secondary);
  margin-left: 6px;
  font-size: 12px;
}
</style>

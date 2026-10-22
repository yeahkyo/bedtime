<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { api } from '@/api/client'
import type { InviteCreateOut, InviteListOut, InviteOut } from '@/api/types'
import { formatAdminTime } from '@/utils/datetime'

const loading = ref(false)
const creating = ref(false)
const page = ref(1)
const pageSize = ref(20)
const total = ref(0)
const status = ref<string>('')
const items = ref<InviteOut[]>([])
const note = ref('')
const count = ref(1)
const expiresInDays = ref(30)

async function load() {
  loading.value = true
  try {
    const { data } = await api.get<InviteListOut>('/admin/invites', {
      params: {
        page: page.value,
        page_size: pageSize.value,
        status: status.value || undefined,
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

async function createInvites() {
  creating.value = true
  try {
    const { data } = await api.post<InviteCreateOut>('/admin/invites', {
      count: count.value,
      note: note.value.trim() || null,
      expires_in_days: expiresInDays.value,
    })
    const codes = data.items.map((x) => x.code).join('\n')
    await ElMessageBox.alert(codes || '（无）', `已生成 ${data.items.length} 个邀请码`, {
      confirmButtonText: '复制关闭',
    })
    try {
      await navigator.clipboard.writeText(codes)
      ElMessage.success('已复制到剪贴板')
    } catch {
      /* ignore */
    }
    note.value = ''
    page.value = 1
    await load()
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '生成失败')
  } finally {
    creating.value = false
  }
}

async function revoke(row: InviteOut) {
  try {
    await ElMessageBox.confirm(`作废邀请码 ${row.code}？`, '确认', { type: 'warning' })
  } catch {
    return
  }
  try {
    await api.post(`/admin/invites/${row.id}/revoke`)
    ElMessage.success('已作废')
    await load()
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '作废失败')
  }
}

function statusLabel(s: string) {
  return (
    { unused: '未使用', used: '已使用', revoked: '已作废', expired: '已过期' } as Record<string, string>
  )[s] || s
}

onMounted(load)
</script>

<template>
  <div>
    <div class="toolbar">
      <h2>邀请码</h2>
    </div>

    <el-card class="gen" shadow="never">
      <el-form inline @submit.prevent="createInvites">
        <el-form-item label="数量">
          <el-input-number v-model="count" :min="1" :max="50" />
        </el-form-item>
        <el-form-item label="有效天数">
          <el-input-number v-model="expiresInDays" :min="1" :max="365" />
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="note" placeholder="可选" clearable style="width: 200px" />
        </el-form-item>
        <el-button type="primary" :loading="creating" @click="createInvites">生成</el-button>
      </el-form>
    </el-card>

    <el-form inline class="filter" @submit.prevent="load">
      <el-form-item label="状态">
        <el-select v-model="status" clearable placeholder="全部" style="width: 140px" @change="() => { page = 1; load() }">
          <el-option label="未使用" value="unused" />
          <el-option label="已使用" value="used" />
          <el-option label="已作废" value="revoked" />
          <el-option label="已过期" value="expired" />
        </el-select>
      </el-form-item>
      <el-button @click="load">刷新</el-button>
    </el-form>

    <el-table v-loading="loading" :data="items" stripe>
      <el-table-column prop="id" label="ID" width="70" />
      <el-table-column prop="code" label="邀请码" min-width="140" />
      <el-table-column label="状态" width="100">
        <template #default="{ row }">{{ statusLabel(row.status) }}</template>
      </el-table-column>
      <el-table-column prop="note" label="备注" min-width="120" show-overflow-tooltip />
      <el-table-column prop="used_by_user_id" label="使用者" width="90" />
      <el-table-column label="过期" min-width="150">
        <template #default="{ row }">{{ formatAdminTime(row.expires_at) }}</template>
      </el-table-column>
      <el-table-column label="创建" min-width="150">
        <template #default="{ row }">{{ formatAdminTime(row.created_at) }}</template>
      </el-table-column>
      <el-table-column label="操作" width="100" fixed="right">
        <template #default="{ row }">
          <el-button
            v-if="row.status === 'unused'"
            link
            type="danger"
            @click="revoke(row)"
          >
            作废
          </el-button>
        </template>
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
.gen {
  margin-bottom: 16px;
}
.filter {
  margin-bottom: 8px;
}
.pager {
  margin-top: 16px;
  display: flex;
  justify-content: flex-end;
}
</style>

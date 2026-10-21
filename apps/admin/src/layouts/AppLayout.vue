<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const active = computed(() => {
  if (route.path.startsWith('/stories')) return '/stories'
  if (route.path.startsWith('/series')) return '/series'
  if (route.path.startsWith('/users')) return '/users'
  if (route.path.startsWith('/settings')) return '/settings'
  if (route.path.startsWith('/shapes') || route.path.startsWith('/beats')) return '/shapes'
  if (route.path.startsWith('/elements')) return '/elements'
  if (route.path.startsWith('/kernels')) return '/kernels'
  if (route.path.startsWith('/agents')) return '/agents'
  if (route.path.startsWith('/voices')) return '/voices'
  return route.path
})

function logout() {
  auth.logout()
  router.push({ name: 'login' })
}
</script>

<template>
  <el-container class="layout">
    <el-aside width="220px" class="aside">
      <div class="brand">Bedtime Admin</div>
      <el-menu :default-active="active" router>
        <el-menu-item index="/users">
          <el-icon><User /></el-icon>
          <span>用户</span>
        </el-menu-item>
        <el-menu-item index="/stories">
          <el-icon><Notebook /></el-icon>
          <span>故事</span>
        </el-menu-item>
        <el-menu-item index="/series">
          <el-icon><Film /></el-icon>
          <span>软系列</span>
        </el-menu-item>
        <el-menu-item index="/shapes">
          <el-icon><Collection /></el-icon>
          <span>故事结构</span>
        </el-menu-item>
        <el-menu-item index="/elements">
          <el-icon><Reading /></el-icon>
          <span>故事元素</span>
        </el-menu-item>
        <el-menu-item index="/kernels">
          <el-icon><Sunny /></el-icon>
          <span>故事内核</span>
        </el-menu-item>
        <el-menu-item index="/agents">
          <el-icon><Cpu /></el-icon>
          <span>LLM Agents</span>
        </el-menu-item>
        <el-menu-item index="/voices">
          <el-icon><Headset /></el-icon>
          <span>音色</span>
        </el-menu-item>
        <el-menu-item index="/settings">
          <el-icon><Setting /></el-icon>
          <span>Provider 设置</span>
        </el-menu-item>
      </el-menu>
    </el-aside>
    <el-container>
      <el-header class="header">
        <span class="muted">运营：{{ auth.operator }}</span>
        <el-button type="danger" link @click="logout">退出</el-button>
      </el-header>
      <el-main>
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<style scoped>
.layout {
  min-height: 100vh;
}
.aside {
  border-right: 1px solid var(--el-border-color);
  background: #fafafa;
}
.brand {
  padding: 20px 16px;
  font-weight: 700;
  font-size: 16px;
}
.header {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 16px;
  border-bottom: 1px solid var(--el-border-color);
}
.muted {
  color: var(--el-text-color-secondary);
}
</style>

import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    { path: '/login', name: 'login', component: () => import('@/views/LoginView.vue') },
    {
      path: '/',
      component: () => import('@/layouts/AppLayout.vue'),
      meta: { requiresAuth: true },
      children: [
        { path: '', redirect: '/users' },
        { path: 'users', name: 'users', component: () => import('@/views/UsersView.vue') },
        { path: 'users/:id', name: 'user-detail', component: () => import('@/views/UserDetailView.vue') },
        {
          path: 'analytics',
          name: 'analytics',
          component: () => import('@/views/AnalyticsView.vue'),
        },
        { path: 'invites', name: 'invites', component: () => import('@/views/InvitesView.vue') },
        { path: 'waitlist', name: 'waitlist', component: () => import('@/views/WaitlistView.vue') },
        { path: 'stories', name: 'stories', component: () => import('@/views/StoriesView.vue') },
        {
          path: 'stories/:id',
          name: 'story-detail',
          component: () => import('@/views/StoryDetailView.vue'),
        },
        { path: 'series', name: 'series', component: () => import('@/views/SeriesView.vue') },
        {
          path: 'series/:id',
          name: 'series-detail',
          component: () => import('@/views/SeriesDetailView.vue'),
        },
        { path: 'settings', name: 'settings', component: () => import('@/views/SettingsView.vue') },
        { path: 'shapes', name: 'shapes', component: () => import('@/views/ShapesView.vue') },
        { path: 'beats', redirect: '/shapes' },
        { path: 'elements', name: 'elements', component: () => import('@/views/ElementsView.vue') },
        { path: 'kernels', name: 'kernels', component: () => import('@/views/KernelsView.vue') },
        {
          path: 'theme-sparks',
          name: 'theme-sparks',
          component: () => import('@/views/ThemeSparksView.vue'),
        },
        { path: 'agents', name: 'agents', component: () => import('@/views/AgentsView.vue') },
        {
          path: 'llm-models',
          name: 'llm-models',
          component: () => import('@/views/LlmModelsView.vue'),
        },
        {
          path: 'llm-routing',
          name: 'llm-routing',
          component: () => import('@/views/LlmRoutingView.vue'),
        },
        { path: 'voices', name: 'voices', component: () => import('@/views/VoicesView.vue') },
        { path: 'tts-lab', name: 'tts-lab', component: () => import('@/views/TtsLabView.vue') },
      ],
    },
  ],
})

router.beforeEach((to) => {
  const auth = useAuthStore()
  if (to.meta.requiresAuth && !auth.isLoggedIn()) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }
  if (to.name === 'login' && auth.isLoggedIn()) {
    return { name: 'users' }
  }
})

export default router

import axios, { type AxiosError } from 'axios'
import { useAuthStore } from '@/stores/auth'

const baseURL = import.meta.env.VITE_API_BASE || ''

export const api = axios.create({
  baseURL,
  timeout: 30_000,
})

api.interceptors.request.use((config) => {
  const auth = useAuthStore()
  if (auth.token) {
    config.headers.Authorization = `Bearer ${auth.token}`
  }
  return config
})

api.interceptors.response.use(
  (res) => res,
  async (error: AxiosError<{ detail?: string } | Blob>) => {
    if (error.response?.status === 401) {
      const auth = useAuthStore()
      auth.logout()
      if (typeof window !== 'undefined' && !window.location.pathname.includes('/login')) {
        window.location.href = '/login'
      }
    }
    let detail: string | undefined
    const data = error.response?.data
    if (typeof Blob !== 'undefined' && data instanceof Blob) {
      try {
        const parsed = JSON.parse(await data.text()) as { detail?: string }
        if (typeof parsed.detail === 'string') detail = parsed.detail
      } catch {
        /* ignore non-JSON error blobs */
      }
    } else if (data && typeof data === 'object' && 'detail' in data) {
      const d = (data as { detail?: unknown }).detail
      if (typeof d === 'string') detail = d
    }
    return Promise.reject(new Error(detail || error.message))
  },
)

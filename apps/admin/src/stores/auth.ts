import { defineStore } from 'pinia'
import { ref } from 'vue'

const TOKEN_KEY = 'bedtime_admin_token'
const OPERATOR_KEY = 'bedtime_admin_operator'
const USERNAME_KEY = 'bedtime_admin_username'
const EXPIRES_KEY = 'bedtime_admin_expires_at'

export const useAuthStore = defineStore('auth', () => {
  const token = ref(sessionStorage.getItem(TOKEN_KEY) || '')
  const operator = ref(sessionStorage.getItem(OPERATOR_KEY) || '')
  const username = ref(sessionStorage.getItem(USERNAME_KEY) || '')
  const expiresAt = ref(sessionStorage.getItem(EXPIRES_KEY) || '')

  function login(data: {
    access_token: string
    operator: string
    username: string
    expires_at: string
  }) {
    token.value = data.access_token
    operator.value = data.operator
    username.value = data.username
    expiresAt.value = data.expires_at
    sessionStorage.setItem(TOKEN_KEY, token.value)
    sessionStorage.setItem(OPERATOR_KEY, operator.value)
    sessionStorage.setItem(USERNAME_KEY, username.value)
    sessionStorage.setItem(EXPIRES_KEY, expiresAt.value)
  }

  function logout() {
    token.value = ''
    operator.value = ''
    username.value = ''
    expiresAt.value = ''
    sessionStorage.removeItem(TOKEN_KEY)
    sessionStorage.removeItem(OPERATOR_KEY)
    sessionStorage.removeItem(USERNAME_KEY)
    sessionStorage.removeItem(EXPIRES_KEY)
  }

  const isLoggedIn = () => {
    if (!token.value) return false
    if (expiresAt.value) {
      const exp = Date.parse(expiresAt.value)
      if (!Number.isNaN(exp) && Date.now() >= exp) {
        logout()
        return false
      }
    }
    return true
  }

  return { token, operator, username, expiresAt, login, logout, isLoggedIn }
})

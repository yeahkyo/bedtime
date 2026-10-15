export interface AdminLoginOut {
  access_token: string
  token_type: string
  expires_at: string
  operator: string
  username: string
}

export interface AdminUserListItem {
  id: number
  display_name: string | null
  preferred_language: string
  apple_sub: string
  created_at: string | null
  story_used: number
  story_limit: number
  clone_used: number
  clone_limit: number
  children_count: number
  stories_count: number
}

export interface AdminUserListOut {
  items: AdminUserListItem[]
  total: number
  page: number
  page_size: number
}

export interface AdminUserDetailOut {
  id: number
  display_name: string | null
  preferred_language: string
  apple_sub: string
  created_at: string | null
  deleted_at: string | null
  story_retention_months: number
  story_used: number
  story_limit: number
  clone_used: number
  clone_limit: number
  quota_month?: string | null
  children: {
    id: number
    nickname: string
    age_band: string
    birth_date?: string | null
    gender?: string
    intro?: string | null
  }[]
  voices: { id: number; name: string; kind: string; provider: string }[]
  stories_count: number
}

export interface AdminQuotaOut {
  month: string
  story_used: number
  story_limit: number
  clone_used: number
  clone_limit: number
}

export interface AdminStoryListItem {
  id: number
  title: string
  status: string
  progress: string | null
  language: string
  theme: string | null
  user_id: number
  user_display_name: string | null
  child_id: number | null
  story_provider: string | null
  speech_provider: string | null
  duration_minutes: number
  created_at: string | null
  error_message: string | null
}

export interface AdminStoryListOut {
  items: AdminStoryListItem[]
  total: number
  page: number
  page_size: number
}

export interface AdminStoryDetailOut {
  id: number
  title: string
  body: string
  status: string
  progress: string | null
  language: string
  theme: string | null
  soft_hook: string | null
  user_id: number
  user_display_name: string | null
  child_id: number | null
  voice_id: number | null
  voice_name: string | null
  story_provider: string | null
  speech_provider: string | null
  duration_minutes: number
  series_id: number | null
  episode_no: number | null
  audio_url: string | null
  error_message: string | null
  params_json: string | null
  episode_plan_json?: string | null
  created_at: string | null
}

export interface ProvidersSettingsOut {
  story_provider: string
  speech_provider: string
  env_story_provider: string
  env_speech_provider: string
  overrides: Record<string, string>
  available: {
    story_providers: { id: string; configured: boolean }[]
    speech_providers: { id: string; configured: boolean }[]
  }
}

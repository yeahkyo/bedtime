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
  voices: {
    id: number
    name: string
    kind: string
    provider: string
    provider_voice_id?: string
    speech_model?: string | null
  }[]
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

export interface AdminStorySeriesBrief {
  id: number
  title: string
  status: string
  episode_count: number
  throughline: string | null
  cast_spine: unknown
  episodes: unknown[] | null
  outline_json: string
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
  speech_model?: string | null
  duration_minutes: number
  series_id: number | null
  episode_no: number | null
  audio_url: string | null
  error_message: string | null
  params_json: string | null
  episode_plan_json?: string | null
  metrics_json?: string | null
  prompts_json?: string | null
  series?: AdminStorySeriesBrief | null
  created_at: string | null
}

export interface AdminSeriesListItem {
  id: number
  title: string
  status: string
  language: string
  theme: string | null
  episode_count: number
  user_id: number
  user_display_name: string | null
  child_id: number | null
  child_nickname: string | null
  stories_count: number
  throughline: string | null
  created_at: string | null
}

export interface AdminSeriesListOut {
  items: AdminSeriesListItem[]
  total: number
  page: number
  page_size: number
}

export interface AdminSeriesDetailOut {
  id: number
  title: string
  status: string
  language: string
  theme: string | null
  episode_count: number
  user_id: number
  user_display_name: string | null
  child_id: number | null
  child_nickname: string | null
  throughline: string | null
  cast_spine: unknown
  threads: unknown[] | null
  episodes: unknown[] | null
  outline_json: string
  stories: {
    episode_no: number | null
    story_id: number
    title: string
    status: string
  }[]
  created_at: string | null
}

export interface ProviderOption {
  id: string
  configured: boolean
  env_model?: string
}

export interface ProvidersSettingsOut {
  story_provider: string
  speech_provider: string
  story_model: string
  speech_model: string
  env_story_provider: string
  env_speech_provider: string
  env_story_model: string
  env_speech_model: string
  overrides: Record<string, string>
  available: {
    story_providers: ProviderOption[]
    speech_providers: ProviderOption[]
  }
}

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
  phone?: string | null
  disabled?: boolean
  created_at: string | null
  last_active_at?: string | null
  story_used: number
  story_limit: number
  clone_used: number
  clone_limit: number
  children_count: number
  stories_count: number
}

export interface InviteOut {
  id: number
  code: string
  note: string | null
  created_by: string | null
  created_at: string | null
  expires_at: string | null
  used_at: string | null
  used_by_user_id: number | null
  revoked_at: string | null
  status: string
}

export interface InviteListOut {
  items: InviteOut[]
  total: number
  page: number
  page_size: number
}

export interface InviteCreateOut {
  items: InviteOut[]
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
  phone?: string | null
  disabled_at?: string | null
  token_version?: number
  created_at: string | null
  last_active_at?: string | null
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
  story_model?: string | null
  speech_provider: string | null
  speech_model?: string | null
  voice_name?: string | null
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
  story_model?: string | null
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

/** Recomputed TTS payload for admin inspection. */
export interface AdminStoryTtsInputOut {
  story_id: number
  source: string
  speak_text: string
  ssml: string | null
  used_ssml: boolean
  provider: string | null
  model: string | null
  display?: string
  prosody_mode?: string
}

export interface AdminTtsLabPrepareOut {
  display: string
  speak_text: string
  ssml: string | null
  used_ssml: boolean
  prosody_mode: string
  provider: string | null
  model: string | null
  voice_id: number | null
  voice_name: string | null
}

export interface AdminTtsLabSynthesizeOut extends AdminTtsLabPrepareOut {
  audio_base64: string
  audio_content_type: string
  audio_bytes: number
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
  story_model: string
  env_story_provider: string
  env_story_model: string
  overrides: Record<string, string>
  available: {
    story_providers: ProviderOption[]
    speech_providers: ProviderOption[]
  }
}

export interface AnalyticsSummaryOut {
  from_date: string
  to_date: string
  event_counts: Record<string, number>
  story_status_counts: Record<string, number>
  listen_rate: number | null
}

export interface AnalyticsEngagementOut {
  from_date: string
  to_date: string
  as_of: string
  max_range_days: number
  dau: { date: string; users: number }[]
  retention: {
    cohort_date: string
    cohort_size: number
    d1: number | null
    d7: number | null
    d30: number | null
  }[]
  avg_dau: number | null
  avg_d1: number | null
  avg_d7: number | null
  avg_d30: number | null
}

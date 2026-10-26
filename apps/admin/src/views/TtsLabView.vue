<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { ElMessage } from 'element-plus'
import { api } from '@/api/client'
import type { AdminTtsLabPrepareOut, AdminTtsLabSynthesizeOut } from '@/api/types'

interface VoiceOption {
  id: number
  name: string
  provider: string
  provider_voice_id: string
  speech_model: string | null
  enabled: boolean
  kind: string
}

const PROSODY_OPTIONS = [
  { value: 'auto', label: 'auto（跟音色 provider）' },
  { value: 'fish_break', label: 'fish_break — [break] / [long-break]' },
  { value: 'punct', label: 'punct — …… 标点呼吸' },
  { value: 'none', label: 'none — 不加停顿标记' },
]

const route = useRoute()
const voices = ref<VoiceOption[]>([])
const voicesLoading = ref(false)
const text = ref('')
const voiceId = ref<number | undefined>(undefined)
const prosody = ref('auto')
const speed = ref(1.0)

const preparing = ref(false)
const synthesizing = ref(false)
const prepared = ref<AdminTtsLabPrepareOut | null>(null)

let audioEl: HTMLAudioElement | null = null
const audioUrl = ref<string | null>(null)
let playGen = 0

const voiceLabel = computed(() => {
  const v = voices.value.find((x) => x.id === voiceId.value)
  if (!v) return ''
  return `${v.name} · ${v.provider}${v.enabled ? '' : '（已禁用）'}`
})

function stopAudio() {
  playGen += 1
  if (audioEl) {
    audioEl.pause()
    audioEl.src = ''
    audioEl = null
  }
  if (audioUrl.value) {
    URL.revokeObjectURL(audioUrl.value)
    audioUrl.value = null
  }
}

function playBase64(b64: string, contentType: string) {
  stopAudio()
  const gen = playGen
  const bin = atob(b64)
  const bytes = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i += 1) bytes[i] = bin.charCodeAt(i)
  const blob = new Blob([bytes], { type: contentType || 'audio/mpeg' })
  audioUrl.value = URL.createObjectURL(blob)
  audioEl = new Audio(audioUrl.value)
  void audioEl.play().catch(() => {
    if (gen === playGen) ElMessage.warning('浏览器无法自动播放，请点播放器控件')
  })
}

async function loadVoices() {
  voicesLoading.value = true
  try {
    const { data } = await api.get<{ items: VoiceOption[] }>('/admin/voices', {
      params: { page: 1, page_size: 100 },
    })
    voices.value = data.items || []
    if (voiceId.value == null && voices.value.length) {
      const enabled = voices.value.find((v) => v.enabled)
      voiceId.value = (enabled || voices.value[0]).id
    }
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '加载音色失败')
  } finally {
    voicesLoading.value = false
  }
}

function payload() {
  if (!voiceId.value) {
    ElMessage.warning('请选择音色')
    return null
  }
  const body = text.value.trim()
  if (!body) {
    ElMessage.warning('请粘贴文案')
    return null
  }
  return {
    text: body,
    voice_id: voiceId.value,
    prosody: prosody.value,
    speed: speed.value,
  }
}

async function runPrepare() {
  const body = payload()
  if (!body) return
  preparing.value = true
  try {
    const { data } = await api.post<AdminTtsLabPrepareOut>('/admin/tts-lab/prepare', body)
    prepared.value = data
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '后处理失败')
  } finally {
    preparing.value = false
  }
}

async function runSynthesize() {
  const body = payload()
  if (!body) return
  synthesizing.value = true
  try {
    const { data } = await api.post<AdminTtsLabSynthesizeOut>('/admin/tts-lab/synthesize', body, {
      timeout: 180_000,
    })
    prepared.value = data
    playBase64(data.audio_base64, data.audio_content_type)
    ElMessage.success(`已生成 ${data.audio_bytes} bytes`)
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '合成失败')
  } finally {
    synthesizing.value = false
  }
}

onMounted(async () => {
  const qText = route.query.text
  if (typeof qText === 'string' && qText.trim()) {
    text.value = qText
  }
  const qVoice = route.query.voice_id
  if (typeof qVoice === 'string' && /^\d+$/.test(qVoice)) {
    voiceId.value = Number(qVoice)
  }
  await loadVoices()
})

onBeforeUnmount(stopAudio)
</script>

<template>
  <div v-loading="voicesLoading">
    <h2>TTS 试验台</h2>
    <p class="muted">
      粘贴故事正文，选择音色与后处理算法，先看注入后的文案，再合成试听。不写回故事、不落库。
    </p>

    <el-form label-width="100px" class="form">
      <el-form-item label="音色">
        <el-select v-model="voiceId" filterable style="width: 420px" placeholder="选择音色">
          <el-option
            v-for="v in voices"
            :key="v.id"
            :label="`${v.name} · ${v.provider}${v.enabled ? '' : '（禁用）'}`"
            :value="v.id"
          />
        </el-select>
        <span v-if="voiceLabel" class="muted tiny">{{ voiceLabel }}</span>
      </el-form-item>
      <el-form-item label="后处理">
        <el-select v-model="prosody" style="width: 420px">
          <el-option
            v-for="opt in PROSODY_OPTIONS"
            :key="opt.value"
            :label="opt.label"
            :value="opt.value"
          />
        </el-select>
      </el-form-item>
      <el-form-item label="语速">
        <el-slider v-model="speed" :min="0.5" :max="1.5" :step="0.05" style="width: 280px" />
        <span class="muted tiny">{{ speed.toFixed(2) }}</span>
      </el-form-item>
      <el-form-item label="原文">
        <el-input
          v-model="text"
          type="textarea"
          :rows="14"
          placeholder="从故事详情复制正文粘贴到这里"
        />
      </el-form-item>
      <el-form-item>
        <el-button :loading="preparing" @click="runPrepare">只后处理</el-button>
        <el-button type="primary" :loading="synthesizing" @click="runSynthesize">
          后处理并生成试听
        </el-button>
        <el-button v-if="audioUrl || prepared" @click="stopAudio">停止播放</el-button>
      </el-form-item>
    </el-form>

    <template v-if="prepared">
      <h3>后处理结果</h3>
      <el-descriptions :column="2" border size="small" class="block">
        <el-descriptions-item label="provider">{{ prepared.provider || '—' }}</el-descriptions-item>
        <el-descriptions-item label="model">{{ prepared.model || '—' }}</el-descriptions-item>
        <el-descriptions-item label="prosody">{{ prepared.prosody_mode }}</el-descriptions-item>
        <el-descriptions-item label="used_ssml">
          {{ prepared.used_ssml ? 'yes' : 'no' }}
        </el-descriptions-item>
        <el-descriptions-item v-if="prepared.voice_name" label="voice">
          {{ prepared.voice_name }}
        </el-descriptions-item>
      </el-descriptions>
      <p class="prompt-label">speak_text（实际会发给 TTS）</p>
      <el-input :model-value="prepared.speak_text" type="textarea" :rows="12" readonly />
      <template v-if="prepared.ssml">
        <p class="prompt-label">ssml</p>
        <pre class="json">{{ prepared.ssml }}</pre>
      </template>
      <audio
        v-if="audioUrl"
        class="player"
        :src="audioUrl"
        controls
        style="width: 100%; margin-top: 12px"
      />
    </template>
  </div>
</template>

<style scoped>
h2 {
  margin: 0 0 8px;
}
.muted {
  color: var(--el-text-color-secondary);
  font-size: 13px;
}
.tiny {
  margin-left: 8px;
  font-size: 12px;
}
.form {
  margin-top: 16px;
  max-width: 960px;
}
.block {
  margin: 12px 0;
}
.prompt-label {
  margin: 8px 0 4px;
  font-size: 12px;
  color: var(--el-text-color-secondary);
}
.json {
  margin: 0;
  padding: 12px;
  background: #f5f7fa;
  border-radius: 6px;
  font-size: 12px;
  line-height: 1.45;
  overflow: auto;
  max-height: 420px;
  white-space: pre-wrap;
  word-break: break-word;
}
.player {
  margin-bottom: 24px;
}
</style>

<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { core, initBridge, parseTSV } from '../lib/bridge'
import { toast } from '../lib/toast'
import { TELEMETRY_GROUPS, fmtTelemetry, telemetryMeta } from '../lib/meta'

const props = defineProps({ active: Boolean })
const rows = ref([])
const raw = ref('—')
const live = ref(true)
const updated = ref('—')
let timer = null

const groups = computed(() => {
  const map = new Map()
  for (const r of rows.value) {
    if (!map.has(r.group)) map.set(r.group, [])
    map.get(r.group).push(r)
  }
  return TELEMETRY_GROUPS.filter((g) => map.has(g)).map((g) => ({ name: g, rows: map.get(g) }))
})

function tone(key, value) {
  const n = Number(value)
  if (key === 'lsposed_hook_fail' && n > 0) return 'warn'
  if (key === 'temp_soc_c' && n > 65) return 'warn'
  if (key === 'mem_avail_kb' && n > 0 && n < 400000) return 'warn'
  return ''
}

async function load(showError = false) {
  try {
    const out = await core('status')
    raw.value = out || '—'
    rows.value = parseTSV(out).map((r) => {
      const key = r[0]
      const value = r.slice(1).join('\t')
      const m = telemetryMeta(key)
      return {
        key,
        label: m.label,
        group: m.group,
        value: fmtTelemetry(key, value),
        tone: tone(key, value),
      }
    })
    updated.value = new Date().toLocaleTimeString([], {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    })
  } catch (e) {
    if (showError) toast('Telemetry failed: ' + (e.message || e))
  }
}

function toggleLive() {
  live.value = !live.value
  if (live.value) load()
}

onMounted(async () => {
  await initBridge()
  await load(true)
  timer = setInterval(() => {
    if (props.active && live.value) load()
  }, 8000)
})
onUnmounted(() => {
  if (timer) clearInterval(timer)
})
</script>

<template>
  <section class="panel">
    <div class="panel-head">
      <div>
        <div class="panel-title">Telemetry</div>
        <div class="panel-sub">Direct sysfs and settings snapshot. Read-only; nothing is written from this tab.</div>
      </div>
      <div class="btnrow">
        <button class="btn ghost" type="button" @click="toggleLive">
          {{ live ? 'Pause live' : 'Resume live' }}
        </button>
        <button class="btn ghost" type="button" @click="load(true)">Refresh</button>
      </div>
    </div>
    <div class="panel-body">
      <div class="telemetry-meta">
        <span class="pill" :class="{ active: live }">{{ live ? 'live · 8s' : 'paused' }}</span>
        <span class="faint">Updated {{ updated }}</span>
      </div>

      <div v-if="!rows.length" class="state">Loading telemetry…</div>
      <template v-else>
        <div v-for="g in groups" :key="g.name">
          <div class="section-label">{{ g.name }}</div>
          <div class="stat-grid">
            <div v-for="s in g.rows" :key="s.key" class="stat">
              <div class="k">{{ s.label }}</div>
              <div class="v" :class="s.tone">{{ s.value }}</div>
            </div>
          </div>
        </div>
      </template>

      <details class="details">
        <summary>Raw key/value output</summary>
        <pre>{{ raw }}</pre>
      </details>
    </div>
  </section>
</template>

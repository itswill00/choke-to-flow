<script setup>
import { onMounted, onUnmounted, ref } from 'vue'
import { core, parseTSV } from '../lib/bridge'
import { toast } from '../lib/toast'

const props = defineProps({ active: Boolean })
const stats = ref([])
const raw = ref('—')
let timer = null

const LABELS = {
  device: 'Perangkat', rom: 'ROM', uptime_s: 'Uptime', load: 'Load avg',
  temp_soc_c: 'Suhu SoC', temp_skin_c: 'Suhu skin', temp_batt_c: 'Suhu baterai',
  zram_used_kb: 'Zram terpakai', zram_total_kb: 'Zram total',
  mem_avail_kb: 'Mem tersedia', mem_free_kb: 'Mem free',
  cpu_little_cur_khz: 'CPU little', cpu_little_cap_khz: 'Cap little',
  cpu_little_hw_khz: 'HW little', cpu_big_cur_khz: 'CPU big',
  cpu_big_cap_khz: 'Cap big', cpu_big_hw_khz: 'HW big',
  charge_now_ua: 'Arus cas', battery_pct: 'Baterai', charge_limit: 'Charge limit',
  module_count: 'Modul aktif', lsposed_hook_fail: 'Hook Failed',
}

function fmt(k, v) {
  if (v === '?' || v === '' || v == null) return '—'
  if (k === 'uptime_s') return Math.round(Number(v) / 60) + ' mnt'
  if (k.endsWith('_kb')) return (Number(v) / 1024).toFixed(0) + ' MB'
  if (k.endsWith('_khz')) return (Number(v) / 1000).toFixed(2) + ' GHz'
  if (k.endsWith('_ua')) return (Number(v) / 1e6).toFixed(2) + ' A'
  if (k.endsWith('_c')) return v + ' °C'
  if (k === 'battery_pct') return v + ' %'
  return v
}

function tone(k, v) {
  if (k === 'lsposed_hook_fail' && Number(v) > 0) return 'warnv'
  if (k === 'temp_soc_c' && Number(v) > 65) return 'warnv'
  if (k === 'mem_avail_kb' && Number(v) < 400000) return 'warnv'
  return ''
}

async function load(silent = true) {
  try {
    const out = await core('status')
    raw.value = out || '—'
    stats.value = parseTSV(out).map((r) => ({
      k: LABELS[r[0]] || r[0],
      v: fmt(r[0], r.slice(1).join('\t')),
      tone: tone(r[0], r.slice(1).join('\t')),
    }))
  } catch (e) {
    if (!silent) toast('Telemetry gagal: ' + (e.message || e))
  }
}

onMounted(() => {
  load(false)
  timer = setInterval(() => { if (props.active) load() }, 8000)
})
onUnmounted(() => { if (timer) clearInterval(timer) })
</script>

<template>
  <div class="card">
    <div class="card-head">
      <div>
        <h2>Live snapshot</h2>
        <p class="muted">Dibaca langsung dari sysfs / settings. Tidak ada yang diubah di sini.</p>
      </div>
      <button class="btn ghost" @click="load(false)">Refresh</button>
    </div>
    <div v-if="!stats.length" class="loading">Memuat…</div>
    <div v-else class="stats">
      <div v-for="(s, i) in stats" :key="i" class="stat">
        <div class="k">{{ s.k }}</div>
        <div class="v" :class="s.tone">{{ s.v }}</div>
      </div>
    </div>
  </div>
  <div class="card">
    <div class="card-head"><h2>Raw values</h2></div>
    <pre class="raw">{{ raw }}</pre>
  </div>
</template>

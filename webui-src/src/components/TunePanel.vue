<script setup>
import { onMounted, ref } from 'vue'
import { core, modDir, exec, parseTSV } from '../lib/bridge'
import { toast } from '../lib/toast'

const rows = ref([])
const loading = ref(true)
const busy = ref(false)

const LABELS = {
  cpu_little_max: 'CPU little · max freq',
  cpu_little_min: 'CPU little · min freq',
  cpu_big_max: 'CPU big · max freq',
  cpu_big_min: 'CPU big · min freq',
  gpu_max: 'GPU · max freq',
  swappiness: 'VM · swappiness',
  anim_window: 'Animasi · window',
  anim_transition: 'Animasi · transition',
  animator_duration: 'Animasi · animator',
}
const label = (k) => LABELS[k] || k.replace(/_/g, ' ')
const cat = (rel) => exec('cat ' + modDir.value + rel)

async function load() {
  loading.value = true
  try {
    const [cfg, tgt, base] = await Promise.all([
      cat('/state/config.tsv'),
      cat('/state/targets.tsv'),
      cat('/state/baseline.tsv'),
    ])
    const targets = {}
    parseTSV(tgt).forEach((r) => { targets[r[0]] = { path: r[1], kind: r[2] } })
    const baseline = {}
    parseTSV(base).forEach((r) => { baseline[r[0]] = r[1] })

    rows.value = await Promise.all(parseTSV(cfg).map(async (r) => {
      const key = r[0]
      const b = parseTSV(await core('bounds ' + key))[0] || ['0', '0', '1', '']
      const cur = await core('get ' + key)
      return {
        key,
        label: label(key),
        kind: targets[key] ? targets[key].kind : '?',
        auto: r[1] !== 'custom',
        value: (r[2] || cur || b[1] || 0),
        min: Number(b[0] || 0),
        max: Number(b[1] || 0),
        step: Number(b[2] || 1),
        unit: b[3] || (targets[key] && targets[key].kind === 'settings' ? 'x' : ''),
        current: cur || '—',
        stock: baseline[key] || '—',
      }
    }))
  } catch (e) {
    toast('Gagal memuat: ' + (e.message || e))
  } finally {
    loading.value = false
  }
}

async function applyAll() {
  busy.value = true
  try {
    for (const r of rows.value) {
      const mode = r.auto ? 'auto' : 'custom'
      const res = await core('set ' + r.key + ' ' + mode + ' ' + (r.auto ? '' : r.value))
      if (res.startsWith('ERR')) { toast(res); return }
    }
    const res = await core('apply')
    toast('Applied · ' + res.replace(/\s+/g, ' ').slice(0, 60))
    await load()
  } catch (e) {
    toast('Gagal apply: ' + (e.message || e))
  } finally {
    busy.value = false
  }
}

async function resetBaseline() {
  busy.value = true
  try {
    await core('restore')
    toast('Baseline dipulihkan')
    await load()
  } catch (e) {
    toast('Gagal reset: ' + (e.message || e))
  } finally {
    busy.value = false
  }
}

function preset(name) {
  rows.value.forEach((r) => {
    if (name === 'stock') {
      r.auto = true
    } else if (name === 'balanced') {
      if (r.key.startsWith('anim_') || r.key === 'animator_duration') {
        r.auto = false; r.value = 0.5
      } else {
        r.auto = true
      }
    } else if (name === 'perf') {
      if (r.key.endsWith('_max')) {
        r.auto = false; r.value = r.max
      } else if (r.key.startsWith('anim_') || r.key === 'animator_duration') {
        r.auto = false; r.value = 0.3
      } else {
        r.auto = true
      }
    }
  })
  toast('Preset "' + name + '" diisi — tekan Apply now')
}

onMounted(load)
</script>

<template>
  <div class="card">
    <div class="card-head">
      <div>
        <h2>Parameters</h2>
        <p class="muted">Path &amp; batas di-deteksi saat runtime. <b>AUTO</b> = modul tidak menyentuh nilai sama sekali.</p>
      </div>
      <div class="btnrow">
        <button class="btn ghost" :disabled="busy" @click="load">Refresh</button>
        <button class="btn primary" :disabled="busy" @click="applyAll">Apply now</button>
      </div>
    </div>

    <div v-if="loading" class="loading">Memuat konfigurasi…</div>
    <div v-else class="grid">
      <div v-for="r in rows" :key="r.key" class="tune">
        <div class="tune-top">
          <label>{{ r.label }}</label>
          <span class="badge" :class="{ custom: !r.auto }">{{ r.auto ? 'auto' : 'custom' }}</span>
        </div>
        <div class="tune-sub">
          Sekarang <b>{{ r.current }}</b> · stock <b>{{ r.stock }}</b><br>
          Batas {{ r.min }}–{{ r.max }} {{ r.unit }} · {{ r.kind }}
        </div>
        <div class="row">
          <label class="switch" :title="r.auto ? 'AUTO: tidak diubah' : 'CUSTOM: nilai diterapkan'">
            <input type="checkbox" v-model="r.auto">
            <span class="slider"></span>
          </label>
          <span class="small">{{ r.auto ? 'AUTO — jangan ubah' : 'CUSTOM — terapkan nilai' }}</span>
        </div>
        <div class="row">
          <input type="range" v-model.number="r.value" :min="r.min" :max="r.max" :step="r.step" :disabled="r.auto">
          <input type="number" v-model.number="r.value" :min="r.min" :max="r.max" :step="r.step" :disabled="r.auto">
          <span class="small">{{ r.unit }}</span>
        </div>
      </div>
    </div>
  </div>

  <div class="card">
    <div class="card-head">
      <div>
        <h2>Presets</h2>
        <p class="muted">Hanya mengisi form — tetap tekan <b>Apply now</b> supaya tersimpan &amp; diterapkan.</p>
      </div>
    </div>
    <div class="presets">
      <button class="btn" :disabled="busy" @click="preset('stock')">Stock / AUTO</button>
      <button class="btn" :disabled="busy" @click="preset('balanced')">Balanced</button>
      <button class="btn" :disabled="busy" @click="preset('perf')">Performance</button>
      <button class="btn danger" :disabled="busy" @click="resetBaseline">Reset ke baseline</button>
    </div>
  </div>
</template>

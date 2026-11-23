<script setup>
import { computed, onMounted, ref } from 'vue'
import { core, exec, initBridge, modDir, parseTSV } from '../lib/bridge'
import { toast } from '../lib/toast'
import { GROUP_ORDER, human, meta } from '../lib/meta'

const rows = ref([])
const loading = ref(true)
const busy = ref(false)

const customCount = computed(() => rows.value.filter((r) => !r.auto).length)

const groups = computed(() => {
  const map = new Map()
  for (const r of rows.value) {
    if (!map.has(r.group)) map.set(r.group, [])
    map.get(r.group).push(r)
  }
  return [...map.entries()]
    .sort((a, b) => {
      const ia = GROUP_ORDER.indexOf(a[0])
      const ib = GROUP_ORDER.indexOf(b[0])
      return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib)
    })
    .map(([name, list]) => ({ name, rows: list }))
})

const cat = (rel) => exec('cat ' + modDir.value + rel)
const show = (value, unit) => human(value, unit)
const range = (r) => show(r.min, r.unit) + ' – ' + show(r.max, r.unit)

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
      const m = meta(key)
      const b = parseTSV(await core('bounds ' + key))[0] || ['0', '0', '1', '']
      const cur = await core('get ' + key)
      return {
        key,
        group: m.group,
        label: m.label,
        desc: m.desc,
        kind: targets[key] ? targets[key].kind : '?',
        auto: r[1] !== 'custom',
        value: r[2] || cur || b[1] || 0,
        min: Number(b[0] || 0),
        max: Number(b[1] || 0),
        step: Number(b[2] || 1),
        unit: b[3] || (targets[key] && targets[key].kind === 'settings' ? 'x' : ''),
        current: cur || '—',
        stock: baseline[key] || '—',
      }
    }))
  } catch (e) {
    toast('Failed to load: ' + (e.message || e))
  } finally {
    loading.value = false
  }
}

async function applyAll() {
  if (!customCount.value) {
    toast('No custom values to apply.')
    return
  }
  busy.value = true
  try {
    for (const r of rows.value) {
      const mode = r.auto ? 'auto' : 'custom'
      const res = await core('set ' + r.key + ' ' + mode + ' ' + (r.auto ? '' : r.value))
      if (res.startsWith('ERR')) {
        toast(res)
        return
      }
    }
    await core('apply')
    toast('Applied. Check Telemetry for live values.')
    await load()
  } catch (e) {
    toast('Apply failed: ' + (e.message || e))
  } finally {
    busy.value = false
  }
}

async function resetBaseline() {
  if (!window.confirm('Restore every key this module has written to its captured original value?')) return
  busy.value = true
  try {
    await core('restore')
    toast('Original values restored.')
    await load()
  } catch (e) {
    toast('Restore failed: ' + (e.message || e))
  } finally {
    busy.value = false
  }
}

function preset(name) {
  if (name === 'perf' && !window.confirm('Performance raises CPU/GPU caps to the hardware maximum. Continue?')) return
  rows.value.forEach((r) => {
    if (name === 'stock') {
      r.auto = true
    } else if (name === 'balanced') {
      if (r.group === 'Interface') {
        r.auto = false
        r.value = 0.5
      } else {
        r.auto = true
      }
    } else if (name === 'perf') {
      if (r.key.endsWith('_max')) {
        r.auto = false
        r.value = r.max
      } else if (r.group === 'Interface') {
        r.auto = false
        r.value = 0.3
      } else {
        r.auto = true
      }
    }
  })
  toast('Preset filled. Review, then Apply changes.')
}

onMounted(async () => {
  await initBridge()
  await load()
})
</script>

<template>
  <div class="tab-root">
  <section class="panel">
    <div class="panel-head">
      <div>
        <div class="panel-title">Parameters</div>
        <div class="panel-sub">Paths and bounds are detected at runtime. AUTO leaves a value completely untouched.</div>
      </div>
      <div class="btnrow">
        <button class="btn ghost" type="button" :disabled="busy" @click="load">Refresh</button>
        <button class="btn primary" type="button" :disabled="busy" @click="applyAll">Apply changes</button>
      </div>
    </div>

    <div class="panel-body">
      <div v-if="loading" class="state">Loading configuration…</div>
      <template v-else>
        <div v-for="g in groups" :key="g.name" class="param-group">
          <div class="group-label">{{ g.name }}</div>
          <div v-for="r in g.rows" :key="r.key" class="param">
            <div class="param-main">
              <div class="param-title">
                {{ r.label }}
                <span class="badge" :class="{ custom: !r.auto }">{{ r.auto ? 'auto' : 'custom' }}</span>
              </div>
              <div class="param-desc">{{ r.desc }}</div>
              <div class="param-meta">
                Current <b>{{ show(r.current, r.unit) }}</b>
                · captured <b>{{ show(r.stock, r.unit) }}</b>
                · range {{ range(r) }}
              </div>
            </div>
            <div class="param-control">
              <div class="toggle-row">
                <label class="switch">
                  <input v-model="r.auto" type="checkbox">
                  <span class="track"></span>
                </label>
                <span class="toggle-label">{{ r.auto ? 'Left untouched' : 'Applied at boot' }}</span>
              </div>
              <div class="value-line">
                <input
                  v-model.number="r.value"
                  type="range"
                  :min="r.min" :max="r.max" :step="r.step"
                  :disabled="r.auto"
                >
                <input
                  v-model.number="r.value"
                  type="number"
                  :min="r.min" :max="r.max" :step="r.step"
                  :disabled="r.auto"
                >
                <span class="unit">{{ r.unit }}</span>
              </div>
            </div>
          </div>
        </div>
      </template>
    </div>
  </section>

  <section class="panel">
    <div class="panel-head">
      <div>
        <div class="panel-title">Presets</div>
        <div class="panel-sub">Presets only fill the form. Nothing is written until you press Apply changes.</div>
      </div>
    </div>
    <div class="panel-body">
      <div class="preset-row">
        <button class="btn" type="button" :disabled="busy" @click="preset('stock')">Stock / AUTO</button>
        <button class="btn" type="button" :disabled="busy" @click="preset('balanced')">Balanced</button>
        <button class="btn" type="button" :disabled="busy" @click="preset('perf')">Performance</button>
        <button class="btn danger" type="button" :disabled="busy" @click="resetBaseline">Restore originals</button>
      </div>
      <div class="preset-note">
        Restore replays only keys this module actually wrote, using their pre-write values. Untouched stock nodes are never overwritten.
      </div>
    </div>
  </section>

  <div class="actionbar">
    <div class="actionbar-inner">
      <div class="action-summary"><b>{{ customCount }}</b> custom · {{ rows.length }} total</div>
      <button class="btn primary" type="button" :disabled="busy || !customCount" @click="applyAll">
        {{ busy ? 'Applying…' : 'Apply changes' }}
      </button>
    </div>
  </div>
  </div>
</template>

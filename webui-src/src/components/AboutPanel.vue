<script setup>
import { onMounted, ref } from 'vue'
import { exec, initBridge, modDir } from '../lib/bridge'
import { toast } from '../lib/toast'

const cfg = ref('—')
const base = ref('—')
const last = ref('—')
const touched = ref('—')
const info = ref({
  name: 'Choke to Flow',
  version: '—',
  versionCode: '—',
  author: '—',
  description: '',
})

const cat = (rel) => exec('cat ' + modDir.value + rel)

async function load() {
  try {
    const [c, b, l, t, p] = await Promise.all([
      cat('/state/config.tsv'),
      cat('/state/baseline.tsv'),
      cat('/state/last_apply.tsv'),
      cat('/state/touched.tsv'),
      cat('/module.prop'),
    ])
    cfg.value = c || '—'
    base.value = b || '—'
    last.value = l || '—'
    touched.value = t || '—'

    const map = {}
    String(p || '').split('\n').forEach((line) => {
      const i = line.indexOf('=')
      if (i > 0) map[line.slice(0, i).trim()] = line.slice(i + 1).trim()
    })
    info.value = {
      name: map.name || 'Choke to Flow',
      version: map.version || '—',
      versionCode: map.versionCode || '—',
      author: map.author || '—',
      description: map.description || '',
    }
  } catch (_) {
    /* keep placeholders */
  }
}

async function copyConfig() {
  try {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      await navigator.clipboard.writeText(cfg.value)
    } else {
      const ta = document.createElement('textarea')
      ta.value = cfg.value
      document.body.appendChild(ta)
      ta.select()
      document.execCommand('copy')
      document.body.removeChild(ta)
    }
    toast('Configuration copied.')
  } catch (e) {
    toast('Copy failed: ' + (e.message || e))
  }
}

onMounted(async () => {
  await initBridge()
  await load()
})
</script>

<template>
  <section class="panel">
    <div class="panel-head">
      <div>
        <div class="panel-title">{{ info.name }}</div>
        <div class="panel-sub">{{ info.description }}</div>
      </div>
      <span class="pill">v{{ info.version }} · {{ info.versionCode }}</span>
    </div>
    <div class="panel-body">
      <ul class="bullets">
        <li>Runtime detection for CPU policies and GPU devfreq — no device paths in code.</li>
        <li>Every write is recorded with its pre-write value; restore only replays touched keys.</li>
        <li>No charging, thermal, LMK, or sepolicy writes. No automatic module disabling.</li>
        <li>Compiled Vue WebUI served from local static assets; no CDN dependency.</li>
      </ul>
      <div class="about-links">
        <a href="https://github.com/itswill00/choke-to-flow" target="_blank" rel="noopener">Repository</a>
        <span class="faint">·</span>
        <a href="https://github.com/itswill00/choke-to-flow/issues" target="_blank" rel="noopener">Issues</a>
        <span class="faint">·</span>
        <span class="faint">by {{ info.author }}</span>
      </div>
    </div>
  </section>

  <section class="panel">
    <div class="panel-head">
      <div>
        <div class="panel-title">Runtime data</div>
        <div class="panel-sub">Stored on device. Baseline is a snapshot; touched is the authoritative restore list.</div>
      </div>
      <button class="btn ghost" type="button" @click="load">Refresh</button>
    </div>
    <div class="panel-body">
      <details class="details" open>
        <summary>Configuration</summary>
        <pre>{{ cfg }}</pre>
      </details>
      <details class="details">
        <summary>Touched keys · restore source</summary>
        <pre>{{ touched }}</pre>
      </details>
      <details class="details">
        <summary>Baseline snapshot</summary>
        <pre>{{ base }}</pre>
      </details>
      <details class="details">
        <summary>Last apply verification</summary>
        <pre>{{ last }}</pre>
      </details>
      <div class="btnrow" style="margin-top: 12px">
        <button class="btn ghost" type="button" @click="copyConfig">Copy configuration</button>
      </div>
    </div>
  </section>

  <section class="panel">
    <div class="panel-body">
      <div class="note neutral">
        This is a tuning utility, not a benchmark. Values accepted by sysfs can still be clamped by
        the vendor power or thermal stack. Check the Telemetry tab after applying a change.
      </div>
    </div>
  </section>
</template>

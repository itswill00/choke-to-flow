<script setup>
import { onMounted, ref } from 'vue'
import { exec, modDir } from '../lib/bridge'
import { toast } from '../lib/toast'

const cfg = ref('—')
const base = ref('—')
const last = ref('Belum pernah apply.')
const cat = (rel) => exec('cat ' + modDir.value + rel)

async function load() {
  try {
    const [c, b, l] = await Promise.all([
      cat('/state/config.tsv'),
      cat('/state/baseline.tsv'),
      cat('/state/last_apply.tsv'),
    ])
    cfg.value = c || '—'
    base.value = b || '—'
    last.value = l || 'Belum pernah apply.'
  } catch (_) { /* ignore */ }
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
    toast('Config disalin')
  } catch (e) {
    toast('Gagal menyalin: ' + (e.message || e))
  }
}

onMounted(load)
</script>

<template>
  <div class="card">
    <h2>Tentang</h2>
    <p class="muted" style="line-height:1.7">
      Modul tuning kecil untuk KernelSU (kompatibel Magisk). Filosofinya:
      <b>deteksi, jangan tebak</b>; <b>change, jangan hardcode</b>; <b>restore, jangan rusak</b>.
    </p>
    <ul class="list">
      <li>Tidak ada path perangkat yang di-hardcode — policy CPU/GPU dicari saat runtime.</li>
      <li>Nilai awal di-capture ke <code>baseline.tsv</code> dan dipakai ulang saat uninstall / Reset.</li>
      <li>Tidak menyentuh node charging, thermal, LMK, sepolicy, atau modul lain.</li>
      <li>WebUI ini Vue SFC yang di-compile jadi aset statis lokal — tanpa CDN.</li>
    </ul>
  </div>

  <div class="card">
    <h2>Config</h2>
    <pre class="raw">{{ cfg }}</pre>
    <h2 style="margin-top:14px">Baseline otomatis</h2>
    <pre class="raw">{{ base }}</pre>
    <h2 style="margin-top:14px">Hasil apply terakhir</h2>
    <pre class="raw">{{ last }}</pre>
    <div class="btnrow" style="margin-top:12px">
      <button class="btn ghost" @click="copyConfig">Salin config</button>
      <button class="btn ghost" @click="load">Refresh</button>
    </div>
  </div>
</template>

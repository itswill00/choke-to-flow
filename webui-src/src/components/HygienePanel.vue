<script setup>
import { onMounted, ref } from 'vue'
import { core, exec, modDir, parseTSV } from '../lib/bridge'

const modules = ref([])
const count = ref('—')
const hookFails = ref('—')
const SUSPECT = ['zygisk', 'lsposed', 'hyperceiler', 'hma', 'teesim', 'detach', 'integrity', 'deviceid']

function isSuspect(id) {
  return SUSPECT.some((s) => String(id).toLowerCase().includes(s))
}

async function load() {
  const parent = modDir.value.replace(/\/[^\/]+$/, '')
  const cmd =
    'for f in ' + parent + '/*/module.prop; do ' +
    'id=$(grep -m1 "^id=" "$f" | cut -d= -f2-); ' +
    'nm=$(grep -m1 "^name=" "$f" | cut -d= -f2-); ' +
    'ver=$(grep -m1 "^version=" "$f" | cut -d= -f2-); ' +
    'st=ACTIVE; [ -f "${f%/module.prop}/disable" ] && st=DISABLED; ' +
    "printf '%s\\t%s\\t%s\\t%s\\n' \"$id\" \"$nm\" \"$ver\" \"$st\"; done"
  try {
    const out = await exec(cmd)
    modules.value = parseTSV(out).map((r) => ({
      id: r[0] || '?', name: r[1] || r[0], version: r[2] || '', state: r[3] || '',
      flag: isSuspect(r[0]),
    }))
    count.value = String(modules.value.length)
    const st = parseTSV(await core('status'))
    const row = st.find((r) => r[0] === 'lsposed_hook_fail')
    hookFails.value = row ? row.slice(1).join('') : '—'
  } catch (_) { /* leave placeholders */ }
}

onMounted(load)
</script>

<template>
  <div class="card">
    <div class="card-head">
      <div>
        <h2>Installed modules</h2>
        <p class="muted">Daftar saja. Modul ini <b>tidak pernah</b> menonaktifkan modul lain.</p>
      </div>
      <span class="pill">{{ count }} modul</span>
    </div>
    <div class="mods">
      <div v-for="m in modules" :key="m.id" class="mod" :class="{ flag: m.flag && m.state === 'ACTIVE' }">
        <div>
          <div class="nm">{{ m.name }}</div>
          <div class="id">{{ m.id }} <span v-if="m.version"> · {{ m.version }}</span></div>
        </div>
        <span class="pill" :style="m.state === 'DISABLED' ? '' : 'color:var(--accent)'">{{ m.state }}</span>
      </div>
      <div v-if="!modules.length" class="loading">Memuat…</div>
    </div>
  </div>

  <div class="card warn">
    <h2>Catatan penting</h2>
    <p>
      Modul ber-highlight kuning karena <b>Hook Failed</b> tercatat {{ hookFails }} kali pada boot ini
      (dari log LSPosed). Kombinasi HyperCeiler + beberapa backend Zygisk aktif bersamaan
      memberi beban nyata ke <code>system_server</code>.
    </p>
    <p class="muted">Modul ini tidak menyentuhnya — matikan / sesuaikan manual lewat manager. Arus pengisian juga sengaja tidak disentuh (urusan safety BMS).</p>
  </div>
</template>

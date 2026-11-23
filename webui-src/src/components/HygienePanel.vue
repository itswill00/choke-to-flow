<script setup>
import { computed, onMounted, ref } from 'vue'
import { core, exec, initBridge, modDir, parseTSV } from '../lib/bridge'

const modules = ref([])
const hookFails = ref('—')

const SUSPECT = ['zygisk', 'lsposed', 'hyperceiler', 'hma', 'teesim', 'detach', 'integrity', 'deviceid']

const activeCount = computed(() => modules.value.filter((m) => m.state === 'ACTIVE').length)
const flaggedCount = computed(
  () => modules.value.filter((m) => m.flag && m.state === 'ACTIVE').length,
)
const sorted = computed(() =>
  [...modules.value].sort((a, b) => {
    const fa = a.flag && a.state === 'ACTIVE' ? 0 : a.state === 'ACTIVE' ? 1 : 2
    const fb = b.flag && b.state === 'ACTIVE' ? 0 : b.state === 'ACTIVE' ? 1 : 2
    return fa - fb || a.name.localeCompare(b.name)
  }),
)

const isSuspect = (id) => SUSPECT.some((s) => String(id).toLowerCase().includes(s))

async function load() {
  const parent = modDir.value.replace(/\/[^/]+$/, '')
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
      id: r[0] || '?',
      name: r[1] || r[0],
      version: r[2] || '',
      state: r[3] || '',
      flag: isSuspect(r[0]),
    }))
    const st = parseTSV(await core('status'))
    const row = st.find((r) => r[0] === 'lsposed_hook_fail')
    hookFails.value = row ? row.slice(1).join('') : '—'
  } catch (_) {
    /* keep placeholders */
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
        <div class="panel-title">Modules</div>
        <div class="panel-sub">Read-only inventory. This module never disables or reorders another module.</div>
      </div>
      <span class="pill">{{ modules.length }} installed</span>
    </div>
    <div class="panel-body">
      <div class="summary-grid">
        <div class="summary-cell">
          <div class="k">Active</div>
          <div class="v">{{ activeCount }}</div>
        </div>
        <div class="summary-cell">
          <div class="k">Highlighted</div>
          <div class="v" :class="{ warn: flaggedCount > 0 }">{{ flaggedCount }}</div>
        </div>
        <div class="summary-cell">
          <div class="k">Hook failures</div>
          <div class="v" :class="{ warn: Number(hookFails) > 0 }">{{ hookFails }}</div>
        </div>
      </div>

      <div class="table-wrap">
        <table class="table">
          <thead>
            <tr>
              <th>Module</th>
              <th>ID</th>
              <th>Version</th>
              <th>State</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="m in sorted"
              :key="m.id"
              :class="{ flagged: m.flag && m.state === 'ACTIVE' }"
            >
              <td>
                {{ m.name }}
                <span v-if="m.flag && m.state === 'ACTIVE'" class="pill flag" style="margin-left:6px">hook</span>
              </td>
              <td class="id">{{ m.id }}</td>
              <td class="muted">{{ m.version || '—' }}</td>
              <td>
                <span class="pill" :class="m.state === 'ACTIVE' ? 'active' : 'disabled'">
                  {{ m.state || '—' }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-if="!modules.length" class="state">Loading modules…</div>
      </div>

      <div class="note" style="margin-top: 14px">
        Modules marked <b>hook</b> are listed because they matched known hooking frameworks.
        LSPosed reported {{ hookFails }} hook failures in the current boot. Review them manually
        in your root manager — this screen intentionally has no disable action.
      </div>
    </div>
  </section>
</template>

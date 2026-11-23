import { ref } from 'vue'

export const modDir = ref('')
export const bridgeError = ref('')
export const deviceLine = ref('Mendeteksi perangkat…')

const KNOWN_ID = 'choke-to-flow'

function ksu() {
  return typeof window !== 'undefined' ? window.ksu : null
}

/** Run a root shell command through the KernelSU WebUI bridge. */
export async function exec(cmd) {
  const api = ksu()
  if (api && typeof api.exec === 'function') {
    return await new Promise((resolve, reject) => {
      const cb = '__tt_cb_' + Math.random().toString(36).slice(2)
      window[cb] = (code, stdout, stderr) => {
        try { delete window[cb] } catch (_) { window[cb] = undefined }
        if (code === 0 || typeof stdout === 'string') resolve(stdout)
        else reject(new Error(stderr || 'exit ' + code))
      }
      try { api.exec(cmd, cb) } catch (e) { reject(e) }
    })
  }
  // Fallback for managers that expose only the npm-style helper.
  for (const spec of ['kernelsu', 'https://mui.kernelsu.org/kernelsu.js']) {
    try {
      const m = await import(/* @vite-ignore */ spec)
      const r = await m.exec(cmd)
      return r.stdout || ''
    } catch (_) { /* try next */ }
  }
  throw new Error('WebUI bridge tidak tersedia. Buka halaman ini lewat KernelSU manager.')
}

export async function core(args) {
  return (await exec(modDir.value + '/lib/core.sh ' + args)).trim()
}

export function parseTSV(text) {
  return String(text || '')
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('#'))
    .map((l) => l.split('\t'))
}

async function discoverDir() {
  try {
    const r = await fetch('./moddir.txt', { cache: 'no-store' })
    if (r.ok) {
      const p = (await r.text()).trim()
      if (p.startsWith('/')) return p
    }
  } catch (_) { /* normal in some WebViews */ }
  try {
    const api = ksu()
    if (api && typeof api.moduleInfo === 'function') {
      const info = JSON.parse(api.moduleInfo())
      if (info.path) return info.path
      if (info.id) return '/data/adb/modules/' + info.id
    }
  } catch (_) { /* ignore */ }
  return '/data/adb/modules/' + KNOWN_ID
}

export async function initBridge() {
  try {
    modDir.value = await discoverDir()
    const up = await core('status')
    const m = {}
    parseTSV(up).forEach((row) => { m[row[0]] = row.slice(1).join('\t') })
    deviceLine.value = [m.device, m.rom].filter(Boolean).join(' · ') || modDir.value
    bridgeError.value = ''
  } catch (e) {
    bridgeError.value = e.message || String(e)
    deviceLine.value = 'Bridge error'
  }
}

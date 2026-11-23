export const KEY_META = {
  cpu_little_max: {
    group: 'CPU',
    label: 'Efficiency cluster · maximum',
    desc: 'Upper frequency cap for the little cores.',
  },
  cpu_little_min: {
    group: 'CPU',
    label: 'Efficiency cluster · minimum',
    desc: 'Frequency floor used when the cluster wakes up.',
  },
  cpu_big_max: {
    group: 'CPU',
    label: 'Performance cluster · maximum',
    desc: 'Upper frequency cap for the big cores.',
  },
  cpu_big_min: {
    group: 'CPU',
    label: 'Performance cluster · minimum',
    desc: 'Frequency floor used when the cluster wakes up.',
  },
  gpu_max: {
    group: 'GPU',
    label: 'GPU · maximum',
    desc: 'Upper devfreq step exposed by the GPU driver.',
  },
  swappiness: {
    group: 'Memory',
    label: 'VM swappiness',
    desc: 'How aggressively anonymous pages are pushed into zram.',
  },
  anim_window: {
    group: 'Interface',
    label: 'Window animation scale',
    desc: 'Android global window animation duration multiplier.',
  },
  anim_transition: {
    group: 'Interface',
    label: 'Transition animation scale',
    desc: 'Activity transition animation duration multiplier.',
  },
  animator_duration: {
    group: 'Interface',
    label: 'Animator duration scale',
    desc: 'Property animator duration multiplier.',
  },
}

export const GROUP_ORDER = ['CPU', 'GPU', 'Memory', 'Interface', 'Other']

export function meta(key) {
  return KEY_META[key] || {
    group: 'Other',
    label: String(key).replace(/_/g, ' '),
    desc: '',
  }
}

export const TELEMETRY_META = {
  device: { label: 'Device', group: 'System' },
  rom: { label: 'Build', group: 'System' },
  uptime_s: { label: 'Uptime', group: 'System' },
  module_count: { label: 'Active modules', group: 'System' },
  lsposed_hook_fail: { label: 'Hook failures', group: 'System' },
  load: { label: 'Load average', group: 'CPU' },
  cpu_little_cur_khz: { label: 'Little · current', group: 'CPU' },
  cpu_little_cap_khz: { label: 'Little · cap', group: 'CPU' },
  cpu_little_hw_khz: { label: 'Little · hardware', group: 'CPU' },
  cpu_big_cur_khz: { label: 'Big · current', group: 'CPU' },
  cpu_big_cap_khz: { label: 'Big · cap', group: 'CPU' },
  cpu_big_hw_khz: { label: 'Big · hardware', group: 'CPU' },
  temp_soc_c: { label: 'SoC', group: 'Thermal' },
  temp_skin_c: { label: 'Skin', group: 'Thermal' },
  temp_batt_c: { label: 'Battery', group: 'Thermal' },
  zram_used_kb: { label: 'Zram used', group: 'Memory' },
  zram_total_kb: { label: 'Zram total', group: 'Memory' },
  mem_avail_kb: { label: 'Available', group: 'Memory' },
  mem_free_kb: { label: 'Free', group: 'Memory' },
  charge_now_ua: { label: 'Charge current', group: 'Power' },
  battery_pct: { label: 'Battery level', group: 'Power' },
  charge_limit: { label: 'Charge limit', group: 'Power' },
}

export const TELEMETRY_GROUPS = ['Thermal', 'Memory', 'CPU', 'Power', 'System']

export function telemetryMeta(key) {
  return TELEMETRY_META[key] || { label: String(key).replace(/_/g, ' '), group: 'System' }
}

export function human(value, unit) {
  if (value === null || value === undefined || value === '') return '—'
  const n = Number(value)
  if (!Number.isFinite(n)) return String(value)
  if (unit === 'kHz') {
    return Math.abs(n) >= 1e6 ? (n / 1e6).toFixed(2) + ' GHz' : (n / 1000).toFixed(0) + ' MHz'
  }
  if (unit === 'x') return n.toFixed(2) + '×'
  return String(value)
}

export function fmtTelemetry(key, raw) {
  if (raw === '?' || raw === '' || raw === null || raw === undefined) return '—'
  const n = Number(raw)
  if (!Number.isFinite(n)) return String(raw)
  if (key === 'uptime_s') return Math.round(n / 60) + ' min'
  if (key.endsWith('_kb')) return (n / 1024).toFixed(0) + ' MB'
  if (key.endsWith('_khz')) return (n / 1000).toFixed(2) + ' GHz'
  if (key.endsWith('_ua')) return (n / 1e6).toFixed(2) + ' A'
  if (key.endsWith('_c')) return n.toFixed(1) + ' °C'
  if (key === 'battery_pct') return n + ' %'
  return String(raw)
}

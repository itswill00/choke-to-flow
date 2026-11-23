<script setup>
import { onMounted, ref } from 'vue'
import { initBridge, deviceLine, bridgeError } from './lib/bridge'
import { toastMessage } from './lib/toast'
import TunePanel from './components/TunePanel.vue'
import TelemetryPanel from './components/TelemetryPanel.vue'
import HygienePanel from './components/HygienePanel.vue'
import AboutPanel from './components/AboutPanel.vue'

const tabs = [
  { id: 'tuning', label: 'Tuning' },
  { id: 'telemetry', label: 'Telemetry' },
  { id: 'modules', label: 'Modules' },
  { id: 'about', label: 'About' },
]
const active = ref('tuning')

onMounted(initBridge)
</script>

<template>
  <div class="topbar">
    <header class="appbar">
      <div class="brand">
        <div class="mark">C2F</div>
        <div class="brand-text">
          <div class="wordmark">Choke to Flow</div>
          <div class="sub">System tuner · KernelSU / Magisk</div>
        </div>
      </div>
      <div class="device-chip" :title="deviceLine">{{ deviceLine }}</div>
    </header>

    <nav class="segmented" role="tablist">
      <button
        v-for="t in tabs"
        :key="t.id"
        type="button"
        :class="{ active: active === t.id }"
        @click="active = t.id"
      >{{ t.label }}</button>
    </nav>
  </div>

  <main class="content">
    <TunePanel v-show="active === 'tuning'" />
    <TelemetryPanel v-show="active === 'telemetry'" :active="active === 'telemetry'" />
    <HygienePanel v-show="active === 'modules'" />
    <AboutPanel v-show="active === 'about'" />
  </main>

  <footer class="footer">Reversible by design · no charging, thermal, LMK, or module kill switches</footer>

  <div v-if="bridgeError" class="banner error">{{ bridgeError }}</div>
  <div v-if="toastMessage" class="toast">{{ toastMessage }}</div>
</template>

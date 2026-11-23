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
  { id: 'hygiene', label: 'Module Hygiene' },
  { id: 'about', label: 'About' },
]
const active = ref('tuning')

onMounted(initBridge)
</script>

<template>
  <header class="hero">
    <div class="hero-row">
      <div class="logo">TT</div>
      <div>
        <h1>Choke to Flow</h1>
        <div class="hero-sub">{{ deviceLine }}</div>
      </div>
    </div>
    <div class="hero-note">Dari <em>dicekik</em> jadi lancar. Default = AUTO, baseline otomatis dipulihkan saat uninstall / Reset.</div>
  </header>

  <nav class="tabs">
    <button
      v-for="t in tabs"
      :key="t.id"
      class="tabbtn"
      :class="{ active: active === t.id }"
      @click="active = t.id"
    >{{ t.label }}</button>
  </nav>

  <main>
    <TunePanel v-show="active === 'tuning'" />
    <TelemetryPanel v-show="active === 'telemetry'" :active="active === 'telemetry'" />
    <HygienePanel v-show="active === 'hygiene'" />
    <AboutPanel v-show="active === 'about'" />
  </main>

  <div v-if="bridgeError" class="errbox" style="margin: 0 16px 16px">
    {{ bridgeError }}
  </div>
  <div v-if="toastMessage" class="toast">{{ toastMessage }}</div>
</template>

# Changelog

## 1.0.0 (unreleased)
- Initial prototype.
- Vue 3 SFC WebUI compiled with Vite into local static assets (no CDN).
- Runtime detection for CPU cpufreq policies and GPU devfreq.
- Adjustable tunables: CPU min/max, GPU max, swappiness, animation scales.
- AUTO by default; every change reversible via captured baseline.
- `last_apply.tsv` verification per tunable.
- `build.sh`: build, package, deploy, push, apply, status, log, check.
- Name/ID finalized: `choke-to-flow`.

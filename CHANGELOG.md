# Changelog

## 1.0.0 (unreleased)
- Initial prototype.
- Vue 3 SFC WebUI compiled with Vite into local static assets (no CDN).
- Runtime detection for CPU cpufreq policies and GPU devfreq.
- Adjustable tunables: CPU min/max, GPU max, swappiness, animation scales.
- AUTO by default; every change reversible via captured baseline.
- `last_apply.tsv` verification per tunable.
- `build.sh`: build, package, deploy, push, apply, dry, test, status, log, check.
- Offline test harness: fake sysfs + fake `settings`, 47 assertions.
- `TT_DRY_RUN=1` and `--dry-run` support in `core.sh`; `build.sh dry`.
- Path indirection via `TT_ROOT`; settings binary via `TT_SETTINGS_BIN`.
- Release ZIP now emits `.sha256`.
- GitHub Actions CI: syntax check, harness, Vite build, package, artifact.
- Name/ID finalized: `choke-to-flow`.

# Choke to Flow

[![ci](https://github.com/itswill00/choke-to-flow/actions/workflows/ci.yml/badge.svg)](https://github.com/itswill00/choke-to-flow/actions/workflows/ci.yml)

> *Dari dicekik jadi lancar.*

Modul KernelSU (kompatibel Magisk) untuk tuning **adjustable + reversible** pada Redmi Note 13 5G / **tanzanite** (MT6789) dan sekitarnya. WebUI-nya ditulis dengan Vue SFC lalu di-compile jadi aset statis lokal — tanpa CDN, tanpa runtime template compiler.

## Kenapa nama ini

Nama sengaja mengikuti pola repo `lizzy-to-lana`: **dari kondisi A ke kondisi B**. Awal proyek ini adalah keluhan "performanya rasanya kayak di cekik", jadi *choke → flow* adalah ringkasan tujuannya sekaligus identitas yang mudah diingat komunitas.

ID module permanen: **`choke-to-flow`**.

## Prinsip

- **Deteksi, jangan tebak** — policy CPU dan devfreq GPU dicari saat runtime, tidak ditulis tetap di kode.
- **Semua nilai bisa diatur** — default `AUTO` = modul tidak menyentuh apa pun.
- **Selalu reversible** — nilai awal di-capture ke `state/baseline.tsv`; tombol *Reset ke baseline* dan uninstall memakai file itu.
- **Tidak ikut campur** — tidak menyentuh node charging, thermal, LMK, sepolicy; tidak menonaktifkan modul lain.
- **Transparan** — `last_apply.tsv` mencatat tiap tweak sebagai `OK` atau `FAIL`.

## Struktur

```
choke-to-flow/
├── build.sh              # helper: build / package / deploy / push / apply / status
├── module.prop
├── skip_mount
├── customize.sh          # installer: perms, moddir.txt, hot-install
├── service.sh            # late_start: apply_all
├── boot-completed.sh     # apply ulang sekali setelah boot
├── hotinstall.sh         # apply langsung saat hot install
├── action.sh             # tombol Action di manager
├── uninstall.sh          # restore baseline
├── lib/core.sh           # detect / bounds / set / apply / restore / status
├── defaults/config.tsv   # config bawaan (semua AUTO)
├── state/                # runtime (diabaikan git, dibuat installer)
├── webroot/              # HASIL BUILD Vue — jangan edit manual
├── webui-src/            # source Vue (.vue)
├── tests/                # test harness offline (fake sysfs + fake settings)
├── tools/sync.py         # sync workspace -> modul terinstall
├── .github/workflows/    # CI: test, build, package, artifact
├── LICENSE
└── ROADMAP.md
```

## Build & deploy

```sh
./build.sh test       # test harness offline (tanpa root, tanpa perangkat)
./build.sh build      # compile WebUI saja
./build.sh package    # build + ZIP flashable + .sha256
./build.sh deploy     # build + ZIP + ksud module install (hot install, tanpa reboot)
./build.sh push       # sync file ke modul yang sudah terinstall + apply (tanpa reboot)
./build.sh apply      # apply + tampilkan hasil verifikasi
./build.sh dry        # simulasi apply (TT_DRY_RUN=1), nol tulisan ke perangkat
./build.sh status     # telemetry
./build.sh log        # tail apply.log
./build.sh check      # cek workspace/target/root
```

## Testing offline

`tests/run.sh` membangun **fake sysfs + fake `settings`** di direktori temp, lalu menguji `detect`, `bounds`, clamp, baseline, `apply`, dry-run, `restore`, dan telemetry. Tidak butuh root dan tidak menyentuh perangkat.

```sh
sh tests/run.sh        # 47 assertion
```

Environment hooks yang dipakai harness (kosong = perangkat asli):

| Var | Fungsi |
|---|---|
| `TT_ROOT` | prefix untuk `/sys`, `/proc`, `/data/adb` |
| `TT_SETTINGS_BIN` | binary `settings` alternatif |
| `TT_SETTINGS_DB` | DB untuk fake `settings` |
| `TT_DRY_RUN=1` | `write_target` hanya mencetak niat, tidak menulis |

`TT_DRY_RUN=1 sh lib/core.sh apply` juga bisa dipakai langsung di perangkat untuk simulasi.

## WebUI

- **Tuning** — toggle AUTO/CUSTOM + slider & angka, lalu **Apply now**.
- **Presets** — `Stock / AUTO`, `Balanced`, `Performance`. Hanya mengisi form.
- **Telemetry** — suhu, zram, frekuensi, arus cas, jumlah modul, jumlah `Hook Failed`.
- **Module Hygiene** — daftar modul (read-only, tidak ada tombol disable).
- **About** — config, baseline, dan hasil apply terakhir.

## Parameter

| Key | Sumber batas | Catatan |
|---|---|---|
| `cpu_little_max`, `cpu_little_min` | `cpuinfo_min_freq` / `cpuinfo_max_freq` policy kecil | deteksi otomatis |
| `cpu_big_max`, `cpu_big_min` | idem, policy besar | deteksi otomatis |
| `gpu_max` | `available_frequencies` devfreq GPU | deteksi otomatis |
| `swappiness` | 0–200 | naik = lebih banyak zram |
| `anim_window`, `anim_transition`, `animator_duration` | 0–2 | settings global Android |

## Status saat ini

Prototype. Validasi yang sudah lewat:

- `sh -n` untuk semua skrip (BusyBox ash di Termux, `sh` di CI).
- **47 assertion** offline di `tests/run.sh`: detect, bounds, clamp, baseline, dry-run, apply, restore, telemetry.
- Clamp diuji: input `99999999` → `2000000`; input `1` → `725000`.
- Mode invalid & key tak dikenal ditolak.
- Baseline `null` → sentinel `__unset__`, restore memakai `settings delete`.
- Build Vite + path aset relatif (`./assets/...`), CI build & package + checksum.

**Belum diuji dengan install ke perangkat.** Belum ada perubahan sysfs/settings yang dilakukan selama pengembangan.

## Catatan inspection awal

Cap CPU sempat terbaca 1,7/1,8 GHz, lalu pada validasi berikutnya sudah 2,0/2,2 GHz (hardware max). Jadi cap itu dinamis, bukan limit permanen. Suhu 54 °C SoC / 37 °C baterai — bukan thermal throttling. Baseline akan merekam nilai apa pun yang berlaku saat first boot.

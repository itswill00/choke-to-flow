# Roadmap

Status: prototype — belum diuji dengan install ke perangkat.

## Milestone 0 — Identitas ✅
- [x] Nama final & ID permanen: `choke-to-flow`
- [x] Repo GitHub `itswill00/choke-to-flow`
- [x] LICENSE, README, build helper

## Milestone 1 — Test harness ✅
- [x] Fake sysfs tree untuk uji `detect` / `bounds` / `apply` / `restore` tanpa perangkat
- [x] Mode `dry-run` di `core.sh` (cetak aksi, jangan tulis)
- [x] Test otomatis: clamp, mode invalid, baseline null sentinel, restore (47 assertion)
- [x] CI job yang menjalankan tes + build ZIP + checksum

## Milestone 2 — Uji nyata (butuh izin eksplisit)
- [ ] Install via KernelSU manager / `build.sh deploy`
- [ ] Buka WebUI, cek deteksi path & batas
- [ ] Apply satu per satu, cek `last_apply.tsv` = OK
- [ ] Reboot, cek `service.sh` + `boot-completed.sh`
- [ ] Uninstall, verifikasi nilai kembali ke baseline
- [ ] Uji hot-install & `build.sh push`

## Milestone 3 — Kualitas rilis komunitas
- [x] WebUI redesign: inset/status-bar, layout console, telemetry & module tables
- [x] Restore berbasis `touched.tsv` (tidak menimpa node yang tidak disentuh)
- [x] `build.sh activate` + `push` yang preserve runtime state
- [ ] Error handling SELinux saat write sysfs (notifikasi di WebUI)
- [ ] Konfirmasi dua langkah untuk preset `Performance` & `Reset ke baseline`
- [ ] Ekspor/impor config via file (selain clipboard)
- [ ] Changelog + `updateJson`
- [ ] FAQ: kompatibilitas ROM, risiko, cara recover

## Milestone 4 — Rilis
- [ ] Tag `v1.0.0`
- [ ] Review komunitas tanzanite
- [ ] Publish ZIP + checksum di GitHub Releases

## Non-goal
- Tidak akan menyentuh batas arus cas / charging safety.
- Tidak akan auto-disable modul lain.
- Tidak akan jadi "all-in-one magisk toolbox".

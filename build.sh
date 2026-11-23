#!/data/data/com.termux/files/usr/bin/bash
# Choke to Flow — build / package / deploy helper
# Run from Termux:  ./build.sh <command>
set -euo pipefail

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
MODID=$(grep -m1 '^id=' "$HERE/module.prop" | cut -d= -f2-)
TARGET=/data/adb/modules/$MODID
ZIP="$HERE/$MODID.zip"
PY=$(command -v python3)
SH=${SH:-sh}

root() { su -c "$1"; }

require_root() {
  if ! root 'id -u' >/dev/null 2>&1; then
    echo "ERR: butuh akses root (su). Jalankan dari Termux dengan root tersedia." >&2
    exit 1
  fi
}

build_ui() {
  if [ "${TT_SKIP_BUILD:-0}" = "1" ]; then
    echo "[build] skipped (TT_SKIP_BUILD=1)"
    return 0
  fi
  echo "[build] Vue SFC -> webroot (Vite, offline assets)"
  (cd "$HERE/webui-src" && npm run build)
}

make_zip() {
  build_ui
  echo "[package] $ZIP"
  "$PY" - "$HERE" "$ZIP" <<'PY'
import hashlib, os, sys, zipfile
src, out = sys.argv[1], sys.argv[2]
skip_dirs = {"webui-src", "node_modules", "__pycache__", ".git", ".github", "tests", "tools"}
skip_files = {"build.sh", "README.md", "ROADMAP.md", "CHANGELOG.md", "LICENSE", ".gitignore"}
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for root, dirs, files in os.walk(src):
        dirs[:] = [d for d in dirs if d not in skip_dirs]
        for f in files:
            if f in skip_files or f.endswith(".zip") or f.endswith(".sha256"):
                continue
            p = os.path.join(root, f)
            z.write(p, os.path.relpath(p, src))
h = hashlib.sha256(open(out, "rb").read()).hexdigest()
with open(out + ".sha256", "w") as fh:
    fh.write(h + "  " + os.path.basename(out) + "\n")
print("created:", out)
print("sha256 :", h)
PY
  ls -lh "$ZIP" "$ZIP.sha256"
}

run_tests() {
  echo "[test] offline harness (fake sysfs + fake settings)"
  "$SH" "$HERE/tests/run.sh"
}

dry_run() {
  require_root
  [ -d "$TARGET" ] || { echo "ERR: modul belum terinstall. Pakai: $0 deploy"; exit 1; }
  echo "[dry] TT_DRY_RUN=1 — tidak menulis apa pun ke perangkat"
  root "TT_DRY_RUN=1 sh '$TARGET/lib/core.sh' apply"
  echo "[dry] report"
  root "sh '$TARGET/lib/core.sh' last"
}

apply_now() {
  require_root
  [ -d "$TARGET" ] || { echo "ERR: modul belum terinstall. Pakai: $0 deploy"; exit 1; }
  echo "[apply] $TARGET/lib/core.sh apply"
  root "sh '$TARGET/lib/core.sh' apply"
  echo "[verify] last_apply.tsv"
  root "sh '$TARGET/lib/core.sh' last"
}

deploy() {
  require_root
  make_zip
  echo "[deploy] ksud module install '$ZIP'"
  echo "         customize.sh meminta hot-install -> seharusnya tanpa reboot."
  root "ksud module install '$ZIP'"
  echo "[done] cek WebUI / 'build.sh status' untuk memastikan."
}

push_files() {
  require_root
  [ -d "$TARGET" ] || { echo "ERR: modul belum terinstall. Pakai: $0 deploy"; exit 1; }
  build_ui
  echo "[push] sync workspace -> $TARGET (tanpa install ulang, tanpa reboot)"
  root "$PY '$HERE/tools/sync.py' '$HERE' '$TARGET'"
  root "chcon -R --reference='$TARGET/module.prop' '$TARGET' 2>/dev/null || true"
  apply_now
}

show_status() {
  require_root
  [ -d "$TARGET" ] || { echo "modul belum terinstall di $TARGET"; exit 0; }
  root "sh '$TARGET/lib/core.sh' status"
}

show_log() {
  require_root
  [ -d "$TARGET" ] || { echo "modul belum terinstall di $TARGET"; exit 0; }
  root "tail -n 40 '$TARGET/state/apply.log'"
}

check() {
  echo "workspace : $HERE"
  echo "module id : $MODID"
  echo "target    : $TARGET"
  if [ -d "$TARGET" ]; then echo "installed : YES"; else echo "installed : NO"; fi
  echo "zip       : $ZIP"
  if [ -f "$HERE/webroot/index.html" ]; then echo "webui     : built"; else echo "webui     : MISSING"; fi
  if root 'id -u' >/dev/null 2>&1; then echo "root      : YES"; else echo "root      : NO"; fi
}

help() {
  cat <<EOF
Choke to Flow — build helper

Usage:
  ./build.sh test       Jalankan test harness offline (tanpa root / tanpa perangkat)
  ./build.sh build      Build WebUI Vue saja (npm run build -> webroot/)
  ./build.sh package    Build + ZIP flashable + .sha256 di $ZIP
  ./build.sh deploy     Build + ZIP + ksud module install (hot install, tanpa reboot)
  ./build.sh push       Sync file workspace ke modul yang SUDAH terinstall + apply
                        (paling cepat untuk update WebUI/script, tanpa reboot)
  ./build.sh apply      Jalankan core.sh apply di modul terinstall + tampilkan hasilnya
  ./build.sh dry        Simulasi apply (TT_DRY_RUN=1), tidak menulis ke perangkat
  ./build.sh status     Tampilkan telemetry dari modul terinstall
  ./build.sh log        Tail apply.log (40 baris terakhir)
  ./build.sh check      Cek workspace, target, root, dan status build
  ./build.sh help       Tampilkan ini

Alias: install=deploy, sync=push, zip=package, harness=test
EOF
}

case "${1:-help}" in
  test|harness)       run_tests ;;
  build)              build_ui ;;
  package|zip)        make_zip ;;
  deploy|install)     deploy ;;
  push|sync)          push_files ;;
  apply)              apply_now ;;
  dry)                dry_run ;;
  status)             show_status ;;
  log)                show_log ;;
  check)              check ;;
  help|-h|--help)     help ;;
  *)                  echo "unknown command: $1"; help; exit 1 ;;
esac

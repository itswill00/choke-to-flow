#!/bin/sh
# Offline test harness — no root, no real sysfs, no device writes.
set -u

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
MOD=$(cd -- "$HERE/.." && pwd)
SH=${SH:-sh}

WORK=$(mktemp -d "${TMPDIR:-/tmp}/c2f-test.XXXXXX" 2>/dev/null) || {
    WORK="${TMPDIR:-/tmp}/c2f-test.$$"
    mkdir -p "$WORK"
}
trap 'rm -rf "$WORK"' EXIT INT TERM

SANDBOX="$WORK/mod"
ROOT="$WORK/root"
SETDB="$WORK/settings.db"

mkdir -p "$SANDBOX/state" "$ROOT" "$WORK/bin"
cp -R "$MOD/lib" "$SANDBOX/lib"
cp -R "$MOD/defaults" "$SANDBOX/defaults"
cp "$MOD/module.prop" "$SANDBOX/module.prop"
cp "$MOD/defaults/config.tsv" "$SANDBOX/state/config.tsv"
printf '# key\tpath\tkind\n' > "$SANDBOX/state/targets.tsv"
printf '# key\tvalue\n' > "$SANDBOX/state/baseline.tsv"
printf '# key\toriginal\n' > "$SANDBOX/state/touched.tsv"
printf '# key\tstatus\trequested\tactual\n' > "$SANDBOX/state/last_apply.tsv"

cp "$HERE/fixtures/settings" "$WORK/bin/settings"
chmod +x "$WORK/bin/settings"
: > "$SETDB"
printf 'window_animation_scale\t1.0\n' >> "$SETDB"
printf 'transition_animation_scale\t1.0\n' >> "$SETDB"

export TT_ROOT="$ROOT"
export TT_SETTINGS_BIN="$WORK/bin/settings"
export TT_SETTINGS_DB="$SETDB"

run_core() {
    MODDIR="$SANDBOX" "$SH" "$SANDBOX/lib/core.sh" "$@"
}
run_core_dry() {
    MODDIR="$SANDBOX" TT_DRY_RUN=1 "$SH" "$SANDBOX/lib/core.sh" "$@"
}

mkfile() {
    mkdir -p "$(dirname -- "$1")"
    printf '%s\n' "$2" > "$1"
}

# ------------------------------------------------------------- fake tree ----
P0="$ROOT/sys/devices/system/cpu/cpufreq/policy0"
P6="$ROOT/sys/devices/system/cpu/cpufreq/policy6"
mkfile "$P0/cpuinfo_min_freq" 500000
mkfile "$P0/cpuinfo_max_freq" 2000000
mkfile "$P0/scaling_min_freq" 500000
mkfile "$P0/scaling_max_freq" 1700000
mkfile "$P0/scaling_cur_freq" 1700000
mkfile "$P6/cpuinfo_min_freq" 725000
mkfile "$P6/cpuinfo_max_freq" 2200000
mkfile "$P6/scaling_min_freq" 725000
mkfile "$P6/scaling_max_freq" 1800000
mkfile "$P6/scaling_cur_freq" 1800000

GPU="$ROOT/sys/class/devfreq/13000000.mali"
mkfile "$GPU/name" "13000000.mali"
mkfile "$GPU/available_frequencies" "1003000000 990000000 390000000"
mkfile "$GPU/max_freq" 1003000000
mkfile "$GPU/cur_freq" 390000000

mkfile "$ROOT/proc/sys/vm/swappiness" 100
mkfile "$ROOT/proc/uptime" "1000.00 2000.00"
mkfile "$ROOT/proc/loadavg" "1.00 1.00 1.00 1/100 1234"
cat > "$ROOT/proc/meminfo" <<'EOF'
MemTotal:        7822924 kB
MemFree:          100000 kB
MemAvailable:    2500000 kB
SwapTotal:       6291452 kB
SwapFree:        4291452 kB
EOF

mkfile "$ROOT/sys/class/thermal/thermal_zone0/temp" 54000
mkfile "$ROOT/sys/class/thermal/thermal_zone16/temp" 40000
BATT="$ROOT/sys/class/power_supply/battery"
mkfile "$BATT/temp" 370
mkfile "$BATT/current_now" -1000000
mkfile "$BATT/capacity" 50
mkfile "$BATT/uevent" "POWER_SUPPLY_CHARGE_CONTROL_LIMIT=8"

mkdir -p "$ROOT/data/adb/modules/modA" "$ROOT/data/adb/modules/modB" "$ROOT/data/adb/lspd/log"
printf 'id=modA\nname=Mod A\nversion=1\n' > "$ROOT/data/adb/modules/modA/module.prop"
printf 'id=modB\nname=Mod B\nversion=2\n' > "$ROOT/data/adb/modules/modB/module.prop"
printf 'Hook Failed\nHook Failed\nHook Failed\n' > "$ROOT/data/adb/lspd/log/modules_test.log"

# -------------------------------------------------------------- asserts -----
PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '       %s\n' "$2"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected [$3] | got [$2]"; fi; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "missing [$3] | got [$2]" ;; esac; }
hasnt() { case "$2" in *"$3"*) bad "$1" "unexpected [$3]" ;; *) ok "$1" ;; esac; }
section() { printf '\n[%s]\n' "$1"; }

cfgval() {
    awk -F '\t' -v k="$1" '$1==k { print $2 "\t" $3 }' "$SANDBOX/state/config.tsv"
}
lastrow() {
    awk -F '\t' -v k="$1" '$1==k { print $2 "\t" $3 "\t" $4 }' "$SANDBOX/state/last_apply.tsv"
}
touchedval() {
    awk -F '\t' -v k="$1" '$1==k { print $2 }' "$SANDBOX/state/touched.tsv"
}

# ----------------------------------------------------------------- tests ----
section detect
out=$(run_core detect)
has "cpu_little detected" "$out" "cpu_little_max"
has "cpu_big detected" "$out" "cpu_big_max"
has "gpu detected" "$out" "gpu_max"
has "swappiness detected" "$out" "swappiness"
has "settings keys detected" "$out" "anim_window"
eq "little path uses runtime detection" \
    "$(awk -F '\t' '$1=="cpu_little_max"{print $2}' "$SANDBOX/state/targets.tsv")" \
    "$P0/scaling_max_freq"
eq "big path uses runtime detection" \
    "$(awk -F '\t' '$1=="cpu_big_max"{print $2}' "$SANDBOX/state/targets.tsv")" \
    "$P6/scaling_max_freq"

section bounds
eq "little bounds" "$(run_core bounds cpu_little_max)" "$(printf '500000\t2000000\t1000\tkHz')"
eq "big bounds" "$(run_core bounds cpu_big_max)" "$(printf '725000\t2200000\t1000\tkHz')"
eq "gpu bounds" "$(run_core bounds gpu_max)" "$(printf '390000000\t1003000000\t1000\tkHz')"
eq "settings bounds" "$(run_core bounds anim_window)" "$(printf '0\t2\t0.05\tx')"
eq "get reads current" "$(run_core get cpu_little_max)" "1700000"
eq "get reads fake settings" "$(run_core get anim_window)" "1.0"

section baseline
out=$(run_core baseline)
has "baseline cpu little" "$out" "$(printf 'cpu_little_max\t1700000')"
has "baseline cpu big" "$out" "$(printf 'cpu_big_max\t1800000')"
has "baseline settings" "$out" "$(printf 'anim_window\t1.0')"
has "baseline null sentinel" "$out" "$(printf 'animator_duration\t__unset__')"

section set-clamp
eq "clamp above hw max" "$(run_core set cpu_little_max custom 99999999)" "OK cpu_little_max custom 2000000"
eq "clamp below hw min" "$(run_core set cpu_big_max custom 1)" "OK cpu_big_max custom 725000"
eq "settings custom" "$(run_core set anim_window custom 0.5)" "OK anim_window custom 0.5"
eq "config reflected" "$(cfgval cpu_little_max)" "$(printf 'custom\t2000000')"
if run_core set cpu_little_max bogus 1 >/dev/null 2>&1; then
    bad "invalid mode rejected" "command unexpectedly succeeded"
else
    ok "invalid mode rejected"
fi
if run_core set no_such_key custom 1 >/dev/null 2>&1; then
    bad "unknown key rejected" "command unexpectedly succeeded"
else
    ok "unknown key rejected"
fi

section dry-run
out=$(run_core_dry apply)
has "dry-run prints intent" "$out" "DRY would write"
eq "dry-run leaves sysfs untouched" "$(cat "$P0/scaling_max_freq")" "1700000"
eq "dry-run status" "$(lastrow cpu_little_max)" "$(printf 'DRY\t2000000\t1700000')"
has "dry-run log" "$(cat "$SANDBOX/state/apply.log")" "dry-run: would write"
eq "dry-run config untouched" "$(cfgval cpu_little_max)" "$(printf 'custom\t2000000')"

section apply
run_core apply >/dev/null
eq "little applied" "$(cat "$P0/scaling_max_freq")" "2000000"
eq "big applied (clamped)" "$(cat "$P6/scaling_max_freq")" "725000"
eq "settings applied" "$("$TT_SETTINGS_BIN" get global window_animation_scale)" "0.5"
eq "verify status" "$(lastrow cpu_little_max)" "$(printf 'OK\t2000000\t2000000')"
eq "verify big status" "$(lastrow cpu_big_max)" "$(printf 'OK\t725000\t725000')"
eq "touched records original" "$(touchedval cpu_little_max)" "1700000"
eq "touched settings original" "$(touchedval anim_window)" "1.0"

section restore-dry
run_core_dry restore >/dev/null
eq "restore dry-run leaves little" "$(cat "$P0/scaling_max_freq")" "2000000"
eq "restore dry-run leaves settings" "$("$TT_SETTINGS_BIN" get global window_animation_scale)" "0.5"

section restore
# A key the module never touched must survive restore, even if it drifted.
mkfile "$ROOT/proc/sys/vm/swappiness" 120
run_core restore >/dev/null
eq "untouched key preserved" "$(cat "$ROOT/proc/sys/vm/swappiness")" "120"
eq "touched list cleared" "$(grep -c -v '^#' "$SANDBOX/state/touched.tsv")" "0"
eq "little restored" "$(cat "$P0/scaling_max_freq")" "1700000"
eq "big restored" "$(cat "$P6/scaling_max_freq")" "1800000"
eq "settings restored" "$("$TT_SETTINGS_BIN" get global window_animation_scale)" "1.0"
eq "unset sentinel restored" "$("$TT_SETTINGS_BIN" get global animator_duration)" "null"
eq "config reset auto" "$(cfgval cpu_little_max)" "$(printf 'auto\t')"

section auto-noop
run_core apply >/dev/null
eq "auto apply changes nothing" "$(cat "$P0/scaling_max_freq")" "1700000"
eq "auto apply has no data rows" "$(grep -c -v '^#' "$SANDBOX/state/last_apply.tsv")" "0"

section source-guard
out=$(MODDIR="$SANDBOX" "$SH" -c '. "$0/lib/core.sh"; echo SOURCED_OK' "$SANDBOX")
eq "sourcing core.sh is quiet" "$out" "SOURCED_OK"

section telemetry
out=$(run_core status)
has "battery temp fixed" "$out" "$(printf 'temp_batt_c\t37.0')"
has "soc temp" "$out" "$(printf 'temp_soc_c\t54.0')"
has "zram used" "$out" "$(printf 'zram_used_kb\t2000000')"
has "module count" "$out" "$(printf 'module_count\t2')"
has "hook failures" "$out" "$(printf 'lsposed_hook_fail\t3')"

printf '\n----------------------------------------\n'
printf 'PASS=%s FAIL=%s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

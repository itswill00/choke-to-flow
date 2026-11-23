#!/system/bin/sh
MODDIR=$(cd -- "${0%/*}" 2>/dev/null && pwd)
. "$MODDIR/lib/core.sh"
apply_all
printf '\n--- Active tweaks ---\n'
awk -F '\t' '$1!~/^#/ && $2=="custom" {printf "%s = %s\n",$1,$3}' "$CONFIG"
printf '\n--- Telemetry ---\n'
telemetry | awk -F '\t' '$1 ~ /^(device|load|temp_soc_c|zram_used_kb|mem_avail_kb|cpu_little_cap_khz|cpu_big_cap_khz|module_count|lsposed_hook_fail)$/ {printf "%s: %s\n",$1,$2}'

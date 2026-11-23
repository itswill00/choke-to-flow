#!/system/bin/sh
# choke-to-flow :: core
#
# Design rules:
#   - NO device-specific constants. CPU/GPU paths are detected at runtime.
#   - NO charging sysfs is ever touched.
#   - NO other module is ever disabled/enabled.
#   - First run captures a baseline; uninstall restores it.
#
# Callers set MODDIR before sourcing. When executed directly, derive from $0.

: "${MODDIR:=$(cd -- "${0%/*}/.." 2>/dev/null && pwd)}"
STATE="$MODDIR/state"
DEFAULTS="$MODDIR/defaults"
CONFIG="$STATE/config.tsv"
TARGETS="$STATE/targets.tsv"
BASELINE="$STATE/baseline.tsv"
TOUCHED="$STATE/touched.tsv"
LOGFILE="$STATE/apply.log"

mkdir -p "$STATE" 2>/dev/null

TAB=$(printf '\t')

# ---------------------------------------------------- testability hooks ------
# Empty/unset on a real device. Tests point these at a sandbox tree.
ROOT_PREFIX="${TT_ROOT:-}"
SYS="$ROOT_PREFIX/sys"
PROC="$ROOT_PREFIX/proc"
ADB="$ROOT_PREFIX/data/adb"
SETTINGS_BIN="${TT_SETTINGS_BIN:-settings}"
DRY_RUN="${TT_DRY_RUN:-0}"

is_dry() { [ "$DRY_RUN" = 1 ]; }

_log() {
    printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOGFILE" 2>/dev/null || return 0
    n=$(wc -l < "$LOGFILE" 2>/dev/null)
    case "$n" in ''|*[!0-9]*) return 0 ;; esac
    if [ "$n" -gt 400 ]; then
        tail -n 200 "$LOGFILE" > "$LOGFILE.t" 2>/dev/null && mv "$LOGFILE.t" "$LOGFILE" 2>/dev/null
    fi
}

_lookup() {
    awk -F '\t' -v k="$1" '$1==k {print $2; exit}' "$TARGETS" 2>/dev/null
}

_lookup_kind() {
    awk -F '\t' -v k="$1" '$1==k {print $3; exit}' "$TARGETS" 2>/dev/null
}

_has_key() {
    awk -F '\t' -v k="$1" '$1==k {f=1} END{exit !f}' "$CONFIG" 2>/dev/null
}

# ---------------------------------------------------------------- detect ----
detect_targets() {
    mkdir -p "$STATE" 2>/dev/null
    [ -f "$CONFIG" ] || cp "$DEFAULTS/config.tsv" "$CONFIG" 2>/dev/null

    plist="$STATE/.policies"
    : > "$plist"
    for p in "$SYS"/devices/system/cpu/cpufreq/policy*; do
        [ -r "$p/cpuinfo_max_freq" ] || continue
        m=$(cat "$p/cpuinfo_max_freq" 2>/dev/null)
        [ -n "$m" ] && printf '%s\t%s\n' "$m" "$p" >> "$plist"
    done

    {
        printf '# key\tpath\tkind\n'
        if [ -s "$plist" ]; then
            sort -n "$plist" > "$plist.s" 2>/dev/null && mv "$plist.s" "$plist" 2>/dev/null
            little=$(awk -F '\t' 'NR==1{print $2}' "$plist")
            big=$(awk -F '\t' 'END{print $2}' "$plist")
            [ -n "$little" ] && {
                printf '%s\t%s\t%s\n' cpu_little_max "$little/scaling_max_freq" freq
                printf '%s\t%s\t%s\n' cpu_little_min "$little/scaling_min_freq" freq
            }
            if [ -n "$big" ] && [ "$big" != "$little" ]; then
                printf '%s\t%s\t%s\n' cpu_big_max "$big/scaling_max_freq" freq
                printf '%s\t%s\t%s\n' cpu_big_min "$big/scaling_min_freq" freq
            fi
        fi

        gpu=""
        for d in "$SYS"/class/devfreq/*; do
            [ -r "$d/name" ] || continue
            n=$(cat "$d/name" 2>/dev/null)
            case "$n" in
                *mali*|*Mali*|*MALI*|*gpu*|*GPU*) gpu="$d"; break ;;
            esac
        done
        if [ -n "$gpu" ] && [ -e "$gpu/max_freq" ]; then
            printf '%s\t%s\t%s\n' gpu_max "$gpu/max_freq" freq
        fi

        [ -e "$PROC/sys/vm/swappiness" ] && \
            printf '%s\t%s\t%s\n' swappiness "$PROC/sys/vm/swappiness" int

        printf '%s\t%s\t%s\n' anim_window window_animation_scale settings
        printf '%s\t%s\t%s\n' anim_transition transition_animation_scale settings
        printf '%s\t%s\t%s\n' animator_duration animator_duration_scale settings
    } > "$TARGETS"

    rm -f "$plist" "$plist.s" 2>/dev/null
    _log "targets detected: $(($(wc -l < "$TARGETS") - 1)) tunables"
}

# ------------------------------------------------------------- read/write ---
read_target() {
    key="$1"
    path=$(_lookup "$key"); kind=$(_lookup_kind "$key")
    [ -z "$path" ] && return 1
    case "$kind" in
        settings) "$SETTINGS_BIN" get global "$path" 2>/dev/null ;;
        *) cat "$path" 2>/dev/null ;;
    esac
}

write_target() {
    key="$1"; val="$2"
    path=$(_lookup "$key"); kind=$(_lookup_kind "$key")
    [ -z "$path" ] && return 1
    if is_dry; then
        printf 'DRY would write %s <- %s\n' "$path" "$val"
        _log "dry-run: would write $path <- $val"
        return 0
    fi
    case "$kind" in
        settings)
            if [ "$val" = '__unset__' ]; then
                "$SETTINGS_BIN" delete global "$path" >/dev/null 2>&1
            else
                "$SETTINGS_BIN" put global "$path" "$val" >/dev/null 2>&1
            fi
            ;;
        *) printf '%s\n' "$val" > "$path" 2>/dev/null ;;
    esac
}

# ----------------------------------------------------------------- bounds ---
bounds() {
    key="$1"
    path=$(_lookup "$key"); kind=$(_lookup_kind "$key")
    case "$kind" in
        freq)
            case "$key" in
                cpu_*)
                    dir=${path%/*}
                    min=$(cat "$dir/cpuinfo_min_freq" 2>/dev/null)
                    max=$(cat "$dir/cpuinfo_max_freq" 2>/dev/null)
                    ;;
                *)
                    avail=$(cat "${path%/max_freq}/available_frequencies" 2>/dev/null)
                    min=$(printf '%s\n' $avail | sort -n 2>/dev/null | head -n 1)
                    max=$(printf '%s\n' $avail | sort -n 2>/dev/null | tail -n 1)
                    ;;
            esac
            step=1000; unit=kHz
            ;;
        settings) min=0; max=2; step=0.05; unit=x ;;
        *) min=0; max=200; step=1; unit= ;;
    esac
    printf '%s\t%s\t%s\t%s\n' "${min:-0}" "${max:-0}" "$step" "$unit"
}

clamp() {
    key="$1"; val="$2"
    case "$val" in ''|*[!0-9.]*) return 1 ;; esac
    b=$(bounds "$key")
    min=$(printf '%s\n' "$b" | cut -f1)
    max=$(printf '%s\n' "$b" | cut -f2)
    awk -v v="$val" -v lo="$min" -v hi="$max" \
        'BEGIN{ if (v<lo) printf "%s",lo; else if (v>hi) printf "%s",hi; else printf "%s",v }'
}

# -------------------------------------------------------------- baseline ----
capture_baseline() {
    # A shipped file may contain only the header — that is NOT a captured baseline.
    if grep -q -v '^#' "$BASELINE" 2>/dev/null; then return 0; fi
    printf '# key\tvalue\n' > "$BASELINE"
    while IFS="$TAB" read -r key path kind rest; do
        case "$key" in ''|\#*) continue ;; esac
        v=$(read_target "$key")
        [ -z "$v" ] && continue
        if [ "$kind" = settings ] && [ "$v" = null ]; then v='__unset__'; fi
        printf '%s\t%s\n' "$key" "$v" >> "$BASELINE"
    done < "$TARGETS"
    _log "baseline captured"
}

# ---------------------------------------------------------- touched keys ----
# First time we actually write a key, remember its pre-write value. Restore
# only replays keys we touched — never stock values the module left alone.
record_touched() {
    key="$1"; old="$2"
    [ -f "$TOUCHED" ] || printf '# key\toriginal\n' > "$TOUCHED"
    if awk -F '\t' -v k="$key" '$1==k {f=1} END{exit !f}' "$TOUCHED" 2>/dev/null; then
        return 0
    fi
    if [ -z "$old" ]; then
        [ "$(_lookup_kind "$key")" = settings ] && old='__unset__' || return 0
    elif [ "$old" = null ] && [ "$(_lookup_kind "$key")" = settings ]; then
        old='__unset__'
    fi
    printf '%s\t%s\n' "$key" "$old" >> "$TOUCHED"
}

# ----------------------------------------------------------------- config ---
cmd_set() {
    key="$1"; mode="$2"; val="$3"
    _has_key "$key" || { printf 'ERR unknown key: %s\n' "$key"; return 1; }
    case "$mode" in
        auto|custom) ;;
        *) printf 'ERR mode must be auto|custom\n'; return 1 ;;
    esac
    if [ "$mode" = custom ]; then
        v=$(clamp "$key" "$val") || { printf 'ERR invalid value: %s\n' "$val"; return 1; }
        val="$v"
    else
        val=""
    fi
    awk -F '\t' -v OFS='\t' -v k="$key" -v m="$mode" -v v="$val" \
        '$1==k {$2=m; $3=v} {print}' "$CONFIG" > "$CONFIG.t" && mv "$CONFIG.t" "$CONFIG"
    printf 'OK %s %s %s\n' "$key" "$mode" "$val"
}

apply_all() {
    detect_targets
    capture_baseline
    printf '# key\tstatus\trequested\tactual\n' > "$STATE/last_apply.tsv"
    while IFS="$TAB" read -r key mode val rest; do
        case "$key" in ''|\#*) continue ;; esac
        [ "$mode" = custom ] || continue
        new=$(clamp "$key" "$val") || continue
        old=$(read_target "$key")
        if ! is_dry; then
            record_touched "$key" "$old"
        fi
        write_target "$key" "$new"
        after=$(read_target "$key")
        if is_dry; then
            st=DRY
        elif [ "$after" = "$new" ]; then
            st=OK
        else
            st=FAIL
        fi
        printf '%s\t%s\t%s\t%s\n' "$key" "$st" "$new" "$after" >> "$STATE/last_apply.tsv"
        _log "apply $key: [$old] -> $new ($st)"
    done < "$CONFIG"
}

restore_all() {
    src=""
    if [ -f "$TOUCHED" ] && grep -q -v '^#' "$TOUCHED" 2>/dev/null; then
        src="$TOUCHED"
    elif [ -f "$BASELINE" ] && grep -q -v '^#' "$BASELINE" 2>/dev/null; then
        src="$BASELINE"   # fallback for installs made before touched tracking
    fi
    [ -n "$src" ] || return 0
    while IFS="$TAB" read -r key val rest; do
        case "$key" in ''|\#*) continue ;; esac
        old=$(read_target "$key")
        write_target "$key" "$val"
        _log "restore $key: [$old] -> $val"
    done < "$src"
    if ! is_dry; then
        printf '# key\toriginal\n' > "$TOUCHED" 2>/dev/null
        awk -F '\t' -v OFS='\t' 'BEGIN{print "# key","mode","value"} /^#/{next} {print $1,"auto",""}' \
            "$CONFIG" > "$CONFIG.t" 2>/dev/null && mv "$CONFIG.t" "$CONFIG" 2>/dev/null
        _log "config reset to auto"
    fi
}

# -------------------------------------------------------------- telemetry ---
# thermal_zone*: millidegrees. power_supply*: tenths of a degree.
f2() { awk -v v="$1" 'BEGIN{if(v==""||v=="NaN")print "?"; else printf "%.1f",v/1000}' 2>/dev/null; }
f1() { awk -v v="$1" 'BEGIN{if(v==""||v=="NaN")print "?"; else printf "%.1f",v/10}' 2>/dev/null; }

telemetry() {
    if ! grep -q -v '^#' "$TARGETS" 2>/dev/null; then
        detect_targets >/dev/null 2>&1
    fi
    dev=$(getprop ro.product.brand 2>/dev/null)" "$(getprop ro.product.model 2>/dev/null)
    rom=$(getprop ro.build.version.incremental 2>/dev/null)
    up=$(cut -d' ' -f1 "$PROC/uptime" 2>/dev/null)
    load=$(cut -d' ' -f1-3 "$PROC/loadavg" 2>/dev/null)
    soc=$(f2 "$(cat "$SYS/class/thermal/thermal_zone0/temp" 2>/dev/null)")
    skin=$(f2 "$(cat "$SYS/class/thermal/thermal_zone16/temp" 2>/dev/null)")
    batt=$(f1 "$(cat "$SYS/class/power_supply/battery/temp" 2>/dev/null)")
    zt=$(awk '/SwapTotal/{t=$2}/SwapFree/{f=$2}END{print t-f}' "$PROC/meminfo" 2>/dev/null)
    zf=$(awk '/SwapTotal/{print $2}' "$PROC/meminfo" 2>/dev/null)
    ma=$(awk '/MemAvailable/{print $2}' "$PROC/meminfo" 2>/dev/null)
    mf=$(awk '/MemFree/{print $2}' "$PROC/meminfo" 2>/dev/null)
    p0=$(_lookup cpu_little_max); p1=$(_lookup cpu_big_max)
    d0=${p0%/scaling_max_freq}; d1=${p1%/scaling_max_freq}
    f0=$(cat "$d0/scaling_cur_freq" 2>/dev/null); c0=$(cat "$d0/scaling_max_freq" 2>/dev/null)
    f1=$(cat "$d1/scaling_cur_freq" 2>/dev/null); c1=$(cat "$d1/scaling_max_freq" 2>/dev/null)
    h0=$(cat "$d0/cpuinfo_max_freq" 2>/dev/null); h1=$(cat "$d1/cpuinfo_max_freq" 2>/dev/null)
    cur=$(cat "$SYS/class/power_supply/battery/current_now" 2>/dev/null)
    cap=$(cat "$SYS/class/power_supply/battery/capacity" 2>/dev/null)
    cl=$(grep -m1 POWER_SUPPLY_CHARGE_CONTROL_LIMIT= "$SYS/class/power_supply/battery/uevent" 2>/dev/null | cut -d= -f2)
    mods=$(ls -d "$ADB"/modules/*/ 2>/dev/null | wc -l)
    fails=$(grep -h -c 'Hook Failed' "$ADB"/lspd/log/modules_*.log 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}')

    printf 'device\t%s\n' "$dev"
    printf 'rom\t%s\n' "$rom"
    printf 'uptime_s\t%s\n' "$up"
    printf 'load\t%s\n' "$load"
    printf 'temp_soc_c\t%s\n' "$soc"
    printf 'temp_skin_c\t%s\n' "$skin"
    printf 'temp_batt_c\t%s\n' "$batt"
    printf 'zram_used_kb\t%s\n' "$zt"
    printf 'zram_total_kb\t%s\n' "$zf"
    printf 'mem_avail_kb\t%s\n' "$ma"
    printf 'mem_free_kb\t%s\n' "$mf"
    printf 'cpu_little_cur_khz\t%s\n' "$f0"
    printf 'cpu_little_cap_khz\t%s\n' "$c0"
    printf 'cpu_little_hw_khz\t%s\n' "$h0"
    printf 'cpu_big_cur_khz\t%s\n' "$f1"
    printf 'cpu_big_cap_khz\t%s\n' "$c1"
    printf 'cpu_big_hw_khz\t%s\n' "$h1"
    printf 'charge_now_ua\t%s\n' "$cur"
    printf 'battery_pct\t%s\n' "$cap"
    printf 'charge_limit\t%s\n' "$cl"
    printf 'module_count\t%s\n' "$mods"
    printf 'lsposed_hook_fail\t%s\n' "$fails"
}

# Only dispatch when core.sh is executed directly — boot scripts source it.
if [ "${0##*/}" = "core.sh" ]; then
    if [ "${1:-}" = "--dry-run" ]; then
        DRY_RUN=1
        shift
    fi

    case "$1" in
        detect)     detect_targets; cat "$TARGETS" ;;
        baseline)   capture_baseline; cat "$BASELINE" ;;
        config)     cat "$CONFIG" ;;
        apply)      apply_all ;;
        restore)    restore_all ;;
        set)        shift; cmd_set "$@" ;;
        get)        shift; read_target "$@" ;;
        bounds)     shift; bounds "$@" ;;
        status)     telemetry ;;
        last)       cat "$STATE/last_apply.tsv" 2>/dev/null ;;
        touched)    cat "$TOUCHED" 2>/dev/null ;;
        *)          printf 'usage: core.sh detect|baseline|config|apply|restore|set KEY MODE VAL|get KEY|bounds KEY|status|last|touched\n' ;;
    esac
fi

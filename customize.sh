#!/system/bin/sh
# Installer. Do NOT touch webroot permissions/context — KernelSU manages it.

mkdir -p "$MODPATH/state" 2>/dev/null

# Let the compiled WebUI discover its own module dir without hardcoding.
printf '%s' "$MODPATH" > "$MODPATH/webroot/moddir.txt" 2>/dev/null
[ -f "$MODPATH/state/config.tsv" ] || cp "$MODPATH/defaults/config.tsv" "$MODPATH/state/config.tsv" 2>/dev/null
printf '# key\tpath\tkind\n' > "$MODPATH/state/targets.tsv"
printf '# key\tvalue\n' > "$MODPATH/state/baseline.tsv"
printf '# key\tstatus\trequested\tactual\n' > "$MODPATH/state/last_apply.tsv"

set_perm_recursive "$MODPATH/lib" 0 0 0755 0644 2>/dev/null
set_perm_recursive "$MODPATH/defaults" 0 0 0755 0644 2>/dev/null
set_perm_recursive "$MODPATH/state" 0 0 0755 0644 2>/dev/null

for f in service.sh boot-completed.sh hotinstall.sh action.sh uninstall.sh; do
    set_perm "$MODPATH/$f" 0 0 0755 2>/dev/null
done

# No system/ files are mounted, so hot install is safe.
export MODULE_HOT_INSTALL_REQUEST=true
export MODULE_HOT_RUN_SCRIPT=hotinstall.sh

ui_print "choke-to-flow installed"
ui_print "Buka WebUI modul untuk mengatur. Default: semua AUTO."

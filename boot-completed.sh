#!/system/bin/sh
# Some ROMs/power HALs re-write sysfs after boot. Re-apply once, quietly.
MODDIR=$(cd -- "${0%/*}" 2>/dev/null && pwd)
. "$MODDIR/lib/core.sh"
apply_all

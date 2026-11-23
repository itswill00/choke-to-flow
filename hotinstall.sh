#!/system/bin/sh
MODDIR=$(cd -- "${0%/*}" 2>/dev/null && pwd)
. "$MODDIR/lib/core.sh"
apply_all
printf 'choke-to-flow: applied hot. No reboot needed.\n'

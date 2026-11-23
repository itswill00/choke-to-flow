#!/system/bin/sh
MODDIR=$(cd -- "${0%/*}" 2>/dev/null && pwd)
. "$MODDIR/lib/core.sh"
restore_all
printf 'choke-to-flow: baseline restored.\n'

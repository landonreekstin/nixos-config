# card-mount <name|uuid> — mount by UUID and print the mountpoint.
set -eu

emu_resolve "${1:-}"
mp=$(emu_ensure_mounted)
printf '%s\n' "$mp"
emu_note "$CARD_NAME mounted at $mp"

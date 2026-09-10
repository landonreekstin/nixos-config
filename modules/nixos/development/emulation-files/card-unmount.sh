# card-unmount <name|uuid> — flush and confirm before anyone pulls the card.
#
# Rule 1: umount is the flush. Confirm with findmnt before reporting safe —
# a Stop hook that was supposed to do this was once caught not firing at all,
# so nothing here trusts that a card is already flushed.
set -eu

emu_resolve "${1:-}"

if ! emu_present; then
  emu_note "$CARD_NAME is not plugged in — nothing to do."
  exit 0
fi

if [ -z "$(emu_mountpoint)" ]; then
  emu_note "$CARD_NAME was already unmounted — safe to pull."
  exit 0
fi

if emu_unmount; then
  emu_note "$CARD_NAME unmounted and confirmed by findmnt — safe to pull."
else
  emu_die "$CARD_NAME is STILL MOUNTED — unmount failed. Do NOT pull it. Check for open files with: lsof +f -- $(emu_mountpoint)"
fi

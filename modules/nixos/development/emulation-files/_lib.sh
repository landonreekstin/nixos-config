# ~/nixos-config/modules/nixos/development/emulation-files/_lib.sh
#
# Shared prelude for the card-* helpers in the `emulation` devShell.
# Sourced textually into each script at build time, so it must stay POSIX-ish
# and must not assume anything about the caller's PATH beyond the devShell.
#
# The card map is DATA and lives in the emulation workspace, not here:
# hardcoding UUIDs in Nix would add a third place to register a card, and
# ~/emulation/CLAUDE.md already warns that keeping two in sync is error-prone.

emu_die() { printf 'card-helper: %s\n' "$*" >&2; exit 1; }

emu_note() { printf '%s\n' "$*" >&2; }

# Locate cards.tsv: $EMU_CARDS, else nearest one at or above $PWD, else the
# default workspace path. Fail loudly rather than guessing a device.
emu_cards_file() {
  if [ -n "${EMU_CARDS:-}" ]; then
    printf '%s' "$EMU_CARDS"
    return
  fi
  _d=$PWD
  while [ "$_d" != "/" ]; do
    if [ -f "$_d/cards.tsv" ]; then
      printf '%s' "$_d/cards.tsv"
      return
    fi
    _d=$(dirname "$_d")
  done
  printf '%s' "$HOME/emulation/cards.tsv"
}

emu_known_names() {
  awk '$0 !~ /^[[:space:]]*#/ && NF >= 2 { printf "%s ", $1 }' "$1"
}

# emu_resolve <name|uuid>
# Sets CARD_NAME CARD_UUID CARD_DEV CARD_TREE CARD_SAVEDIR CARD_ARCHIVE CARD_ROOT
emu_resolve() {
  [ $# -ge 1 ] && [ -n "$1" ] || emu_die "no card given. Try 'card-status' to list them."

  # The whole point of the UUID rule: /dev/sdX is assigned in insertion order
  # and with several cards in rotation it will eventually name the wrong console.
  case "$1" in
    /dev/*|sd[a-z]|sd[a-z][0-9]*|mmcblk*)
      emu_die "refusing '$1'. Address a card by workspace name or filesystem UUID, never a device node — that node is assigned in insertion order and will eventually name the wrong console. See 'SD cards — identify by UUID' in ~/emulation/CLAUDE.md."
      ;;
  esac

  _f=$(emu_cards_file)
  [ -f "$_f" ] || emu_die "no card map found. Looked for cards.tsv at or above \$PWD, then $HOME/emulation/cards.tsv. Set \$EMU_CARDS to point at one."
  CARD_ROOT=$(dirname "$_f")

  _line=$(awk -v k="$1" '$0 !~ /^[[:space:]]*#/ && NF >= 2 && ($1 == k || $2 == k) { print; exit }' "$_f")
  [ -n "$_line" ] || emu_die "unknown card '$1'. Known: $(emu_known_names "$_f")"

  CARD_NAME=$(printf '%s\n'  "$_line" | awk '{ print $1 }')
  CARD_UUID=$(printf '%s\n'  "$_line" | awk '{ print $2 }')
  CARD_TREE=$(printf '%s\n'  "$_line" | awk '{ print $3 }')
  CARD_SAVEDIR=$(printf '%s\n' "$_line" | awk '{ print $4 }')
  CARD_ARCHIVE=$(printf '%s\n' "$_line" | awk '{ print $5 }')

  [ "$CARD_UUID" = "-" ] && emu_die "card '$CARD_NAME' has no UUID recorded yet. Insert it, run 'lsblk -o NAME,SIZE,FSTYPE,UUID,LABEL', and fill the UUID into $_f (and the Stop hook in .claude/settings.json)."

  CARD_DEV=/dev/disk/by-uuid/$CARD_UUID
}

emu_present()    { [ -e "$CARD_DEV" ]; }
emu_mountpoint() { findmnt -no TARGET "$CARD_DEV" 2>/dev/null; }

emu_require_present() {
  emu_present || emu_die "$CARD_NAME ($CARD_UUID) is not plugged in."
}

# Mount if needed; echoes the mountpoint.
emu_ensure_mounted() {
  emu_require_present
  _mp=$(emu_mountpoint)
  if [ -z "$_mp" ]; then
    udisksctl mount -b "$CARD_DEV" >/dev/null 2>&1 || true
    _mp=$(emu_mountpoint)
  fi
  [ -n "$_mp" ] || emu_die "could not mount $CARD_NAME ($CARD_DEV)."
  printf '%s' "$_mp"
}

# Rule 1: umount is the flush. Never a bare `sync`.
emu_unmount() {
  udisksctl unmount -b "$CARD_DEV" >/dev/null 2>&1 || true
  [ -z "$(emu_mountpoint)" ]
}

emu_remount() {
  emu_unmount || emu_die "$CARD_NAME is still mounted — do NOT pull it."
  udisksctl mount -b "$CARD_DEV" >/dev/null 2>&1 || true
  _mp=$(emu_mountpoint)
  [ -n "$_mp" ] || emu_die "could not remount $CARD_NAME."
  printf '%s' "$_mp"
}

# Rule 13: a hash taken through the page cache proves nothing. Read cold.
emu_cold_md5() { dd if="$1" iflag=direct bs=1M 2>/dev/null | md5sum | cut -d' ' -f1; }
emu_md5()      { md5sum "$1" | cut -d' ' -f1; }

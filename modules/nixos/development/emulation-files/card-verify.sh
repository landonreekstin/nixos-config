# card-verify <src> <dest-on-card> <name|uuid> — rule 13, verify half.
#
# Unmount and remount first, then read the card copy with iflag=direct. A hash
# taken while the card is still mounted proves nothing: the bytes may never
# have left RAM. A verification that cannot fail is not a verification.
set -eu

src=${1:-}
dest=${2:-}
card=${3:-}
[ -n "$src" ] && [ -n "$dest" ] && [ -n "$card" ] || emu_die "usage: card-verify <src> <dest-on-card> <name|uuid>"
[ -f "$src" ] || emu_die "source not found: $src"

emu_resolve "$card"

# The dest path is under the old mountpoint; recompute it after the remount.
oldmp=$(emu_mountpoint)
[ -n "$oldmp" ] || emu_die "$CARD_NAME is not mounted — nothing to verify."
case "$dest" in
  "$oldmp"/*) rel=${dest#"$oldmp"/} ;;
  *) emu_die "destination '$dest' is not under $CARD_NAME's mountpoint ($oldmp)." ;;
esac

emu_note "== dropping the page cache the only way that is guaranteed: unmount + remount"
mp=$(emu_remount)
target=$mp/$rel
[ -f "$target" ] || emu_die "not on the card after remount: $target"

a=$(emu_md5 "$src")
b=$(emu_cold_md5 "$target")

printf 'source %s  %s\n' "$a" "$src"
printf 'card   %s  %s\n' "$b" "$target"

if [ "$a" = "$b" ]; then
  emu_note "MATCH — cold read, so this one actually means something."
else
  emu_die "MISMATCH. The card copy is bad. Do not trust it and do not boot it."
fi

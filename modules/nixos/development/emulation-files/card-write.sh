# card-write <src> <dest> — rule 13, write half.
#
# A plain cp followed by md5sum cannot fail: the read comes back through the
# page cache. On 2026-09-05 that let a ROM whose last 40 KB never landed hash
# correctly and then refuse to boot. Write with direct I/O and fsync, then
# verify cold with card-verify.
set -eu

src=${1:-}
dest=${2:-}
[ -n "$src" ] && [ -n "$dest" ] || emu_die "usage: card-write <src> <dest-on-card>"
[ -f "$src" ] || emu_die "source not found: $src"

destdir=$(dirname "$dest")
[ -d "$destdir" ] || emu_die "destination directory not found: $destdir (is the card mounted?)"

size=$(stat -c %s "$src")
emu_note "== writing $(basename "$src") ($size bytes) with oflag=direct conv=fsync"
dd if="$src" of="$dest" bs=1M oflag=direct conv=fsync status=none

emu_note "written. NOW VERIFY COLD — the write is not proven until you do:"
emu_note ""
emu_note "  card-verify $src $dest <card>"

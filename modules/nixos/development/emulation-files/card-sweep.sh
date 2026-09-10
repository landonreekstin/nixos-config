# card-sweep <localdir> <carddir> <name|uuid> — rule 13 across a whole directory.
#
# Worth running after any bulk copy. The same sweep that found the one bad
# write among 34 X7 ROMs in 2026-09-05: everything else matched, one file was
# corrupt in its last 40 KB.
set -eu

localdir=${1:-}
carddir=${2:-}
card=${3:-}
[ -n "$localdir" ] && [ -n "$carddir" ] && [ -n "$card" ] || emu_die "usage: card-sweep <localdir> <carddir-on-card> <name|uuid>"
[ -d "$localdir" ] || emu_die "not a directory: $localdir"

emu_resolve "$card"

oldmp=$(emu_mountpoint)
[ -n "$oldmp" ] || emu_die "$CARD_NAME is not mounted."
case "$carddir" in
  "$oldmp"/*) rel=${carddir#"$oldmp"/} ;;
  "$oldmp")   rel="" ;;
  *) emu_die "'$carddir' is not under $CARD_NAME's mountpoint ($oldmp)." ;;
esac

emu_note "== unmount + remount so every read below is cold"
mp=$(emu_remount)
base=$mp${rel:+/$rel}
[ -d "$base" ] || emu_die "not on the card after remount: $base"

ok=0; bad=0; missing=0
while IFS= read -r f; do
  name=${f#"$localdir"/}
  target=$base/$name
  if [ ! -f "$target" ]; then
    printf 'MISSING   %s\n' "$name"
    missing=$((missing + 1))
    continue
  fi
  a=$(emu_md5 "$f")
  b=$(emu_cold_md5 "$target")
  if [ "$a" = "$b" ]; then
    ok=$((ok + 1))
  else
    printf 'MISMATCH  %s\n  local %s\n  card  %s\n' "$name" "$a" "$b"
    bad=$((bad + 1))
  fi
done <<EOF
$(find "$localdir" -type f | sort)
EOF

emu_note ""
emu_note "== $ok matched, $bad mismatched, $missing missing on the card"
[ "$bad" -eq 0 ] && [ "$missing" -eq 0 ] || exit 1

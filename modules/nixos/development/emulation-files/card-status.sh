# card-status — list every known card: present, mounted, where.
# No arguments, no side effects. The safe thing to run first.
set -eu

f=$(emu_cards_file)
[ -f "$f" ] || emu_die "no card map found. Looked for cards.tsv at or above \$PWD, then $HOME/emulation/cards.tsv."

printf 'card map: %s\n\n' "$f"
printf '%-8s %-12s %-16s %s\n' NAME UUID CONSOLE STATE
printf '%-8s %-12s %-16s %s\n' ------ ------------ ---------------- -----

awk '$0 !~ /^[[:space:]]*#/ && NF >= 2 { print $1, $2, $3 }' "$f" | while read -r name uuid tree; do
  if [ "$uuid" = "-" ]; then
    state="no UUID recorded — fill it in on first insertion"
  else
    dev=/dev/disk/by-uuid/$uuid
    if [ ! -e "$dev" ]; then
      state="absent"
    else
      mp=$(findmnt -no TARGET "$dev" 2>/dev/null || true)
      if [ -n "$mp" ]; then
        state="MOUNTED at $mp"
      else
        state="present, not mounted"
      fi
    fi
  fi
  printf '%-8s %-12s %-16s %s\n' "$name" "$uuid" "$tree" "$state"
done

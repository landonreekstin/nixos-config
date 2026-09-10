# card-backup <name|uuid> — rule 0. Back up a card's saves the moment it is here.
#
# Runs the console's archive tool if it has one, then takes a raw, diffable
# cp -a of the save directory into <tree>/saves/card-<stamp>/.
#
# It does NOT commit. saves/ is tracked and rule 0 says commit, but committing
# is a decision, not a side effect of plugging a card in — the command to run
# is printed at the end.
set -eu

emu_resolve "${1:-}"

[ "$CARD_TREE" = "-" ] && emu_die "card '$CARD_NAME' has no console tree recorded in the card map."
[ "$CARD_SAVEDIR" = "-" ] && emu_die "card '$CARD_NAME' has no save directory recorded yet. Read the card first and document where its saves live (see $CARD_ROOT/$CARD_TREE/README.md) before automating a backup of it."

tree=$CARD_ROOT/$CARD_TREE
[ -d "$tree" ] || emu_die "console tree not found: $tree"

mp=$(emu_ensure_mounted)
src=$mp/$CARD_SAVEDIR
[ -d "$src" ] || emu_die "save directory not on the card: $src"

stamp=$(date +%Y%m%d-%H%M%S)
dest=$tree/saves/card-$stamp

emu_note "== rule 0 backup: $CARD_NAME ($CARD_UUID)"
emu_note "   card    $mp"
emu_note "   into    $dest"

# 1. the console's own archive tool, where one exists
case "$CARD_ARCHIVE" in
  pupdate)
    emu_note "== pupdate backup-saves (captures Saves/ AND Memories/)"
    pupdate backup-saves -p "$mp" -l "$tree/saves/pocket-backups" 2>&1 | tr '\r' '\n' | grep -v '%' || true
    ;;
  -|"") ;;
  *) emu_note "== unknown archive tool '$CARD_ARCHIVE' in the card map — skipping" ;;
esac

# 2. the raw, diffable copy — this is what save surgery actually reads
mkdir -p "$dest"
cp -a "$src/." "$dest/"

emu_note ""
emu_note "== files"
find "$dest" -type f -printf '%10s  %P\n' | sort -k2

count=$(find "$dest" -type f | wc -l)
emu_note ""
emu_note "$count file(s) backed up. saves/ is tracked — commit it:"
emu_note ""
emu_note "  git -C $CARD_ROOT add $CARD_TREE/saves/ && \\"
emu_note "  git -C $CARD_ROOT commit -m 'rule 0: $CARD_NAME card backup $stamp'"
emu_note ""
emu_note "Remember: a card-side backup is a floor, not a snapshot of the console."

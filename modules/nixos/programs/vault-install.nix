# ~/nixos-config/modules/nixos/programs/vault-install.nix
{ config, pkgs, lib, ... }:

# vault-install — turn a Gamarr PC grab into a game in Heroic.
#
# Gamarr (modules/nixos/homelab/gamarr.nix, on optiplex-nas) stops at the download:
# a PC release lands in <libraryPath>/vault/ as
#
#   <Release>.rar                  the original archive
#   <Release>.rar.extracted/       Gamarr's unpack of it
#   <Release>.rar.gamarr.json      { "is_pc": true, "title": "...", ... }
#
# Most of what the indexers return are pre-installed repacks: somewhere under the
# .extracted/ dir is a `game/` folder that already runs. This command copies that
# folder onto a local disk (running off the CIFS mount means slow loads, and the game
# writing its saves into the NAS library) and registers it with Heroic as a sideloaded
# Windows game with its own Proton prefix.
#
# Heroic's sideload store is plain electron-store JSON, written here exactly as its
# own "Add Game" dialog writes it (2.22: addNewApp → sideload_apps/library.json under
# "games"). Heroic only reads that file at startup and rewrites it on exit, so the
# command refuses to touch it while Heroic is open — otherwise the entry would be
# silently dropped the next time Heroic quit.
let
  cfg = config.customConfig.programs.vaultInstall;
  enabled = cfg.enable && config.customConfig.profiles.gaming.enable;

  vault-install = pkgs.writeShellApplication {
    name = "vault-install";
    runtimeInputs = with pkgs; [ coreutils findutils gnused gnugrep jq rsync curl procps ];
    text = ''
      VAULT_DIR="${cfg.vaultDir}"
      INSTALL_DIR="${cfg.installDir}"
      HEROIC_DIR="$HOME/.config/heroic"

      usage() {
        cat <<EOF
      Usage: vault-install [--list]

      Pick a PC game Gamarr downloaded to $VAULT_DIR,
      copy it to $INSTALL_DIR and add it to Heroic.

        --list   just show what is in the vault
      EOF
      }

      LIST_ONLY=0
      case "''${1:-}" in
        "") ;;
        --list) LIST_ONLY=1 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 1 ;;
      esac

      if [ "$(id -u)" = 0 ]; then
        echo "Run vault-install as your own user, not with sudo -- the game and its Heroic entry belong to you." >&2
        exit 1
      fi

      if ! [ -d "$VAULT_DIR" ]; then
        echo "Can't see the vault at $VAULT_DIR -- is the NAS mounted?" >&2
        exit 1
      fi

      # "Sea Power : Naval Combat in the Missile Age (v2026.07.23)" -> "Sea Power - Naval Combat in the Missile Age"
      # The version suffix goes so a re-grab of a newer build replaces the old install
      # instead of sitting beside it; the rest is made safe for a directory name.
      clean_title() {
        sed -E -e 's/ *\([vV][0-9][^)]*\)$//' -e 's/ *: */ - /g' -e 's#[/\\*?"<>|]##g' -e 's/  +/ /g' -e 's/^ +| +$//g'
      }

      # Lowercase alphanumerics only, for loose "does this exe look like the game" matching.
      squash() { tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]'; }

      # ---- What's in the vault -------------------------------------------------
      TITLES=()
      SOURCES=()
      while IFS= read -r meta; do
        jq -e '.is_pc == true' "$meta" >/dev/null 2>&1 || continue
        ext="''${meta%.gamarr.json}.extracted"
        [ -d "$ext" ] || continue
        title=$(jq -r '.title // empty' "$meta" | clean_title)
        [ -n "$title" ] || title=$(basename "''${meta%.gamarr.json}" | clean_title)
        TITLES+=("$title")
        SOURCES+=("$ext")
      done < <(find "$VAULT_DIR" -maxdepth 1 -name '*.gamarr.json' | sort)

      if [ "''${#TITLES[@]}" -eq 0 ]; then
        echo "No PC games in $VAULT_DIR yet."
        exit 0
      fi

      echo "PC games in the vault:"
      for i in "''${!TITLES[@]}"; do
        mark=""
        [ -d "$INSTALL_DIR/''${TITLES[$i]}" ] && mark="  [installed]"
        printf '  %2d) %s%s\n' "$((i + 1))" "''${TITLES[$i]}" "$mark"
      done
      [ "$LIST_ONLY" = 1 ] && exit 0

      echo
      read -rp "Install which? [1-''${#TITLES[@]}, q to quit] " pick
      [[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -ge 1 ] && [ "$pick" -le "''${#TITLES[@]}" ] || exit 0
      TITLE="''${TITLES[$((pick - 1))]}"
      SRC="''${SOURCES[$((pick - 1))]}"

      # ---- Find the game inside the unpack -----------------------------------------
      # Releases wrap the game in one or more single-directory layers
      # (Release.rar.extracted/Release/game/); peel those off, then prefer game/.
      while :; do
        mapfile -t entries < <(find "$SRC" -mindepth 1 -maxdepth 1)
        if [ "''${#entries[@]}" -eq 1 ] && [ -d "''${entries[0]}" ]; then
          SRC="''${entries[0]}"
        else
          break
        fi
      done
      [ -d "$SRC/game" ] && SRC="$SRC/game"

      # Anything that is not the game itself: crash reporters, uninstallers, the
      # redistributable installers repacks bundle, and installers proper.
      exe_candidates() {
        find "$1" -iname '*.exe' \
          -not -iname 'unins*' -not -iname '*crash*' -not -iname 'setup*' \
          -not -iname '*redist*' -not -ipath '*redist*' -not -iname 'dxsetup*' \
          -not -iname '*prereq*' -not -iname 'dotnet*' -not -iname 'install*' \
          -printf '%d\t%P\n' | sort -t$'\t' -k1,1n -k2,2 | cut -f2
      }

      mapfile -t src_exes < <(exe_candidates "$SRC")
      if [ "''${#src_exes[@]}" -eq 0 ]; then
        echo "\"$TITLE\" isn't a ready-to-run game -- there's no game .exe in:" >&2
        echo "  $SRC" >&2
        echo "It is probably an installer (setup.exe / .iso). Run that through Heroic's Add Game instead." >&2
        exit 1
      fi

      DEST="$INSTALL_DIR/$TITLE"
      echo
      echo "Game:     $TITLE"
      echo "From:     $SRC"
      echo "To:       $DEST  ($(du -sh "$SRC" | cut -f1))"
      echo

      # ---- Copy ------------------------------------------------------------------
      # Into a .partial sibling first: an interrupted copy resumes on the next run, and
      # a directory under the real name always means a finished one.
      mkdir -p "$INSTALL_DIR"
      if [ -d "$DEST" ]; then
        read -rp "Already installed. Copy it again over the top (keeps your saves in the prefix)? [y/N] " again
        if [[ "$again" =~ ^[yY] ]]; then
          rsync -rlt --info=progress2 "$SRC/" "$DEST/"
        fi
      else
        rsync -rlt --info=progress2 "$SRC/" "$DEST.partial/"
        mv "$DEST.partial" "$DEST"
      fi

      # ---- Which exe launches it ---------------------------------------------------------
      # Shallowest first, then any whose name looks like the title floated to the top
      # (War on the Sea ships JSGME.exe, a mod manager, right beside WarOnTheSea.exe).
      mapfile -t exes < <(exe_candidates "$DEST")
      want=$(printf '%s' "$TITLE" | squash)
      ordered=()
      for e in "''${exes[@]}"; do
        n=$(basename "$e" .exe | squash)
        [ -n "$n" ] && [[ "$want" == *"$n"* ]] && ordered+=("$e")
      done
      for e in "''${exes[@]}"; do
        n=$(basename "$e" .exe | squash)
        { [ -n "$n" ] && [[ "$want" == *"$n"* ]]; } || ordered+=("$e")
      done

      EXE="''${ordered[0]}"
      if [ "''${#ordered[@]}" -gt 1 ]; then
        echo
        echo "Which program starts the game?"
        for i in "''${!ordered[@]}"; do
          printf '  %2d) %s\n' "$((i + 1))" "''${ordered[$i]}"
        done
        read -rp "[1-''${#ordered[@]}, Enter = 1] " which
        if [[ "$which" =~ ^[0-9]+$ ]] && [ "$which" -ge 1 ] && [ "$which" -le "''${#ordered[@]}" ]; then
          EXE="''${ordered[$((which - 1))]}"
        fi
      fi
      EXE="$DEST/$EXE"

      # ---- Add to Heroic ---------------------------------------------------------
      # Heroic is electron running .../opt/heroic/resources/app.asar; the [.] keeps the
      # pattern from matching a shell that merely has this string on its command line.
      while pgrep -u "$(id -u)" -f 'opt/heroic/resources/app[.]asar' >/dev/null; do
        echo
        read -rp "Heroic is open. Quit it (it would overwrite the new entry on exit), then press Enter. " _
      done

      # Cover art from Steam's store search, best effort: no key needed, and every
      # title Gamarr grabs here is a Steam release. Without it Heroic shows its
      # placeholder, which is fine.
      ART_COVER=""
      ART_SQUARE=""
      query=$(jq -rn --arg t "$TITLE" '$t | @uri')
      if appid=$(curl -fsS --max-time 10 "https://store.steampowered.com/api/storesearch/?term=$query&cc=us&l=en" \
                   | jq -er '.items[0].id'); then
        ART_COVER="https://shared.steamstatic.com/store_item_assets/steam/apps/$appid/header.jpg"
        ART_SQUARE="https://shared.steamstatic.com/store_item_assets/steam/apps/$appid/library_600x900.jpg"
        curl -fsI --max-time 10 "$ART_SQUARE" >/dev/null 2>&1 || ART_SQUARE="$ART_COVER"
      fi

      APP_NAME="vault-$(printf '%s' "$TITLE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g')"
      PREFIX_ROOT=$(jq -r '.defaultSettings.defaultWinePrefix // empty' "$HEROIC_DIR/config.json" 2>/dev/null || true)
      [ -n "$PREFIX_ROOT" ] || PREFIX_ROOT="$HOME/Games/Heroic/Prefixes/default"
      PREFIX="$PREFIX_ROOT/$TITLE"

      mkdir -p "$HEROIC_DIR/sideload_apps" "$HEROIC_DIR/GamesConfig"
      LIB="$HEROIC_DIR/sideload_apps/library.json"
      [ -s "$LIB" ] || echo '{"games":[]}' > "$LIB"
      tmp=$(mktemp "$LIB.XXXXXX")
      jq --arg id "$APP_NAME" --arg title "$TITLE" --arg exe "$EXE" --arg dir "$DEST" \
         --arg cover "$ART_COVER" --arg square "$ART_SQUARE" '
        .games = ([(.games // [])[] | select(.app_name != $id)] + [{
          runner: "sideload",
          app_name: $id,
          title: $title,
          install: { executable: $exe, platform: "windows", is_dlc: false },
          folder_name: $dir,
          art_cover: $cover,
          art_square: $square,
          is_installed: true,
          canRunOffline: true
        }])' "$LIB" > "$tmp"
      mv "$tmp" "$LIB"

      # Per-game settings: the user's global Heroic defaults (so it gets whichever
      # Proton is set as default there) plus its own prefix. Left alone on a reinstall
      # so any tweaks made in Heroic survive.
      GCFG="$HEROIC_DIR/GamesConfig/$APP_NAME.json"
      if ! [ -e "$GCFG" ]; then
        jq --arg id "$APP_NAME" --arg prefix "$PREFIX" '
          (.defaultSettings // {}) as $d
          | ["autoInstallDxvk","autoInstallDxvkNvapi","autoInstallVkd3d","preferSystemLibs",
             "enableEsync","enableMsync","enableFsync","enableWineWayland","enableHDR",
             "enableWoW64","nvidiaPrime","enviromentOptions","wrapperOptions","showFps",
             "useGameMode","useSteamRuntime","battlEyeRuntime","eacRuntime","language",
             "beforeLaunchScriptPath","afterLaunchScriptPath","verboseLogs","wineVersion",
             "wineCrossoverBottle"] as $keys
          | { ($id): (($d | with_entries(select(.key as $k | $keys | index($k)))) + { winePrefix: $prefix }),
              version: "v0", explicit: true }
        ' "$HEROIC_DIR/config.json" > "$GCFG" 2>/dev/null || echo '{}' > "$GCFG"
      fi

      echo
      echo "Done. \"$TITLE\" is in Heroic (Library -> filter: Sideloaded)."
      echo "  runs:   $EXE"
      echo "  prefix: $PREFIX"
      echo
      echo "Once it plays, the .rar on the NAS can go -- the .extracted folder holds the full game."
    '';
  };
in
{
  options.customConfig.programs.vaultInstall = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Install `vault-install`, which copies a PC game Gamarr downloaded to the NAS
        onto a local disk and adds it to Heroic. Requires customConfig.profiles.gaming.enable.
      '';
    };

    vaultDir = mkOption {
      type = types.str;
      default = "/mnt/nas/games/vault";
      description = ''
        Gamarr's PC library as this host sees it -- `<libraryPath>/vault` on the NAS,
        reached through the nasClient SMB mount by default.
      '';
    };

    installDir = mkOption {
      type = types.str;
      default = "${config.customConfig.user.home}/Games/Vault";
      defaultText = literalExpression ''"''${config.customConfig.user.home}/Games/Vault"'';
      description = "Where games are copied to, one directory per game. Point this at a games disk on hosts that have one.";
    };
  };

  # Outside the mkIf for the same reason as iw4x.nix: inside it the assertion would be
  # suppressed by the very condition it is checking.
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.enable || config.customConfig.profiles.gaming.enable;
          message = "customConfig.programs.vaultInstall.enable requires customConfig.profiles.gaming.enable.";
        }
      ];
    }

    (lib.mkIf enabled {
      environment.systemPackages = [ vault-install ];
    })
  ];
}

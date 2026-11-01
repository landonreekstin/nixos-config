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
# or, when the torrent was a folder rather than one archive, as the folder itself
# with the metadata inside it:
#
#   <Release>/.gamarr.json
#
# Most of what the indexers return are pre-installed repacks: somewhere under the
# .extracted/ dir is a `game/` folder that already runs. This command copies that
# folder onto a local disk (running off the CIFS mount means slow loads, and the game
# writing its saves into the NAS library) and registers it with Heroic as a sideloaded
# Windows game with its own Proton prefix.
#
# Scene releases are the other shape: an .iso holding setup.exe and a crack folder
# named after the group (RUNE/, CODEX/, ...). Their setup-1.bin is usually a
# FreeArc-style repack that only the installer's own ISDone/unarc DLLs can unpack, so
# innoextract (which mw2-install uses) gets nothing out of it -- the installer has to
# really run. It runs under the same Proton and in the same prefix Heroic will later
# launch the game with, silently, pointed at the install dir; then the crack folder
# is laid over the result.
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
    runtimeInputs = with pkgs; [ coreutils findutils gnused gnugrep jq rsync curl procps p7zip umu-launcher ];
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
      # instead of sitting beside it, as does a scene group tag ("Korea IL-2 Series-RUNE");
      # the rest is made safe for a directory name.
      clean_title() {
        sed -E -e 's/ *\([vV][0-9][^)]*\)$//' \
               -e 's/[-.](RUNE|CODEX|SKIDROW|PLAZA|TENOKE|FLT|DOGE|EMPRESS|RAZOR1911|RELOADED|HOODLUM|PROPHET|CPY|TiNYiSO|DARKSiDERS|GOG|ElAmigos|FitGirl|DODI)$//I' \
               -e 's/ *: */ - /g' -e 's#[/\\*?"<>|]##g' -e 's/  +/ /g' -e 's/^ +| +$//g'
      }

      # Lowercase alphanumerics only, for loose "does this exe look like the game" matching.
      squash() { tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]'; }

      # ---- What's in the vault -------------------------------------------------
      TITLES=()
      SOURCES=()
      add_game() { # <metadata file> <source dir> <fallback name>
        jq -e '.is_pc == true' "$1" >/dev/null 2>&1 || return 0
        [ -d "$2" ] || return 0
        local title
        title=$(jq -r '.title // empty' "$1" | clean_title)
        [ -n "$title" ] || title=$(printf '%s' "$3" | clean_title)
        TITLES+=("$title")
        SOURCES+=("$2")
      }
      # Archive grabs: <Release>.rar.gamarr.json beside <Release>.rar.extracted/
      while IFS= read -r meta; do
        add_game "$meta" "''${meta%.gamarr.json}.extracted" "$(basename "''${meta%.gamarr.json}")"
      done < <(find "$VAULT_DIR" -maxdepth 1 -name '*.gamarr.json' | sort)
      # Folder grabs: <Release>/.gamarr.json
      while IFS= read -r meta; do
        add_game "$meta" "$(dirname "$meta")" "$(basename "$(dirname "$meta")")"
      done < <(find "$VAULT_DIR" -mindepth 2 -maxdepth 2 -name '.gamarr.json' | sort)

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

      DEST="$INSTALL_DIR/$TITLE"
      PREFIX_ROOT=$(jq -r '.defaultSettings.defaultWinePrefix // empty' "$HEROIC_DIR/config.json" 2>/dev/null || true)
      [ -n "$PREFIX_ROOT" ] || PREFIX_ROOT="$HOME/Games/Heroic/Prefixes/default"
      PREFIX="$PREFIX_ROOT/$TITLE"
      mkdir -p "$INSTALL_DIR"

      mapfile -t src_exes < <(exe_candidates "$SRC")
      if [ "''${#src_exes[@]}" -gt 0 ]; then
        echo
        echo "Game:     $TITLE"
        echo "From:     $SRC"
        echo "To:       $DEST  ($(du -sh "$SRC" | cut -f1))"
        echo

        # ---- Copy a ready-to-run game -----------------------------------------------
        # Into a .partial sibling first: an interrupted copy resumes on the next run, and
        # a directory under the real name always means a finished one.
        if [ -d "$DEST" ]; then
          read -rp "Already installed. Copy it again over the top (keeps your saves in the prefix)? [y/N] " again
          if [[ "$again" =~ ^[yY] ]]; then
            rsync -rlt --info=progress2 "$SRC/" "$DEST/"
          fi
        else
          rsync -rlt --info=progress2 "$SRC/" "$DEST.partial/"
          mv "$DEST.partial" "$DEST"
        fi
      else
        # ---- Run an installer ---------------------------------------------------------
        ISO=$(find "$SRC" -maxdepth 1 -iname '*.iso' | sort | head -n1)
        SETUP=$(find "$SRC" -maxdepth 1 -iname 'setup*.exe' | sort | head -n1)
        if [ -z "$ISO" ] && [ -z "$SETUP" ]; then
          echo "\"$TITLE\" has neither a game .exe nor an installer (.iso / setup.exe) in:" >&2
          echo "  $SRC" >&2
          exit 1
        fi

        echo
        echo "Game:     $TITLE  (installer)"
        echo "From:     ''${ISO:-$SETUP}"
        echo "To:       $DEST"
        echo

        RUN_SETUP=1
        if [ -d "$DEST" ]; then
          read -rp "Already installed. Run the installer again? [y/N] " again
          [[ "$again" =~ ^[yY] ]] || RUN_SETUP=0
        fi

        if [ "$RUN_SETUP" = 1 ]; then
          # Unpacked onto the local games disk, not /tmp: these are 10-20 GB, and the
          # installer reads its .bin files far faster from here than over CIFS.
          STAGING="$INSTALL_DIR/.staging/$TITLE"
          CRACK_ROOT="$SRC"
          if [ -n "$ISO" ]; then
            # A finished unpack from an earlier attempt is reused -- 7z writes setup.exe
            # last, so its presence means the .bin files beside it are complete.
            if [ -z "$(find "$STAGING" -maxdepth 1 -iname 'setup*.exe' 2>/dev/null)" ]; then
              echo "Unpacking $(basename "$ISO") ($(du -h "$ISO" | cut -f1)) to $STAGING ..."
              mkdir -p "$STAGING"
              7z x -y -bso0 -bsp1 -o"$STAGING" "$ISO"
            fi
            SETUP=$(find "$STAGING" -maxdepth 1 -iname 'setup*.exe' | sort | head -n1)
            CRACK_ROOT="$STAGING"
            if [ -z "$SETUP" ]; then
              echo "No setup.exe inside $(basename "$ISO") -- left unpacked in $STAGING." >&2
              exit 1
            fi
          fi

          # The same Proton Heroic is set to use by default, so the prefix the installer
          # creates is one Heroic can launch from without a version upgrade in between.
          PROTON=$(jq -r 'if .defaultSettings.wineVersion.type == "proton" then .defaultSettings.wineVersion.bin else empty end' \
                     "$HEROIC_DIR/config.json" 2>/dev/null || true)
          if [ -n "$PROTON" ] && [ -x "$PROTON" ]; then
            PROTON=$(dirname "$PROTON")
          else
            PROTON="${pkgs.proton-ge-bin.steamcompattool}"
          fi

          # Which drive letter the install dir goes through matters. Repacks check free
          # space on the *drive root*, and inside Proton's container Z:\ is the
          # container's own small root (33 GB on gaming-pc), so /DIR=Z:\mnt\games\...
          # was refused with "not enough of free space on selected disk" while the
          # games disk had 370 GB. Proton maps every real mount to its own letter on
          # each start (gaming-pc: S: -> /mnt/games) and rewrites dosdevices as it does,
          # so a letter added by hand does not survive; instead the prefix is created
          # first (wineboot, no window) and the letter whose target is the deepest
          # ancestor of the install dir -- never z:, the bare / -- is used.
          echo "Preparing the Proton prefix ($(basename "$PROTON")) ..."
          mkdir -p "$DEST" "$PREFIX_ROOT"
          GAMEID="umu-0" PROTONPATH="$PROTON" WINEPREFIX="$PREFIX" PROTON_VERB=run \
            umu-run wineboot -u >/dev/null 2>&1 || true
          DOSDEV="$PREFIX/pfx/dosdevices"
          [ -d "$DOSDEV" ] || DOSDEV="$PREFIX/dosdevices"
          DRIVE=""
          DRIVE_ROOT=""
          for link in "$DOSDEV"/?:; do
            [ -L "$link" ] || continue
            target=$(readlink -f "$link")
            case "$target" in /|"$PREFIX"*) continue ;; esac
            if [[ "$DEST/" == "$target/"* ]] && [ "''${#target}" -gt "''${#DRIVE_ROOT}" ]; then
              DRIVE=$(basename "$link" | tr '[:lower:]' '[:upper:]')
              DRIVE_ROOT="$target"
            fi
          done
          if [ -z "$DRIVE" ]; then
            echo "Proton gave $INSTALL_DIR no drive letter of its own; the installer may misjudge free space." >&2
            DRIVE="Z:"
            DRIVE_ROOT=""
          fi
          rel="''${DEST#"$DRIVE_ROOT"}"
          WIN_DEST="$DRIVE''${rel//\//\\}"
          echo "Installing to $WIN_DEST"

          # Inno Setup flags: /SILENT shows the progress bar but asks nothing, and /DIR
          # takes the install dir as a Windows path.
          echo "Installing -- a setup progress window will open."
          GAMEID="umu-0" PROTONPATH="$PROTON" WINEPREFIX="$PREFIX" \
            umu-run "$SETUP" /SP- /SILENT /SUPPRESSMSGBOXES /NORESTART /NOICONS "/DIR=$WIN_DEST" || true
          # setup.exe hands off to setup.tmp (Inno's real installer) and repacks then
          # shell out to unarc; wait until none of that is left running.
          while pgrep -u "$(id -u)" -fi 'is-[a-z0-9]+[.]tmp|setup[.]tmp|unarc' >/dev/null; do
            sleep 5
          done

          if [ -z "$(exe_candidates "$DEST")" ]; then
            echo "The installer didn't put a game into $DEST." >&2
            echo "Its setup.exe is $SETUP -- try running it from Heroic's Add Game instead." >&2
            exit 1
          fi

          # The crack: every top-level folder beside setup.exe that isn't a bundled
          # redistributable mirrors the install dir's layout (RUNE/bin/game/... ->
          # bin/game/...), so it is laid straight over the top.
          for d in "$CRACK_ROOT"/*/; do
            [ -d "$d" ] || continue
            name=$(basename "$d")
            case "''${name,,}" in
              redist*|_redist|_commonredist|directx|dotnet*|vcredist*|support) continue ;;
            esac
            echo "Applying $name over the install"
            rsync -rlt "$d" "$DEST/"
          done

          if [ -n "$ISO" ]; then
            rm -rf "$STAGING"
            rmdir --ignore-fail-on-non-empty "$INSTALL_DIR/.staging"
          fi
        fi
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
      # Falls back to the part before " - ": clean_title turned "Sea Power : Naval ..."
      # into "Sea Power - Naval ...", which Steam's search no longer matches.
      steam_appid() {
        local query
        query=$(jq -rn --arg t "$1" '$t | @uri')
        curl -fsS --max-time 10 "https://store.steampowered.com/api/storesearch/?term=$query&cc=us&l=en" \
          | jq -er '.items[0].id'
      }
      ART_COVER=""
      ART_SQUARE=""
      if appid=$(steam_appid "$TITLE") || appid=$(steam_appid "''${TITLE%% - *}"); then
        ART_COVER="https://shared.steamstatic.com/store_item_assets/steam/apps/$appid/header.jpg"
        ART_SQUARE="https://shared.steamstatic.com/store_item_assets/steam/apps/$appid/library_600x900.jpg"
        curl -fsI --max-time 10 "$ART_SQUARE" >/dev/null 2>&1 || ART_SQUARE="$ART_COVER"
      fi

      APP_NAME="vault-$(printf '%s' "$TITLE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g')"

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
      echo "Once it plays, the download in $VAULT_DIR is no longer needed by this machine."
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

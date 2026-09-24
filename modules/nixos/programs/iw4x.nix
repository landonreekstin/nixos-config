# ~/nixos-config/modules/nixos/programs/iw4x.nix
{ config, pkgs, lib, ... }:

# IW4x — the community client for Call of Duty: Modern Warfare 2 (2009).
#
# IW4x is a *mod*, not a game: it needs a complete MW2 installation underneath it.
# This module therefore ships two commands rather than one:
#
#   mw2-install   one-shot: turn the two install ISOs into a playable MW2 directory
#   iw4x          sync the IW4x files into that directory, then launch the game
#
# Where the install media lives, what it contains, and the traps involved in
# unpacking it are all recorded in docs/runbooks/mw2-iw4x-source.md.
let
  cfg = config.customConfig.programs.iw4x;
  enabled = cfg.enable && config.customConfig.profiles.gaming.enable;

  # proton-ge-bin's default output is deliberately a poison-pill *file* ("should not be
  # installed into environments"); the real tree is in its `steamcompattool` output,
  # which is the directory holding the `proton` script that umu-run wants in PROTONPATH.
  protonPath = cfg.protonPackage.steamcompattool;

  # Proton is used only to RUN the game -- the install no longer touches Wine at all,
  # since innoextract unpacks Setup.exe directly. These three variables are what umu
  # needs, and getting any of them wrong fails in a differently confusing way.
  #   GAMEID=umu-0  is umu's "not a Steam game" id. umu refuses to start without one.
  #   WINEPREFIX    is deliberately a SIBLING of the game directory, not inside it, so
  #                 that the game dir stays a self-contained ~12 GB tree that can be
  #                 copied to another machine without dragging a host-specific prefix
  #                 (full of absolute /nix/store symlinks) along with it.
  umuEnv = ''
    export GAMEID="umu-0"
    export PROTONPATH="${protonPath}"
    export WINEPREFIX="${cfg.prefixDir}"
  '';

  # From docs/runbooks/mw2-iw4x-source.md. Only checked under --verify: hashing ~12 GB
  # off a CIFS mount takes several minutes and the unrar that produced these already
  # verified the release CRCs.
  isoSha256 = {
    "sr-mw2a.iso" = "d5bb15e47f1f73d674cf2933cacf81cc3dc48d7b47663c44cb3c2b552ebe5e0c";
    "sr-mw2b.iso" = "afa0ae7244fe8797beb0c3d1d56cd503725a2a34bdc00864a8c9e8d4e067e72a";
  };

  # MW2 is from 2009 and its r_mode list is a hardcoded table that stops at 1080p -- the
  # enum tops out at "1440x1080" and an unrecognised value silently falls back to index 0
  # (640x480), which is what makes a naive "just set 2560x1440" attempt look like the game
  # breaking. So the game always renders at its own ceiling and gamescope scales the result
  # up to the monitor.
  #
  # Gamescope earns its place twice over here. The second reason is multi-monitor: XWayland
  # presents every display as one large screen (on gaming-pc, three outputs as 5560x1920),
  # and Wine "fullscreen" then covers that whole rectangle, leaving the game rendered into a
  # corner with the rest black. Inside gamescope the game sees exactly one display, so the
  # question does not arise -- and r_monitor must be 0, whatever the host's physical layout.
  gs = cfg.gamescope;
  gamescopeCmd = lib.escapeShellArgs ([ "gamescope" ]
    ++ lib.optionals (gs.outputWidth != null) [ "-W" (toString gs.outputWidth) ]
    ++ lib.optionals (gs.outputHeight != null) [ "-H" (toString gs.outputHeight) ]
    ++ [ "-w" (toString gs.renderWidth) "-h" (toString gs.renderHeight) ]
    ++ lib.optionals (gs.refresh != null) [ "-r" (toString gs.refresh) ]
    ++ lib.optionals (gs.upscaler != null) [ "-F" gs.upscaler ]
    ++ [ "-f" ]
    ++ gs.extraArgs);

  mw2-install = pkgs.writeShellApplication {

    name = "mw2-install";
    runtimeInputs = [ pkgs.p7zip pkgs.innoextract pkgs.coreutils pkgs.findutils ];
    text = ''
      INSTALL_DIR="${cfg.installDir}"
      DEFAULT_MEDIA="${if cfg.mediaDir == null then "" else cfg.mediaDir}"

      # "Is MW2 actually installed here?" is NOT answerable with binkw32.dll or mss32.dll,
      # even though those are the two files the IW4x launcher itself checks for: the
      # launcher DOWNLOADS both as part of iw4x-rawfiles, so they appear in a directory
      # that has no game in it at all. (Verified 2026-09-23 by pointing the launcher at an
      # empty directory with --ignore-required-files; it produced binkw32.dll, mss32.dll,
      # iw4x.exe, iw4x.dll, zone/{dlc,patch,zonebuilder} and miles/, 775 MB in total.)
      #
      # main/*.iwd is the right marker: it is the base game's own data, 31 files of it,
      # and nothing IW4x ships ever creates it.
      has_game() {
        [ -n "$(find "$1/main" -maxdepth 1 -name '*.iwd' -print -quit 2>/dev/null)" ]
      }

      VERIFY=0
      KEEP_STAGING=0
      REEXTRACT=0
      SRC=""

      usage() {
        cat <<'USAGE'
      mw2-install [MEDIA_DIR] [--verify] [--keep-staging] [--reextract]

      Installs Call of Duty: Modern Warfare 2 (2009) from its two install ISOs, so that
      IW4x has something to sit on top of. Run `iw4x` afterwards to play.

        MEDIA_DIR       directory holding sr-mw2a.iso and sr-mw2b.iso.
                        Defaults to the host's configured mediaDir.
        --verify        check both ISO sha256s before unpacking (slow: ~12 GB).
        --keep-staging  don't delete the ~24 GB of intermediates afterwards.
        --reextract     redo a stage even if its output is already present.

      Needs roughly 37 GB free while it runs (12 GB unpacked ISOs + 12 GB extracted
      payload + 13 GB installed game), settling to ~13 GB once staging is removed.
      USAGE
      }

      for arg in "$@"; do
        case "$arg" in
          --verify)       VERIFY=1 ;;
          --keep-staging) KEEP_STAGING=1 ;;
          --reextract)    REEXTRACT=1 ;;
          -h|--help)      usage; exit 0 ;;
          -*)             echo "mw2-install: unknown option $arg" >&2; usage >&2; exit 2 ;;
          *)              SRC="$arg" ;;
        esac
      done

      # Everything this writes -- staging, the game directory -- has to be owned by
      # whoever plays the game. Run as root it all lands root-owned, and the first thing
      # that breaks is the IW4x launcher trying to write its own files into the game
      # directory, with an error that points nowhere near the cause.
      if [ "$(id -u)" = 0 ]; then
        echo "mw2-install: do not run this as root." >&2
        echo "Run it as the user who will play the game." >&2
        exit 1
      fi

      if has_game "$INSTALL_DIR"; then
        echo "mw2-install: MW2 already installed at $INSTALL_DIR" >&2
        echo "Delete that directory first if you want to reinstall." >&2
        exit 1
      fi

      # Both intermediates sit next to the install directory rather than in /tmp: they
      # hold ~12 GB each, and being on the same filesystem as INSTALL_DIR makes the final
      # move a rename instead of another 12 GB copy.
      STAGE="$(dirname "$INSTALL_DIR")/.mw2-staging"
      EXTRACT="$(dirname "$INSTALL_DIR")/.mw2-extract"

      # ---------------------------------------------------------------- stage 1: ISOs
      # Each stage is skipped when its output is already there. The whole run is ~25 GB
      # of I/O, so a failure in a later stage must not cost the earlier ones again.
      if [ -f "$STAGE/Setup.exe" ] && [ "$REEXTRACT" = 0 ]; then
        echo "==> Reusing already-unpacked media in $STAGE"
      else
        if [ -z "$SRC" ]; then
          SRC="$DEFAULT_MEDIA"
        fi
        if [ -z "$SRC" ]; then
          echo "mw2-install: no media directory given and this host sets no mediaDir." >&2
          echo "Pass the directory holding sr-mw2a.iso / sr-mw2b.iso as an argument." >&2
          exit 1
        fi

        # Touching the path is what triggers the NAS automount; do it before complaining
        # that the files are missing, or a cold mount looks like missing media.
        ls "$SRC" >/dev/null 2>&1 || true

        for iso in sr-mw2a.iso sr-mw2b.iso; do
          if [ ! -f "$SRC/$iso" ]; then
            echo "mw2-install: $SRC/$iso not found" >&2
            exit 1
          fi
        done

        if [ "$VERIFY" = 1 ]; then
          echo "==> Verifying ISO checksums (this reads ~12 GB)"
          echo "${isoSha256."sr-mw2a.iso"}  $SRC/sr-mw2a.iso" | sha256sum -c -
          echo "${isoSha256."sr-mw2b.iso"}  $SRC/sr-mw2b.iso" | sha256sum -c -
        fi

        echo "==> Unpacking install media into $STAGE"
        # Both ISOs go into ONE directory on purpose: Setup.exe is an Inno Setup
        # installer whose payload is split across Setup-1*.bin (disc 1) and Setup-2*.bin
        # (disc 2), and innoextract below needs every slice in one place.
        #
        # The images are plain ISO9660, so 7z reads them and no privileged loop-mount is
        # needed. (docs/runbooks/mw2-iw4x-source.md, trap 2.)
        rm -rf "$STAGE"
        mkdir -p "$STAGE"
        7z x -y -o"$STAGE" "$SRC/sr-mw2a.iso" >/dev/null
        7z x -y -o"$STAGE" "$SRC/sr-mw2b.iso" >/dev/null
      fi

      if [ ! -f "$STAGE/Setup.exe" ]; then
        echo "mw2-install: no Setup.exe after unpacking -- wrong media?" >&2
        exit 1
      fi

      # ------------------------------------------------------------ stage 2: the payload
      # Setup.exe is Inno Setup 5.3.3 and the Setup-*.bin files are its data slices --
      # the "idska32" magic that made 7z refuse them is Inno's slice signature, not an
      # unknown container. innoextract reads them directly, so the game is unpacked here
      # WITHOUT running the installer under Wine at all.
      #
      # That matters beyond convenience: the installer's skinned UI calls ISSkin.dll,
      # which fails under Proton with "cannot import dll: ...\is-XXXXX.tmp\isskin.dll"
      # and leaves a black window. There is no click-through path past it. Extracting is
      # not a workaround for that bug, it is simply the better method -- it needs no
      # display, no prefix and no interaction, which is also what makes this script
      # runnable over SSH.
      if [ -d "$EXTRACT/app" ] && [ -n "$(find "$EXTRACT/app/main" -maxdepth 1 -name '*.iwd' -print -quit 2>/dev/null)" ] && [ "$REEXTRACT" = 0 ]; then
        echo "==> Reusing already-extracted payload in $EXTRACT"
      else
        echo "==> Extracting the game from Setup.exe (~12 GB, no Wine needed)"
        rm -rf "$EXTRACT"
        mkdir -p "$EXTRACT"
        # -m drops Inno's temporary files (the installer's own scaffolding, including
        # ISSkin.dll), leaving just the game payload under app/.
        ( cd "$STAGE" && innoextract -e -m -d "$EXTRACT" Setup.exe )
      fi

      if [ ! -d "$EXTRACT/app" ]; then
        echo "mw2-install: innoextract produced no app/ directory" >&2
        exit 1
      fi

      # -------------------------------------------------------------- stage 3: install
      echo "==> Moving the game to $INSTALL_DIR"
      mkdir -p "$INSTALL_DIR"
      find "$EXTRACT/app" -mindepth 1 -maxdepth 1 -exec mv -t "$INSTALL_DIR" -- {} +

      # Step 4 of the release's own instructions: the SKIDROW directory on disc 2 holds
      # DRM-free replacements for the stock executables, and overwrites what was just
      # installed. These are MW2's own iw4mp/iw4sp binaries -- nothing to do with IW4x,
      # which ships its own client -- but the install is not complete without them.
      echo "==> Applying the SKIDROW files"
      skidrow="$(find "$STAGE" -maxdepth 2 -type d -iname SKIDROW -print -quit 2>/dev/null || true)"
      if [ -z "$skidrow" ]; then
        echo "mw2-install: no SKIDROW directory in the unpacked media" >&2
        exit 1
      fi
      cp -f "$skidrow"/* "$INSTALL_DIR/"

      # Completeness check. The game data has to be there, and so do the two DRM-free
      # executables just copied over it -- if the SKIDROW step silently did nothing, this
      # is where it gets caught rather than at first launch.
      if ! has_game "$INSTALL_DIR"; then
        echo "mw2-install: no main/*.iwd in $INSTALL_DIR -- install is incomplete" >&2
        exit 1
      fi
      for required in iw4mp.exe iw4sp.exe; do
        if [ ! -f "$INSTALL_DIR/$required" ]; then
          echo "mw2-install: $required missing from $INSTALL_DIR -- the SKIDROW step failed" >&2
          exit 1
        fi
      done

      if [ "$KEEP_STAGING" = 1 ]; then
        echo "==> Leaving staging at $STAGE and $EXTRACT"
      else
        echo "==> Removing staging"
        rm -rf "$STAGE" "$EXTRACT"
      fi

      echo
      echo "MW2 installed at $INSTALL_DIR"
      echo "Run 'iw4x' to install the IW4x files and play."
    '';
  };

  iw4x = pkgs.writeShellApplication {
    name = "iw4x";
    runtimeInputs = [ pkgs.iw4x-launcher pkgs.umu-launcher pkgs.libnotify ]
      ++ lib.optional gs.enable pkgs.gamescope;
    text = ''
      INSTALL_DIR="${cfg.installDir}"
      ${umuEnv}

      # Launched from the applications menu there is no terminal, so stderr goes nowhere.
      # Anything the user needs to see has to become a desktop notification too.
      say() {
        echo "iw4x: $*" >&2
        if [ ! -t 2 ]; then
          notify-send -a IW4x -i applications-games "IW4x" "$*" 2>/dev/null || true
        fi
      }

      if [ "$(id -u)" = 0 ]; then
        echo "iw4x: do not run this as root." >&2
        echo "The launcher writes into the game directory and Proton writes into the" >&2
        echo "prefix; as root both end up owned by root and break for the real user." >&2
        exit 1
      fi

      # Deliberately NOT checking binkw32.dll/mss32.dll here, even though those are what
      # the IW4x launcher checks: the launcher downloads them itself, so they are present
      # in a directory containing no game. main/*.iwd is the base game's own data and is
      # the only honest test. (See the same note in mw2-install.)
      if [ -z "$(find "$INSTALL_DIR/main" -maxdepth 1 -name '*.iwd' -print -quit 2>/dev/null)" ]; then
        say "No MW2 installation at $INSTALL_DIR. Run mw2-install first."
        exit 1
      fi

      # --skip-self-update is NOT optional: the launcher updates itself by rewriting its
      # own executable, which here is a read-only /nix/store path. Nix owns the launcher
      # version; bump it with a nixpkgs update.
      #
      # --update makes it sync game files and stop, rather than also launching. We launch
      # ourselves below because its own Linux launch path probes $PATH for a binary named
      # `umu` (src/game.rs), while nixpkgs installs `umu-run` -- so left to itself it
      # would silently fall through to plain wine, losing Proton's 32-bit D3D9 support.
      # The update must NOT be able to stop the game starting. This script runs under
      # `set -e`, so a bare call here aborts on any non-zero exit -- and because the
      # desktop entry has no terminal, that looks like clicking the icon does nothing at
      # all. It happened on 2026-09-23: the NAS (which is the LAN's DNS resolver) had
      # Mullvad blocked, name resolution failed for the whole network, the launcher exited
      # non-zero 10ms in, and the game silently never launched.
      #
      # The game is already installed by this point. A failed update check is a reason to
      # warn, not a reason to refuse to play.
      # stdin from /dev/null: on failure the launcher prints "Press Enter to exit.." and
      # blocks on a read. Launched from the menu that would be an invisible hang rather
      # than a failed update, so never give it a stdin to wait on.
      if ! iw4x-launcher --update --skip-self-update --path "$INSTALL_DIR" </dev/null; then
        say "Update check failed -- network problem? Launching the installed version."
      fi

      # ...unless the client itself was never synced, in which case there is nothing to
      # launch and saying so beats Proton failing on a missing exe.
      if [ ! -f "$INSTALL_DIR/iw4x.exe" ]; then
        say "IW4x client is missing and the update failed. Check the network, then run iw4x again."
        exit 1
      fi

      cd "$INSTALL_DIR"
      ${if gs.enable then ''
        exec ${gamescopeCmd} -- umu-run "$INSTALL_DIR/iw4x.exe" "$@"
      '' else ''
        exec umu-run "$INSTALL_DIR/iw4x.exe" "$@"
      ''}
    '';
  };

  iw4x-desktop = pkgs.makeDesktopItem {
    name = "iw4x";
    desktopName = "IW4x";
    genericName = "Modern Warfare 2 Multiplayer";
    comment = "Call of Duty: Modern Warfare 2 (2009) on community servers";
    exec = "iw4x";
    icon = "applications-games";
    terminal = false;
    categories = [ "Game" "ActionGame" ];
    keywords = [ "mw2" "call of duty" "modern warfare" "iw4x" "multiplayer" ];
  };
in
{
  options.customConfig.programs.iw4x = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Install IW4x, the community client for Call of Duty: Modern Warfare 2 (2009),
        along with an `mw2-install` command that builds the base game from its install
        ISOs. Requires customConfig.profiles.gaming.enable.
      '';
    };

    installDir = mkOption {
      type = types.str;
      default = "${config.customConfig.user.home}/Games/mw2";
      defaultText = literalExpression ''"''${config.customConfig.user.home}/Games/mw2"'';
      description = ''
        Where the MW2 installation lives. Needs ~13 GB, plus ~12 GB alongside it while
        `mw2-install` is unpacking. Point this at a games disk on hosts that have one.
      '';
    };

    prefixDir = mkOption {
      type = types.str;
      default = "${cfg.installDir}.prefix";
      defaultText = literalExpression ''"''${installDir}.prefix"'';
      description = ''
        The Proton/Wine prefix. Deliberately outside installDir so the game directory
        stays portable between machines.
      '';
    };

    mediaDir = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/mnt/nas/games/installers/Call Of Duty Modern Warfare 2 [English][PC][2DVDs]";
      description = ''
        Default directory holding sr-mw2a.iso and sr-mw2b.iso, used by `mw2-install`
        when it is run without an argument. Null means the path must be passed in.
      '';
    };

    gamescope = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Run the game inside gamescope. On by default, and you almost certainly want it:
          it is what lets a 1080p-capped 2009 engine fill a higher-resolution monitor, and
          it is what stops Wine treating a multi-monitor XWayland screen as one giant
          display. Turn it off only to debug something.
        '';
      };
      renderWidth = mkOption {
        type = types.int;
        default = 1920;
        description = "Resolution the game renders at. 1920x1080 is MW2's hard ceiling.";
      };
      renderHeight = mkOption {
        type = types.int;
        default = 1080;
        description = "See renderWidth.";
      };
      outputWidth = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = 2560;
        description = ''
          Resolution gamescope scales up to. Null lets it use the display's native mode,
          which is usually right; set it explicitly when you want a specific monitor's
          resolution rather than whichever one the window lands on.
        '';
      };
      outputHeight = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = 1440;
        description = "See outputWidth.";
      };
      refresh = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = 180;
        description = ''
          Refresh rate cap for the nested display. Null leaves it to gamescope. Note this
          is separate from the game's own r_displayRefresh, which lives in
          players/iw4x_config.cfg and describes the virtual display gamescope provides.
        '';
      };
      upscaler = mkOption {
        type = types.nullOr types.str;
        default = "fsr";
        description = "gamescope -F filter: linear, nearest, fsr, nis or pixel.";
      };
      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Extra gamescope arguments appended verbatim.";
      };
    };

    protonPackage = mkOption {
      type = types.package;
      default = pkgs.proton-ge-bin;
      defaultText = literalExpression "pkgs.proton-ge-bin";
      description = ''
        Proton build used to run the installer and the game. MW2 is a 32-bit D3D9 title,
        which Proton handles considerably better than current nixpkgs wine (26.05
        deprecated the multilib wineWowPackages in favour of new-WoW64, which loses
        hardware GL for 32-bit applications).
      '';
    };
  };

  # The assertion is deliberately OUTSIDE the mkIf below. Inside it, the same condition
  # that makes the config vanish would also suppress the assertion, so a host that set
  # iw4x.enable without gaming.enable would get silence instead of an error -- which is
  # exactly the failure mode this is here to prevent.
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.enable || config.customConfig.profiles.gaming.enable;
          message = "customConfig.programs.iw4x.enable requires customConfig.profiles.gaming.enable.";
        }
      ];
    }

    (lib.mkIf enabled {
      environment.systemPackages = [
        pkgs.iw4x-launcher
        pkgs.umu-launcher
        pkgs.p7zip
        mw2-install
        iw4x
        iw4x-desktop
      ];
    })
  ];
}

# ~/nixos-config/modules/nixos/services/ios-device.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.services.iosDevice;

  # Open the mount in the host's configured graphical file manager rather than
  # xdg-open: on gaming-pc the inode/directory MIME default is kitty, so xdg-open
  # would drop you in a terminal instead of Dolphin.
  fileManager = config.customConfig.apps.programs.fileManager.command;

  # Same reasoning for the gallery: blaney-pc's browser is a Flatpak
  # (`flatpak run org.chromium.Chromium`), so xdg-open or a hardcoded package
  # would both be wrong. The registry is the only thing that knows.
  browser = config.customConfig.apps.programs.browser.command;

  pythonEnv = pkgs.python3;

  # One command for a non-technical user: plug the phone in, type `photos`, end up
  # looking at the gallery. Tool paths are passed by absolute store path so nothing
  # depends on what happens to be on PATH.
  photos = pkgs.writeShellScriptBin "photos" ''
    #!${pkgs.stdenv.shell}
    set -uo pipefail

    export IOS_IFUSE=${pkgs.ifuse}/bin/ifuse
    export IOS_RSYNC=${pkgs.rsync}/bin/rsync
    export IOS_EXIFTOOL=${pkgs.exiftool}/bin/exiftool
    export IOS_FFMPEG=${pkgs.ffmpeg}/bin/ffmpeg
    export IOS_MAGICK=${pkgs.imagemagick}/bin/magick
    export IOS_IDEVICE_ID=${pkgs.libimobiledevice}/bin/idevice_id
    export IOS_IDEVICEPAIR=${pkgs.libimobiledevice}/bin/idevicepair
    export IOS_IDEVICEINFO=${pkgs.libimobiledevice}/bin/ideviceinfo
    export IOS_BROWSER=${lib.escapeShellArg browser}

    # ifuse links fuse 2.x, so the unmount helper is `fusermount`, not fusermount3,
    # and only the setuid NixOS wrapper works unprivileged.
    IOS_FUSERMOUNT=/run/wrappers/bin/fusermount
    [ -x "$IOS_FUSERMOUNT" ] || IOS_FUSERMOUNT=${pkgs.fuse}/bin/fusermount
    export IOS_FUSERMOUNT

    exec ${pythonEnv}/bin/python3 ${./ios-photos-src/photo_tool.py} "$@" \
      --archive ${lib.escapeShellArg cfg.photos.archive} \
      --gallery ${lib.escapeShellArg cfg.photos.gallery}
  '';

  # The Linux equivalent of iTunes' "Device -> Apps -> File Sharing" pane. That pane
  # is not an iTunes feature: it drives an iOS service (com.apple.mobile.house_arrest)
  # over AFC on USB, which libimobiledevice implements in full. `ifuse --list-apps` is
  # the app list, `ifuse --documents <appid>` is the Documents pane for one app. This
  # wrapper just glues them together with a numbered menu so no bundle IDs need
  # memorising, matching the branch-switch/blaney-todo picker style.
  #
  # ifuse here links fuse 2.x, so the unmount helper is `fusermount`, not fusermount3.
  # The store copy isn't setuid — only the NixOS security wrapper works unprivileged.
  iphone = pkgs.writeShellScriptBin "iphone" ''
    #!${pkgs.stdenv.shell}
    set -uo pipefail

    IFUSE=${pkgs.ifuse}/bin/ifuse
    IDEVICE_ID=${pkgs.libimobiledevice}/bin/idevice_id
    IDEVICEPAIR=${pkgs.libimobiledevice}/bin/idevicepair
    IDEVICEINFO=${pkgs.libimobiledevice}/bin/ideviceinfo
    MOUNTPOINT=${pkgs.util-linux}/bin/mountpoint
    FUSERMOUNT=/run/wrappers/bin/fusermount
    [ -x "$FUSERMOUNT" ] || FUSERMOUNT=${pkgs.fuse}/bin/fusermount
    BASE=${lib.escapeShellArg cfg.mountBase}
    FILEMANAGER=${lib.escapeShellArg fileManager}

    usage() {
      cat <<'USAGE'
    Usage: iphone [APP]        pick an app (or match APP) and mount its Documents folder
           iphone -l           list apps that have File Sharing enabled
           iphone -u           unmount everything mounted by this command
           iphone -h           this help

    The app list is the same one iTunes shows under Device -> Apps -> File Sharing:
    only apps whose Info.plist sets UIFileSharingEnabled can be reached this way.
    USAGE
    }

    # Unmount every ifuse mount under $BASE and tidy up the empty directories.
    unmount_all() {
      local found=0 d
      if [ -d "$BASE" ]; then
        for d in "$BASE"/*; do
          [ -d "$d" ] || continue
          if "$MOUNTPOINT" -q "$d"; then
            if "$FUSERMOUNT" -u "$d"; then
              echo "Unmounted $d"
              found=1
            else
              echo "Could not unmount $d — is something still using it?" >&2
            fi
          fi
          rmdir "$d" 2>/dev/null || true
        done
        rmdir "$BASE" 2>/dev/null || true
      fi
      [ "$found" = 1 ] || echo "Nothing was mounted."
    }

    # Device present, unlocked and trusted? Everything below needs all three.
    require_device() {
      if [ -z "$("$IDEVICE_ID" -l 2>/dev/null)" ]; then
        echo "No iPhone found. Plug it in with a cable and unlock the screen." >&2
        exit 1
      fi
      if ! "$IDEVICEPAIR" validate >/dev/null 2>&1; then
        echo "Pairing with the device..."
        if ! "$IDEVICEPAIR" pair; then
          echo "Pairing failed. Unlock the phone, tap 'Trust' on its screen, then run this again." >&2
          exit 1
        fi
      fi
      local name version
      name=$("$IDEVICEINFO" -k DeviceName 2>/dev/null)
      version=$("$IDEVICEINFO" -k ProductVersion 2>/dev/null)
      echo "Connected: ''${name:-iPhone} (iOS ''${version:-?})"
    }

    # ifuse --list-apps prints CSV with a header row:
    #   "CFBundleIdentifier","CFBundleVersion","CFBundleDisplayName"
    # Emit "<bundle id><TAB><display name>" rows, skipping that header.
    list_apps() {
      "$IFUSE" --list-apps 2>/dev/null | ${pkgs.gawk}/bin/awk -F'","' '
        NR > 1 && NF >= 3 {
          id = $1; sub(/^"/, "", id)
          name = $3; sub(/"$/, "", name)
          if (name == "") name = id
          printf "%s\t%s\n", id, name
        }'
    }

    mount_app() {
      local appid="$1" label="$2" dir
      # Display names are free-form; only a path separator actually breaks things.
      dir="$BASE/''${label//\//_}"

      if "$MOUNTPOINT" -q "$dir"; then
        echo "Already mounted at $dir"
      else
        mkdir -p "$dir" || exit 1
        local err
        if ! err=$("$IFUSE" "$dir" --documents "$appid" 2>&1); then
          echo "$err" >&2
          rmdir "$dir" 2>/dev/null || true
          case "$err" in
            *house_arrest*)
              echo >&2
              echo "The FUSE mount was refused by the device. An FTP-style session avoids" >&2
              echo "FUSE entirely and usually still works:" >&2
              echo "  afcclient --documents $appid" >&2
              ;;
          esac
          exit 1
        fi
        echo "Mounted $appid at $dir"
      fi

      # Intentionally unquoted: the registry command may carry arguments.
      # shellcheck disable=SC2086
      if [ -n "$FILEMANAGER" ]; then
        $FILEMANAGER "$dir" >/dev/null 2>&1 &
      else
        ${pkgs.xdg-utils}/bin/xdg-open "$dir" >/dev/null 2>&1 &
      fi
      echo "Unmount when you're done with:  iphone -u"
    }

    case "''${1-}" in
      -h|--help)     usage; exit 0 ;;
      -u|--unmount)  unmount_all; exit 0 ;;
      -l|--list)     require_device; list_apps | ${pkgs.coreutils}/bin/cut -f2-; exit 0 ;;
    esac

    if [ "$(id -u)" -eq 0 ]; then
      echo "Run this as your normal user, not with sudo — the mount belongs to whoever creates it." >&2
      exit 1
    fi

    require_device

    mapfile -t APPS < <(list_apps)
    if [ "''${#APPS[@]}" -eq 0 ]; then
      echo "No apps with File Sharing enabled were found on the device." >&2
      echo "That's the same set iTunes would show — apps that only use the Files app don't appear." >&2
      exit 1
    fi

    # A name/bundle-id argument skips the menu entirely.
    if [ -n "''${1-}" ]; then
      MATCHES=()
      for entry in "''${APPS[@]}"; do
        if [[ "''${entry,,}" == *"''${1,,}"* ]]; then MATCHES+=("$entry"); fi
      done
      if [ "''${#MATCHES[@]}" -eq 1 ]; then
        mount_app "''${MATCHES[0]%%$'\t'*}" "''${MATCHES[0]#*$'\t'}"
        exit 0
      elif [ "''${#MATCHES[@]}" -eq 0 ]; then
        echo "No app matching '$1'. Showing the full list instead."
      else
        echo "Several apps match '$1'. Pick one:"
        APPS=("''${MATCHES[@]}")
      fi
    fi

    echo
    echo "Apps with File Sharing enabled:"
    for i in "''${!APPS[@]}"; do
      printf "  %d) %s\n" $((i + 1)) "''${APPS[$i]#*$'\t'}"
    done
    echo

    read -rp "Enter a number (or q to cancel): " CHOICE
    [ "$CHOICE" = q ] && { echo "Cancelled — nothing mounted."; exit 0; }
    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] \
         || [ "$CHOICE" -gt "''${#APPS[@]}" ]; then
      echo "That wasn't a valid choice. Nothing mounted."
      exit 1
    fi

    SELECTED="''${APPS[$((CHOICE - 1))]}"
    mount_app "''${SELECTED%%$'\t'*}" "''${SELECTED#*$'\t'}"
  '';
in
{
  options.customConfig.services.iosDevice = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable access to a USB-connected iPhone/iPad, including the equivalent of
        iTunes' "Apps -> File Sharing" pane. Runs usbmuxd and provides the `iphone`
        command, which lists the apps with UIFileSharingEnabled and mounts the
        chosen app's Documents folder locally so any file manager can use it.
      '';
    };

    mountBase = mkOption {
      type = types.str;
      default = "${config.customConfig.user.home}/iphone";
      defaultText = literalExpression ''"''${config.customConfig.user.home}/iphone"'';
      description = ''
        Parent directory the `iphone` command mounts into, one subdirectory per app.
        Created on demand and removed again on unmount, so nothing persists on disk.
      '';
    };

    photos = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Provide the `photos` command: copies the camera roll off a USB-connected
          iPhone/iPad, reconstructs dates and albums from the device's Photos
          database, and builds a static HTML gallery. One command start to finish,
          so it is usable without knowing any of the underlying tools.
        '';
      };

      archive = mkOption {
        type = types.str;
        default = "${config.customConfig.user.home}/ios-archive";
        defaultText = literalExpression ''"''${config.customConfig.user.home}/ios-archive"'';
        description = ''
          Where the untouched copy of each device's media lives, one directory per
          device. Only ever appended to; the organized views are hardlinks into it.
        '';
      };

      gallery = mkOption {
        type = types.str;
        default = "${config.customConfig.user.home}/photos";
        defaultText = literalExpression ''"''${config.customConfig.user.home}/photos"'';
        description = ''
          Where the browsable output goes: by-date/, by-album/, by-device/, the
          HEIC-to-JPEG conversions, and gallery/index.html. Hardlinked from the
          archive, so it costs almost no extra disk.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Multiplexes connections over USB to the device. Without it nothing —
    # not ifuse, not the idevice* tools — can see an attached iPhone at all.
    services.usbmuxd.enable = true;

    environment.systemPackages = [
      pkgs.libimobiledevice # idevice_id, ideviceinfo, idevicepair, afcclient
      pkgs.ifuse            # the FUSE mount of an app's Documents folder
      pkgs.ideviceinstaller # app listing/install, incl. bundle-id lookup
      iphone
    ] ++ lib.optional cfg.photos.enable photos;
  };
}

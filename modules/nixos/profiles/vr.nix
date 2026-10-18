# ~/nixos-config/modules/nixos/profiles/vr.nix
#
# PC VR on a standalone headset (Quest 2) streamed over USB with WiVRn.
#
#   game ──OpenXR──▶ WiVRn (Monado runtime + NVENC encoder) ──adb reverse, USB──▶ WiVRn app on the headset
#
# * OpenXR games (DCS: GE-Proton's wineopenxr) talk to WiVRn directly; Steam's
#   pressure-vessel imports the runtime because of steam.importOXRRuntimes.
# * OpenVR games go through xrizer, which the wivrn package already has on its
#   OVR_COMPAT_SEARCH_PATH — WiVRn writes ~/.config/openvr/openvrpaths.vrpath itself.
# * Plugging the headset in is the whole workflow: a udev rule starts vr-connect,
#   which installs/upgrades the matching headset app, reverses the port and opens it.
#
# Bitrate and resolution scale are NOT here: WiVRn keeps them in the headset app's
# settings at runtime (config.json has no keys for them). See docs/vr.md.
{ config, pkgs, lib, ... }:
let
  cfg = config.customConfig.profiles.vr;

  # NVENC needs the CUDA build; it is not the default because cudaSupport is off globally.
  wivrn = pkgs.wivrn.override { cudaSupport = true; };

  # The headset app and the server must be the exact same version or the client
  # refuses to connect. Pin the GitHub release APK per server version: when a
  # weekly update moves pkgs.wivrn, the assertion below fails evaluation instead of
  # silently installing a mismatched client.
  apkHashes = {
    "26.6.2" = "19qrj8ffvl566na92zba02sx6734k64mpbmvpk4jgii21gdaadgp";
  };
  clientApk = pkgs.fetchurl {
    url = "https://github.com/WiVRn/WiVRn/releases/download/v${wivrn.version}/WiVRn-release.apk";
    sha256 = apkHashes.${wivrn.version} or lib.fakeSha256;
  };
  # GitHub release builds use this package id (the Meta Store build is org.meumeu.wivrn).
  clientPackage = "org.meumeu.wivrn.github";

  adb = "${pkgs.android-tools}/bin/adb";

  # 7900X3D: "cache" makes the scheduler prefer the V-Cache CCD (what DCS wants),
  # "frequency" the high-clock one. The udev rule below makes it gamemode-group writable.
  x3dMode = pkgs.writeShellScript "x3d-mode" ''
    for f in /sys/bus/platform/drivers/amd_x3d_vcache/*/amd_x3d_mode; do
      [ -w "$f" ] && echo "$1" > "$f"
    done
    true
  '';

  vr-client-install = pkgs.writeShellScriptBin "vr-client-install" ''
    set -euo pipefail
    echo "Installing WiVRn ${wivrn.version} headset app..."
    ${adb} install -r ${clientApk}
  '';

  vr-connect = pkgs.writeShellScriptBin "vr-connect" ''
    set -uo pipefail
    notify() { ${pkgs.libnotify}/bin/notify-send -a "VR" -i io.github.wivrn.wivrn "$@" 2>/dev/null || true; echo "$*"; }

    # Waits through the "Allow USB debugging?" prompt in the headset, which only
    # needs answering once if "Always allow" is ticked.
    notify "Headset detected" "Put it on and allow USB debugging if asked"
    if ! timeout 300 ${adb} wait-for-usb-device; then
      notify "VR: headset not authorised" "adb never reached 'device' — is Developer Mode on and USB debugging allowed?"
      exit 1
    fi
    # Plugged in while the headset is booting: adb answers before the package
    # service exists, so dumpsys reads "none" and the install fails.
    timeout 180 ${adb} shell 'while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 1; done'

    installed=$(${adb} shell dumpsys package ${clientPackage} 2>/dev/null \
      | sed -n 's/^ *versionName=//p' | head -n1 | tr -d '\r')
    if [ "$installed" != "${wivrn.version}" ]; then
      notify "VR: installing headset app" "WiVRn ''${installed:-none} → ${wivrn.version}"
      ${vr-client-install}/bin/vr-client-install || { notify "VR: app install failed"; exit 1; }
    fi
    if ${adb} shell pm path org.meumeu.wivrn >/dev/null 2>&1; then
      echo "note: the Meta Store WiVRn app is also installed; using the ${clientPackage} build"
    fi

    systemctl --user start wivrn.service
    ${adb} reverse tcp:9757 tcp:9757
    ${adb} shell am start -a android.intent.action.VIEW -d "wivrn+tcp://localhost" ${clientPackage} >/dev/null
    notify "VR connected" "WiVRn ${wivrn.version} over USB"

    # Prefer the V-Cache CCD for the whole headset session. gamemoderun can't do it
    # for Proton games: it is a /nix/store bash script, and inside Steam's runtime it
    # loads the runtime's libc and dies (undefined symbol __pointer_chk_guard).
    ${x3dMode} cache
    trap '${x3dMode} frequency' EXIT

    # The reverse tunnel lives in the adb server, which is in this unit's cgroup:
    # stay alive until the headset is unplugged so systemd doesn't reap it.
    ${adb} wait-for-usb-disconnect
    ${adb} kill-server
  '';

  # One-shot Steam/prefix setup for DCS World (Steam appid 223750). Idempotent.
  dcsAppId = "223750";
  vdfEdit = pkgs.writers.writePython3 "dcs-vr-vdf" { libraries = [ pkgs.python3Packages.vdf ]; } ''
    import glob
    import os
    import sys

    import vdf

    steam, appid, launch_opts, tool = sys.argv[1:5]


    def child(d, key):
        # Steam is inconsistent about key case ("apps" vs "Apps").
        for k in d:
            if k.lower() == key.lower():
                return d[k]
        d[key] = vdf.VDFDict() if isinstance(d, vdf.VDFDict) else {}
        return d[key]


    def put(d, key, value):
        # VDFDict keeps duplicate keys, and `d[key] = v` APPENDS another one; Steam
        # then reads the stale first entry. Drop every existing copy first.
        for k in [k for k in d if k.lower() == key.lower()]:
            d.remove_all_for(k)
        d[key] = value


    def edit(path, fn):
        with open(path, encoding="utf-8") as f:
            data = vdf.load(f, mapper=vdf.VDFDict, escaped=False)
        fn(data)
        tmp = path + ".dcs-vr-tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            vdf.dump(data, f, pretty=True, escaped=False)
        os.replace(tmp, path)
        print("updated", path)


    def compat(data):
        m = child(child(child(child(child(data, "InstallConfigStore"),
                  "Software"), "Valve"), "Steam"), "CompatToolMapping")
        # Keep a GE-Proton build picked by hand in Steam (e.g. GE-Proton10-34
        # from protonup-qt); only fall back to the Nix-provided one.
        current = m.get(appid, {}).get("name", "")
        if current.startswith("GE-Proton"):
            print("keeping compat tool", current)
            return
        put(m, appid, {"name": tool, "config": "", "priority": "250"})


    edit(os.path.join(steam, "config", "config.vdf"), compat)


    def launch(data):
        apps = child(child(child(child(child(data, "UserLocalConfigStore"),
                     "Software"), "Valve"), "Steam"), "apps")
        put(child(apps, appid), "LaunchOptions", launch_opts)


    for p in glob.glob(os.path.join(steam, "userdata", "*", "config",
                                    "localconfig.vdf")):
        edit(p, launch)
  '';

  dcs-vr-setup = pkgs.writeShellScriptBin "dcs-vr-setup" ''
    set -euo pipefail
    STEAM="$HOME/.local/share/Steam"
    APPID=${dcsAppId}
    MODE="''${1:-vr}"

    # No double quotes in here: localconfig.vdf is written unescaped (see dcs-vr-vdf).
    common='PROTON_ENABLE_NVAPI=1 WINEDLLOVERRIDES=wbemprox=n %command% --no-launcher'
    case "$MODE" in
      vr)   OPTS="$common --force_enable_VR --force_OpenXR" ;;
      flat) OPTS="$common" ;;
      *)    echo "usage: dcs-vr-setup [vr|flat]" >&2; exit 2 ;;
    esac

    if pgrep -u "$(id -u)" steamwebhelper >/dev/null; then
      echo "Steam is running — it rewrites its config on exit. Quit Steam fully and re-run." >&2
      exit 1
    fi

    # Find the library DCS is installed in.
    LIB=""
    for l in $(sed -n 's/^\s*"path"\s*"\(.*\)"/\1/p' "$STEAM/steamapps/libraryfolders.vdf"); do
      [ -f "$l/steamapps/appmanifest_$APPID.acf" ] && LIB="$l" && break
    done
    if [ -z "$LIB" ]; then
      echo "DCS World is not installed yet. Install it in Steam (steam steam://install/$APPID), then re-run." >&2
      exit 1
    fi
    echo "DCS library: $LIB"

    echo "== Steam: GE-Proton + $MODE launch options"
    ${vdfEdit} "$STEAM" "$APPID" "$OPTS" GE-Proton

    PREFIX="$LIB/steamapps/compatdata/$APPID/pfx"
    if [ ! -d "$PREFIX/drive_c" ]; then
      echo
      echo "The Proton prefix doesn't exist yet. Start DCS once from Steam (let it reach"
      echo "the main menu), quit, then run dcs-vr-setup again to finish the prefix setup."
      exit 0
    fi

    # Under GE-Proton10-34, a Wine command whose stderr goes to a file under /tmp
    # prints nothing on stdout. winetricks redirects stderr to its temp dir
    # (TMPDIR, else /tmp), so every %AppData% lookup came back empty and it
    # aborted. Any temp dir outside /tmp works.
    export TMPDIR="''${XDG_CACHE_HOME:-$HOME/.cache}/dcs-vr-setup"
    mkdir -p "$TMPDIR"

    echo "== Prefix: winetricks components"
    # Nice-to-haves from the standalone-DCS guide, not VR requirements: GE-Proton
    # already ships d3dcompiler_47 and xact (FAudio). Under GE-Proton10-34 the 32-bit regedit these
    # verbs use has segfaulted (139) — consolas once, xact every time so far — so a
    # failure is reported and skipped rather than aborting before the VR keys.
    for verb in consolas corefonts d3dcompiler_47 xact; do
      ${pkgs.protontricks}/bin/protontricks "$APPID" -q "$verb" >/dev/null 2>&1 \
        && echo "  $verb: ok" || echo "  $verb: FAILED (skipped)"
    done

    echo "== Prefix: Wine OpenXR registry keys"
    # PCI ids of the NVIDIA card specifically — this host also has the Raphael iGPU.
    read -r VID PID < <(${pkgs.pciutils}/bin/lspci -nn -d 10de::0300 \
      | sed -n 's/.*\[\(10de\):\([0-9a-f]\{4\}\)\].*/\1 \2/p' | head -n1)
    REG=$(mktemp --suffix=.reg)
    cat > "$REG" <<EOF
    Windows Registry Editor Version 5.00

    [HKEY_CURRENT_USER\\Software\\Wine\\VR]
    "openxr_vulkan_device_extensions"="VK_KHR_external_fence VK_KHR_external_memory VK_KHR_external_semaphore VK_KHR_dedicated_allocation VK_KHR_get_memory_requirements2 VK_KHR_external_memory_fd VK_KHR_external_semaphore_fd VK_KHR_external_fence_fd VK_KHR_image_format_list VK_KHR_timeline_semaphore"
    "openxr_vulkan_instance_extensions"="VK_KHR_external_memory_capabilities VK_KHR_get_physical_device_properties2 VK_KHR_external_semaphore_capabilities VK_KHR_external_fence_capabilities"
    "openxr_vulkan_device_vid"=dword:0000$VID
    "openxr_vulkan_device_pid"=dword:0000$PID
    "state"=dword:00000001
    EOF
    ${pkgs.protontricks}/bin/protontricks -c "wine regedit /S '$REG'" "$APPID"
    rm -f "$REG"

    echo
    echo "Done. Recommended in-game VR settings are in ~/nixos-config/docs/vr.md."
  '';

  # One click from the desktop: make sure the headset is streaming, then start DCS
  # in VR. DCS fails over to flat if no headset is connected when it starts, because
  # WiVRn only provides the OpenXR runtime during a headset session.
  dcs-vr = pkgs.writeShellScriptBin "dcs-vr" ''
    set -uo pipefail
    notify() { ${pkgs.libnotify}/bin/notify-send -a "DCS VR" -i steam_icon_${dcsAppId} "$@" 2>/dev/null || true; echo "$*"; }

    if pgrep -u "$(id -u)" -f 'DCSWorld/bin/DCS.exe' >/dev/null; then
      notify "DCS is already running"; exit 0
    fi

    # A headset session = wivrn-server has forked its per-client server process.
    streaming() {
      local main; main=$(systemctl --user show wivrn.service -p MainPID --value)
      [ "''${main:-0}" != 0 ] && pgrep -P "$main" >/dev/null
    }

    if ! streaming; then
      systemctl --user start wivrn.service
      if ! ${adb} get-state 2>/dev/null | grep -qx device; then
        notify "Plug in the headset" "Waiting for the Quest on USB…"
        # The udev rule starts vr-connect once it appears.
        timeout 120 ${adb} wait-for-usb-device || { notify "No headset found" "Gave up after 2 minutes."; exit 1; }
      elif ! systemctl --user is-active --quiet vr-connect.service; then
        systemctl --user start vr-connect.service
      else
        # Tunnel is up but the app isn't connected (e.g. it was closed): reopen it.
        ${adb} shell am start -a android.intent.action.VIEW -d "wivrn+tcp://localhost" ${clientPackage} >/dev/null
      fi
      notify "Put the headset on" "Waiting for WiVRn to connect…"
      # The headset ignores the connect intent while it's off your head (the app
      # cold-starts without it), so keep re-sending it until the stream is up.
      for i in $(seq 120); do
        streaming && break
        if [ $((i % 10)) = 0 ]; then
          ${adb} shell am start -a android.intent.action.VIEW -d "wivrn+tcp://localhost" ${clientPackage} >/dev/null 2>&1
        fi
        sleep 1
      done
      streaming || { notify "Headset didn't connect" "Open WiVRn in the headset and run dcs-vr again."; exit 1; }
    fi

    # launch/<appid>/VR skips Steam's launch-option picker and runs the default
    # entry, which our launch options (dcs-vr-setup) turn into OpenXR VR.
    notify "Starting DCS World in VR"
    exec steam "steam://launch/${dcsAppId}/VR"
  '';

  # A browser for wayvr's own nested display (launch it from wayvr's app list).
  # Windows there take controller input directly; a mirrored *desktop* window only
  # gets clicks through the real cursor, which a focused game (DCS) holds locked.
  # Separate profile + --new-instance, or the launch is handed to the desktop
  # Firefox and the window opens on Hyprland instead.
  vr-browser = pkgs.writeShellScriptBin "vr-browser" ''
    profile="''${XDG_DATA_HOME:-$HOME/.local/share}/vr-browser"
    mkdir -p "$profile"
    exec firefox --new-instance --profile "$profile" --name vr-browser "''${@:-https://www.youtube.com}"
  '';

  vr-browser-desktop = pkgs.makeDesktopItem {
    name = "vr-browser";
    desktopName = "Firefox (VR)";
    comment = "Separate Firefox for wayvr's in-headset display; controller clicks work during games";
    exec = "${vr-browser}/bin/vr-browser %U";
    icon = "firefox";
    categories = [ "Network" "WebBrowser" ];
  };

  dcs-vr-desktop = pkgs.makeDesktopItem {
    name = "dcs-vr";
    desktopName = "DCS World (VR)";
    comment = "Connect the Quest over USB and start DCS World in VR";
    exec = "${dcs-vr}/bin/dcs-vr";
    icon = "steam_icon_${dcsAppId}";
    categories = [ "Game" ];
  };
in
{
  options.customConfig.profiles.vr = with lib; {
    enable = mkEnableOption "PC VR streamed to a standalone headset over USB with WiVRn";
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = apkHashes ? ${wivrn.version};
      message = ''
        customConfig.profiles.vr: pkgs.wivrn moved to ${wivrn.version} but no headset APK
        hash is pinned for it in modules/nixos/profiles/vr.nix. Add it with:
          nix-prefetch-url https://github.com/WiVRn/WiVRn/releases/download/v${wivrn.version}/WiVRn-release.apk
      '';
    }];

    services.wivrn = {
      enable = true;
      package = wivrn;
      autoStart = true;
      highPriority = true; # CAP_SYS_NICE for the compositor's async reprojection thread
      openFirewall = false; # USB only: the headset reaches us through `adb reverse`
      steam.enable = true;
      steam.importOXRRuntimes = true;
      config = {
        enable = true;
        json = {
          # 10-bit HEVC on NVENC: removes the colour banding 8-bit shows in skies
          # and dark cockpits, which is most of what a flight sim draws.
          encoder = { encoder = "nvenc"; codec = "h265"; };
          bit-depth = 10;
          # Nothing to advertise over the network when the link is a cable.
          publish-service = null;
          # Desktop/overlay inside the headset, started when the headset connects.
          application = [ pkgs.wayvr ];
        };
      };
    };

    environment.systemPackages = [
      pkgs.android-tools # adb; device access comes from systemd's uaccess rules
      pkgs.protontricks
      vr-connect
      vr-client-install
      dcs-vr-setup
      dcs-vr
      dcs-vr-desktop
      vr-browser
      vr-browser-desktop
    ];

    # Plug in the headset → vr-connect runs in the seat user's session.
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="2833", TAG+="systemd", ENV{SYSTEMD_USER_WANTS}+="vr-connect.service"

      # Let gamemode (running as the user) flip the 7900X3D's scheduler preference to the V-Cache CCD.
      ACTION=="add|bind", SUBSYSTEM=="platform", DRIVER=="amd_x3d_vcache", RUN+="${pkgs.coreutils}/bin/chgrp gamemode /sys%p/amd_x3d_mode", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys%p/amd_x3d_mode"
    '';

    # wivrn-server saves paired headsets to $XDG_CONFIG_HOME/wivrn/ but never creates
    # it (with config.json from the store nothing else does), so every pairing was
    # dropped ("Failed to save keys") and the PIN came back on each server restart.
    systemd.user.services.wivrn.serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %E/wivrn";

    systemd.user.services.vr-connect = {
      description = "Connect a USB-attached headset to WiVRn";
      serviceConfig = {
        Type = "simple";
        ExecStart = "${vr-connect}/bin/vr-connect";
      };
    };

    # For non-Proton games run under gamemoderun: gamemode already pins game threads
    # to the V-Cache CCD (pin_cores autodetects the 7900X3D); also flip amd_x3d_vcache.
    programs.gamemode.settings.custom = {
      start = "${x3dMode} cache";
      end = "${x3dMode} frequency";
    };

    # WiVRn's NVENC path uses CUDA, which makes the driver hold the GPU in P2
    # instead of P0 under load. This application profile lifts that for the
    # server (upstream docs/nvenc.md). The driver reads this directory directly.
    environment.etc."nvidia/nvidia-application-profiles-rc.d/50-wivrn.json".text = builtins.toJSON {
      profiles = [{ name = "WiVRnServer"; settings = [{ key = "0x166c5e"; value = 0; }]; }];
      rules = [{ pattern = { feature = "procname"; matches = "wivrn-server"; }; profile = "WiVRnServer"; }];
    };
  };
}

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
  questVendor = "2833"; # Oculus / Meta
  busctl = "${pkgs.systemd}/bin/busctl";
  wivrnBus = "io.github.wivrn.Server /io/github/wivrn/Server io.github.wivrn.Server";

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

    # Also started at login (a headset plugged in before then sent its udev event
    # to nobody): nothing to do if none is attached.
    if ! ${pkgs.usbutils}/bin/lsusb -d ${questVendor}: >/dev/null; then
      echo "no headset attached"; exit 0
    fi

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
    since=$(date '+%Y-%m-%d %H:%M:%S')
    ${adb} reverse tcp:9757 tcp:9757
    ${adb} shell am start -a android.intent.action.VIEW -d "wivrn+tcp://localhost" ${clientPackage} >/dev/null
    notify "VR connected" "WiVRn ${wivrn.version} over USB"

    # No headset paired yet: the server is in pairing mode and the headset will ask
    # for a PIN. wivrn-server's own notification ("PIN" + the code) goes out when the
    # server starts at login, long before anyone plugs a headset in, so repeat it
    # here with words. The D-Bus name appears a moment after the unit starts.
    for _ in $(seq 10); do
      pairing=$(${busctl} --user get-property ${wivrnBus} PairingEnabled 2>/dev/null) && break
      sleep 1
    done
    if [ "''${pairing:-}" = "b true" ]; then
      pin=$(${busctl} --user get-property ${wivrnBus} Pin | sed 's/^s "\(.*\)"$/\1/')
      ${pkgs.libnotify}/bin/notify-send -a "VR" -i dialog-password -u critical -t 600000 \
        "VR pairing code: $pin" "Put the headset on. When WiVRn asks for a PIN, type $pin. Only needed once." || true
      echo "pairing code: $pin"
    fi

    # Cable pulled mid-game: WiVRn refuses the headset back into the session the
    # game still holds ("headset config incompatible with current session") and
    # only restarting the game recovers. Say so, rather than leaving the headset
    # on WiVRn's error screen.
    (
      for _ in $(seq 60); do
        if ${pkgs.systemd}/bin/journalctl --user -u wivrn.service --since "$since" -q 2>/dev/null \
            | grep -q "incompatible with current session"; then
          notify "VR: restart the game" "The headset can't rejoin a game that was running when the cable came out. Quit the game, then start it again from its (VR) entry."
          break
        fi
        sleep 1
      done
    ) &

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

  dcsAppId = "223750";
  # Sets a game's compat tool (config.vdf) and launch options (every
  # localconfig.vdf). Steam must be closed. Idempotent.
  vdfEdit = pkgs.writers.writePython3 "vr-steam-vdf" { libraries = [ pkgs.python3Packages.vdf ]; } ''
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
        tmp = path + ".vr-setup-tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            vdf.dump(data, f, pretty=True, escaped=False)
        os.replace(tmp, path)
        print("updated", path)


    def compat(data):
        m = child(child(child(child(child(data, "InstallConfigStore"),
                  "Software"), "Valve"), "Steam"), "CompatToolMapping")
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

  # Shell helpers shared by the setup scripts below.
  # * Steam rewrites its config files on exit, so they refuse to run while it is open.
  # * $tool is set to the newest GE-Proton 11 (11-9 or newer) Steam can see, by Steam's
  #   internal tool name: either one unpacked into compatibilitytools.d (protonup-qt,
  #   GitHub tarball) or the one programs.steam.extraCompatPackages installs (the
  #   gaming profile's proton-ge-bin, internal name plain "GE-Proton"), so a machine
  #   needs no hand-downloaded build. Older wineopenxr leaves
  #   xrConvertWin32PerformanceCounterToTimeKHR unimplemented (black headset in War
  #   Thunder), and only Proton 11 writes the HKCU\Software\Wine\VR keys itself.
  nixCompatTools = lib.optionals config.programs.steam.enable
    (map (lib.getOutput "steamcompattool") config.programs.steam.extraCompatPackages);
  steamHelpers = ''
    STEAM="$HOME/.local/share/Steam"
    steam_running() {
      pgrep -u "$(id -u)" -x steam >/dev/null || pgrep -u "$(id -u)" steamwebhelper >/dev/null
    }
    # Library folder an app is installed in; fails if it isn't installed.
    game_lib() {
      local l
      for l in "$STEAM" $(sed -n 's/^\s*"path"\s*"\(.*\)"/\1/p' "$STEAM/steamapps/libraryfolders.vdf" 2>/dev/null); do
        [ -f "$l/steamapps/appmanifest_$1.acf" ] && { echo "$l"; return 0; }
      done
      return 1
    }
    # Steam keeps a compat tool and launch options for an app that isn't installed
    # yet, so setup can run first. War Thunder then downloads as the Windows client
    # (the native Linux one has no VR) instead of needing a re-download.
    not_installed_note() {
      game_lib "$1" >/dev/null || echo "($2 isn't installed yet — set up anyway, so it installs ready for VR.)"
    }
  '';
  geProton11Setup = ''
    set -euo pipefail
    ${steamHelpers}
    if steam_running; then
      echo "Steam is running — it rewrites its config on exit. Quit Steam fully and re-run." >&2
      exit 1
    fi
    tool=""; best=-1
    for dir in "$STEAM"/compatibilitytools.d/* ${lib.concatStringsSep " " nixCompatTools}; do
      [ -f "$dir/version" ] && [ -f "$dir/compatibilitytool.vdf" ] || continue
      # `version` reads "<timestamp> GE-Proton11-9" for every GE-Proton build.
      v=$(sed -n 's/^[0-9]* GE-Proton11-\([0-9]*\)$/\1/p' "$dir/version")
      [ -n "$v" ] && [ "$v" -ge 9 ] && [ "$v" -gt "$best" ] || continue
      best=$v
      tool=$(sed -n 's/^\s*"\([^"]*\)"\s*\/\/ Internal name.*/\1/p' "$dir/compatibilitytool.vdf")
    done
    if [ -z "$tool" ]; then
      echo "Needs GE-Proton11-9 or newer. Enable the gaming profile (proton-ge-bin) or unpack one" >&2
      echo "into $STEAM/compatibilitytools.d from https://github.com/GloriousEggroll/proton-ge-custom/releases" >&2
      exit 1
    fi
    echo "Using $tool (GE-Proton11-$best)"
  '';

  # DCS World (Steam appid 223750) under GE-Proton 11. Proton 11 writes the Wine
  # OpenXR registry keys itself whenever WiVRn is reachable at start-up, so there is
  # no prefix step: this only sets the compat tool and launch options, and works
  # before DCS has ever been started.
  dcs-vr-setup = pkgs.writeShellScriptBin "dcs-vr-setup" ''
    ${geProton11Setup}
    MODE="''${1:-vr}"
    # No double quotes in here: localconfig.vdf is written unescaped (see vr-steam-vdf).
    common='PROTON_ENABLE_NVAPI=1 WINEDLLOVERRIDES=wbemprox=n %command% --no-launcher'
    case "$MODE" in
      vr)   OPTS="$common --force_enable_VR --force_OpenXR" ;;
      flat) OPTS="$common" ;;
      *)    echo "usage: dcs-vr-setup [vr|flat]" >&2; exit 2 ;;
    esac
    not_installed_note ${dcsAppId} "DCS World"
    echo "== Steam: $tool + $MODE launch options"
    ${vdfEdit} "$STEAM" ${dcsAppId} "$OPTS" "$tool"
    echo "Done. Start it with the DCS World (VR) launcher (or dcs-vr)."
  '';

  # War Thunder (Steam appid 236390), Windows client under GE-Proton 11.
  # * Steam already has a hidden "vr" launch entry (beac_wt_mlauncher.exe
  #   -config:gameplay/enableVR:b=yes); steam://launch/236390/VR runs it.
  # * XR_SRGB_FIX turns on xr-srgb-fix (below) for this game only.
  # * Online play needs Valve's Proton BattlEye Runtime (appid 1161040); Steam passes
  #   PROTON_BATTLEYE_RUNTIME to the game by itself once it is installed.
  wtAppId = "236390";
  battlEyeAppId = "1161040";
  wt-vr-setup = pkgs.writeShellScriptBin "wt-vr-setup" ''
    ${geProton11Setup}
    not_installed_note ${wtAppId} "War Thunder"
    echo "== Steam: $tool + VR launch options"
    # PROTON_DISABLE_NVAPI: game build 2.59.0.78 (2026-10-20) crashes in dxvk-nvapi's
    # nvapi64.dll right after DX11 init (seen flat; VR shares that path). DLSS is off anyway.
    ${vdfEdit} "$STEAM" ${wtAppId} "PROTON_DISABLE_NVAPI=1 XR_SRGB_FIX=1 %command%" "$tool"
    if ! game_lib ${battlEyeAppId} >/dev/null; then
      echo "Missing the Proton BattlEye Runtime: online matches will refuse to start." >&2
      echo "Install it with: steam steam://install/${battlEyeAppId} (vr-setup does this for you)." >&2
    fi
    echo "Done. Start it with the War Thunder (VR) launcher (or wt-vr)."
  '';

  # Phasmophobia (Steam appid 739630), Windows build under GE-Proton 11. Unity's
  # OpenXR plugin, so it reaches WiVRn through wineopenxr like War Thunder.
  # Steam's "Phasmophobia in VR" launch entry passes --enable-vr;
  # steam://launch/739630/VR runs it.
  phasmoAppId = "739630";
  phasmo-vr-setup = pkgs.writeShellScriptBin "phasmo-vr-setup" ''
    ${geProton11Setup}
    not_installed_note ${phasmoAppId} "Phasmophobia"
    echo "== Steam: $tool"
    ${vdfEdit} "$STEAM" ${phasmoAppId} "%command%" "$tool"
    echo "Done. Start it with the Phasmophobia (VR) launcher (or phasmo-vr)."
  '';

  # The one setup command: closes Steam if it's open, sets up all three VR games
  # (installed or not), then reopens Steam, installing the BattlEye runtime War
  # Thunder needs if it's missing. Safe to re-run any time.
  vr-setup = pkgs.writeShellScriptBin "vr-setup" ''
    set -uo pipefail
    ${steamHelpers}
    was_running=0
    if steam_running; then
      was_running=1
      echo "Closing Steam (it reopens when setup is done)…"
      steam -shutdown >/dev/null 2>&1 &
      for _ in $(seq 60); do steam_running || break; sleep 1; done
      if steam_running; then
        echo "Steam didn't close. Quit it (Steam menu → Exit) and run vr-setup again." >&2
        exit 1
      fi
    fi

    ready=(); missing=(); failed=()
    setup() { # appid, title, command
      echo; echo "### $2"
      if "$3"; then ready+=("$2"); else failed+=("$2"); return; fi
      game_lib "$1" >/dev/null || missing+=("$2")
    }
    setup ${dcsAppId} "DCS World" ${dcs-vr-setup}/bin/dcs-vr-setup
    setup ${wtAppId} "War Thunder" ${wt-vr-setup}/bin/wt-vr-setup
    setup ${phasmoAppId} "Phasmophobia" ${phasmo-vr-setup}/bin/phasmo-vr-setup

    echo
    [ ''${#ready[@]} -gt 0 ] && echo "Set up for VR: $(IFS=,; echo "''${ready[*]}" | sed 's/,/, /g')"
    [ ''${#missing[@]} -gt 0 ] && echo "Still to install in Steam (no need to run vr-setup again): $(IFS=,; echo "''${missing[*]}" | sed 's/,/, /g')"
    [ ''${#failed[@]} -gt 0 ] && echo "FAILED: $(IFS=,; echo "''${failed[*]}" | sed 's/,/, /g') (see above)"

    if ! game_lib ${battlEyeAppId} >/dev/null; then
      echo "Opening Steam to install the Proton BattlEye Runtime War Thunder needs online — click Install."
      setsid -f steam steam://install/${battlEyeAppId} >/dev/null 2>&1
    elif [ "$was_running" = 1 ]; then
      setsid -f steam >/dev/null 2>&1
    fi
    [ ''${#failed[@]} -eq 0 ]
  '';

  # OpenXR layer that undoes Proton's double sRGB encode (washed-out colours in
  # War Thunder). Runs on the Linux side, outside the game's anti-cheat-watched
  # Windows process; only active when XR_SRGB_FIX is set.
  xr-srgb-fix = pkgs.callPackage ../../../pkgs/xr-srgb-fix { };

  # One click from the desktop: make sure the headset is streaming, then start the
  # game in VR. Games fail over to flat if no headset is connected when they start,
  # because WiVRn only provides the OpenXR runtime during a headset session.
  mkVrLauncher = { name, title, appId, process }: pkgs.writeShellScriptBin name ''
    set -uo pipefail
    notify() { ${pkgs.libnotify}/bin/notify-send -a "${title} VR" -i steam_icon_${appId} "$@" 2>/dev/null || true; echo "$*"; }

    # A second click while the first is still waiting for the headset or for Steam.
    exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/${name}.lock"
    if ! ${pkgs.util-linux}/bin/flock -n 9; then
      notify "${title} is already starting" "Give it a moment; it opens in the headset."; exit 0
    fi
    running() { pgrep -u "$(id -u)" -f '${process}' >/dev/null; }
    if running; then
      notify "${title} is already running" "Look in the headset."; exit 0
    fi

    # The adb server forks off and lives on: it must not inherit the lock (fd 9),
    # or every later click would report "already starting".
    adb() { ${adb} "$@" 9>&-; }
    # Ask WiVRn itself. Its per-client server process outlives an unplug (the
    # session just pauses), so "has a child process" is not "a headset is there".
    headset_connected() {
      ${busctl} --user get-property ${wivrnBus} HeadsetConnected 2>/dev/null | grep -qx "b true"
    }

    # Works in any order: headset unplugged, plugged in but asleep, plugged in before
    # login (no udev event reached this session), WiVRn app closed. Keep nudging
    # until the headset connects, but only for 2 minutes, so a forgotten click
    # can't start the game out of nowhere later.
    systemctl --user start wivrn.service
    if ! headset_connected; then
      # A session with no headset in it is stale: left paused by an unplug, or one
      # that refuses the headset back after the cable came out mid-game ("headset
      # config incompatible with current session"). wayvr keeps it alive after the
      # game quits, so a relaunch would join it and never connect. Only wayvr is
      # attached at this point, so restart for a fresh one, and close the headset
      # app (maybe on WiVRn's error screen) so the intents below start it clean.
      if ${busctl} --user get-property ${wivrnBus} SessionRunning 2>/dev/null | grep -qx "b true"; then
        systemctl --user restart wivrn.service
        adb get-state 2>/dev/null | grep -qx device && adb shell am force-stop ${clientPackage}
      fi
      notify "Waiting for the headset" "Plug it in and put it on. ${title} starts by itself once it connects."
      for i in $(seq 120); do
        headset_connected && break
        if adb get-state 2>/dev/null | grep -qx device; then
          # Plugged in: make sure vr-connect is up (it owns the tunnel), and keep
          # re-sending the connect intent, which the headset ignores while off-head.
          systemctl --user is-active --quiet vr-connect.service \
            || systemctl --user start vr-connect.service
          [ $((i % 10)) = 1 ] && adb shell am start -a android.intent.action.VIEW \
            -d "wivrn+tcp://localhost" ${clientPackage} >/dev/null 2>&1
        fi
        sleep 1
      done
      headset_connected || { notify "Headset didn't connect" "Plug in and power on the headset, then click ${title} (VR) again."; exit 1; }
      notify "Headset connected"
    fi

    # launch/<appid>/VR skips Steam's launch-option picker. DCS: runs the default
    # entry, which dcs-vr-setup's launch options turn into OpenXR VR. War Thunder
    # and Phasmophobia: run their own "vr" entry.
    # Steam can take a while (cold start, or its first-run step after a Proton
    # update), so report until the game process exists instead of going quiet.
    # 9>&- : Steam must not inherit the lock.
    notify "Starting ${title} in VR" "Steam is launching it. This can take a minute."
    setsid -f steam "steam://launch/${appId}/VR" >/dev/null 2>&1 9>&-
    for _ in $(seq 180); do
      if running; then
        notify "${title} is loading" "It appears in the headset when it's ready."; exit 0
      fi
      sleep 1
    done
    notify "${title} didn't start" "Check the Steam window for a message, then try again."
    exit 1
  '';

  mkVrDesktop = { name, title, appId, launcher }: pkgs.makeDesktopItem {
    inherit name;
    desktopName = "${title} (VR)";
    comment = "Connect the Quest over USB and start ${title} in VR";
    exec = "${launcher}/bin/${name}";
    icon = "steam_icon_${appId}";
    categories = [ "Game" ];
  };

  dcs-vr = mkVrLauncher { name = "dcs-vr"; title = "DCS World"; appId = dcsAppId; process = "DCSWorld/bin/DCS.exe"; };
  wt-vr = mkVrLauncher { name = "wt-vr"; title = "War Thunder"; appId = wtAppId; process = "win64.aces.exe"; };
  dcs-vr-desktop = mkVrDesktop { name = "dcs-vr"; title = "DCS World"; appId = dcsAppId; launcher = dcs-vr; };
  wt-vr-desktop = mkVrDesktop { name = "wt-vr"; title = "War Thunder"; appId = wtAppId; launcher = wt-vr; };
  phasmo-vr = mkVrLauncher { name = "phasmo-vr"; title = "Phasmophobia"; appId = phasmoAppId; process = "Phasmophobia.exe"; };
  phasmo-vr-desktop = mkVrDesktop { name = "phasmo-vr"; title = "Phasmophobia"; appId = phasmoAppId; launcher = phasmo-vr; };

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
      wt-vr-setup
      wt-vr
      wt-vr-desktop
      phasmo-vr-setup
      vr-setup
      phasmo-vr
      phasmo-vr-desktop
      vr-browser
      vr-browser-desktop
    ];

    # Plug in the headset → vr-connect runs in the seat user's session.
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="${questVendor}", TAG+="systemd", ENV{SYSTEMD_USER_WANTS}+="vr-connect.service"

      # Let gamemode (running as the user) flip the 7900X3D's scheduler preference to the V-Cache CCD.
      ACTION=="add|bind", SUBSYSTEM=="platform", DRIVER=="amd_x3d_vcache", RUN+="${pkgs.coreutils}/bin/chgrp gamemode /sys%p/amd_x3d_mode", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys%p/amd_x3d_mode"
    '';

    # wivrn-server saves paired headsets to $XDG_CONFIG_HOME/wivrn/ but never creates
    # it (with config.json from the store nothing else does), so every pairing was
    # dropped ("Failed to save keys") and the PIN came back on each server restart.
    systemd.user.services.wivrn.serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %E/wivrn";

    # Implicit OpenXR layers are found under XDG dirs; Steam's container doesn't see
    # the host's /etc/xdg but does see $HOME (and /nix/store), so link it there.
    systemd.user.tmpfiles.rules = [
      "L+ %h/.local/share/openxr/1/api_layers/implicit.d/XR_APILAYER_NIXOS_srgb_fix.json - - - - ${xr-srgb-fix}/share/openxr/1/api_layers/implicit.d/XR_APILAYER_NIXOS_srgb_fix.json"
    ];

    systemd.user.services.vr-connect = {
      description = "Connect a USB-attached headset to WiVRn";
      wantedBy = [ "default.target" ];
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

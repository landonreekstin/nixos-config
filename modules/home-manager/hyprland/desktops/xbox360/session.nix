# ~/nixos-config/modules/home-manager/hyprland/desktops/xbox360/session.nix
# The xbox360 desktop's Hyprland settings and startup (hyprDesktops.xbox360, rendered
# onto the functional layer as ~/.config/hypr/desktops/xbox360.conf by ../../desktops.nix),
# and everything host-specific its program (pkgs/xbox360-dashboard) needs: the
# generated Config.js, the blade shader's knots, and each helper's JSON config.
{ config, pkgs, lib, customConfig, ... }:

let
  desktopLib = import ../lib.nix { inherit lib; };
  inherit (desktopLib.state customConfig "xbox360") enabled;

  c = import ./colors.nix { inherit lib; };
  assets = pkgs.callPackage ../../../../../pkgs/xbox360-assets { };
  # The program itself (QML shell, shader source, Python helpers), from its own
  # repo; devSource swaps the pin for a local checkout. Its .git and the files
  # this module generates into a checkout (Config.js, *.qsb) are left out.
  dashboard = pkgs.callPackage ../../../../../pkgs/xbox360-dashboard (lib.optionalAttrs (xcfg.devSource != null) {
    srcOverride = builtins.path {
      name = "xbox360-dashboard-src";
      path = xcfg.devSource;
      filter = p: _: !(lib.elem (baseNameOf p) [ ".git" "Config.js" "blade.frag.qsb" ]);
    };
  });
  share = "${dashboard}/share/xbox360-dashboard";

  # The blades shell paints the whole background, so the functional layer's
  # wallpaper daemon has no place here: started anyway it would put its own
  # background-layer surface (and its cached century wallpaper) under or over
  # the blades, depending on which mapped first.
  isWallpaperDaemon = line: lib.hasInfix "awww-daemon" line || lib.hasInfix "bin/hyprpaper" line;
  # The default session's locker and logout menu become this rice's own lock
  # screen and Turn Off Console blade (SUPER+Escape, SUPER+BackSpace).
  qsCall = fn: "${pkgs.quickshell}/bin/qs -c xbox360 ipc call ui ${fn}";
  rebind = b: builtins.replaceStrings
    [ ", exec, swaylock" ", exec, ${pkgs.wlogout}/bin/wlogout" ", exec, wlogout" ]
    [ ", exec, ${qsCall "lock"}" ", exec, ${qsCall "power"}" ", exec, ${qsCall "power"}" ] b;
  # Applied to the merged settings (hyprDesktops.xbox360.transformSettings).
  transform = s:
    s // {
      "exec-once" = lib.filter (l: !isWallpaperDaemon l) (s."exec-once" or [ ]);
      bind = map rebind (s.bind or [ ]);
    };

  rgb = hex: "rgb(${hex})";
  bladeBorder = name:
    let b = c.blades.${name}; in "${rgb "ffffff"} ${rgb b.base} ${rgb (lib.elemAt b.stops 3)} 90deg";

  # The rice's own settings. Functional values set WITHOUT mkDefault need
  # mkForce here, exactly as in a normal theme. exec-once is NOT set here:
  # functional.nix gives that list mkDefault priority, so any plain definition
  # would silently replace it — the rice's startup lines go in extraConfig.
  settings = {
    general = {
      gaps_in = 8;
      # The blades shell reserves the panel area (Blades.qml), so this is only
      # the breathing room between a window and the blade's own edge.
      gaps_out = 12;
      border_size = 2;
      # The shell recolours this to the blade an app was launched from
      # (ShellState.applyBorder); steel until it does.
      "col.active_border" = bladeBorder "steel";
      "col.inactive_border" = "rgba(f0f0f055)";
      resize_on_border = true;
    };

    # The "aero glass" box: large soft corners, a frosted backdrop through
    # translucent inactive windows, and the dashboard's soft drop shadow.
    decoration = {
      rounding = 18;
      rounding_power = 3.0;
      active_opacity = 1.0;
      inactive_opacity = 0.9;
      fullscreen_opacity = 1.0;
      blur = {
        enabled = true;
        size = 8;
        passes = 3;
        vibrancy = 0.35;
        noise = 0.01;
        contrast = 1.0;
        brightness = 1.05;
        popups = true;
      };
      shadow = {
        enabled = true;
        range = 24;
        render_power = 3;
        color = "rgba(00000066)";
        color_inactive = "rgba(00000033)";
      };
    };

    # One tempo for everything, as on the console: 350 ms on (.4,0,.2,1).
    # Hyprland animation speed is in units of 100 ms. Workspaces slide
    # sideways because blades move left/right.
    animations = {
      enabled = true;
      bezier = [ "blade, ${c.motion.bezier}" ];
      animation = [
        "windows, 1, 3.5, blade, popin 85%"
        "windowsOut, 1, 3.5, blade, popin 85%"
        "border, 1, 3.5, blade"
        "fade, 1, 3.5, blade"
        "workspaces, 1, 3.5, blade, slide"
        "layers, 1, 3.5, blade, fade"
      ];
    };

    misc.force_default_wallpaper = lib.mkForce 0;

    # SUPER+Space opens the Guide, like the Guide button; SUPER+Home goes to
    # the dashboard, or back to the last app from it.
    "$menu" = lib.mkForce "${pkgs.quickshell}/bin/qs -c xbox360 ipc call ui guide";
    bind = [
      "SUPER, Home, exec, ${pkgs.quickshell}/bin/qs -c xbox360 ipc call ui home"
    ];
  };

  # ---- the blades shell (Quickshell) ---------------------------------------

  # The blades go on the host's "main" monitor, else the first enabled one —
  # the same rule functional.nix uses for XWayland's primary output. Quickshell
  # matches connector names, so a `desc:` identifier falls back to the first
  # screen at runtime (as does a VM with no monitors configured).
  primaryOutput =
    let
      enabledMonitors = lib.filter (m: m.enabled) customConfig.desktop.monitors;
      main = lib.findFirst (m: m.name == "main") null enabledMonitors;
      mon = if main != null then main else if enabledMonitors != [ ] then lib.head enabledMonitors else null;
    in
    if mon != null && !(lib.hasPrefix "desc:" mon.identifier) then mon.identifier else "";

  bladeOrder = c.order ++ [ "steel" ];

  xcfg = customConfig.homeManager.themes.xbox360;

  menus = import ./menus.nix {
    inherit lib pkgs;
    apps = customConfig.apps.programs;
    downloadsUrl = xcfg.transmissionUrl;
    jellyfinUrl = xcfg.jellyfinUrl;
    # The Jellyfin desktop client, when the host installs it system-wide.
    jellyfinApp = lib.any (p: (p.pname or "") == "jellyfin-desktop") customConfig.packages.nixos;
    hasTv = tvMonitor != null;
    hasAudio = audioCmd != null;
  };

  # Full-screen pages a menu row can open, by id.
  pages = {
    downloads = "PageDownloads.qml";
    games = "PageGames.qml";
    videos = "PageVideos.qml";
    updates = "PageUpdates.qml";
  };

  # The user's own picture for the gamer card, if they have one.
  gamerpic = "file://${config.home.homeDirectory}/.face";

  # Marketplace -> Downloads: Transmission's torrents as JSON. Its RPC wants
  # the session id it hands out in a 409 first (CSRF protection).
  downloadsCmd = pkgs.writeShellScript "xbox360-downloads" ''
    url=${if xcfg.transmissionUrl == null then "" else xcfg.transmissionUrl}
    [ -n "$url" ] || { echo "[]"; exit 0; }
    curl=${pkgs.curl}/bin/curl
    sid=$($curl -s -m 4 -o /dev/null -D - "$url" | tr -d '\r' | sed -n 's/^X-Transmission-Session-Id: //Ip')
    $curl -s -m 6 -H "X-Transmission-Session-Id: $sid" \
      -d '{"method":"torrent-get","arguments":{"fields":["name","percentDone","rateDownload","eta","totalSize","status","error"]}}' \
      "$url" \
    | ${pkgs.jq}/bin/jq -c '[.arguments.torrents[] | {
        name, pct: .percentDone, rate: .rateDownload, eta, size: .totalSize,
        statusText: (if .error != 0 then "Error"
                     elif .status == 4 then "Downloading"
                     elif .status == 6 then "Seeding"
                     elif .status == 0 then (if .percentDone >= 1 then "Finished" else "Paused" end)
                     elif .status < 4 then "Checking"
                     else "Waiting" end)
      }]'
  '';

  # Everything the QML needs from Nix, as one generated JS library.
  configJs = pkgs.writeText "Config.js" ''
    // Generated by hyprland/desktops/xbox360/session.nix — edit colors.nix, not this.
    .pragma library
    var primary = ${builtins.toJSON primaryOutput};
    var gamertag = ${builtins.toJSON customConfig.user.name};
    var pwPlay = "${pkgs.pipewire}/bin/pw-play";
    var sounds = "${assets}/share/sounds/xbox360";
    var font = "Convection";
    var blades = ${builtins.toJSON (map (n: { inherit (c.blades.${n}) title stops tab ink base rule; }) bladeOrder)};
    var bladesNight = ${builtins.toJSON (map (n: { inherit (c.night.blades.${n}) title stops tab ink base rule; }) bladeOrder)};
    var silverNight = ${builtins.toJSON c.night.silver};
    var guideNight = ${builtins.toJSON c.night.guide};
    var backdropNight = "${c.night.backdrop}";
    var washInkNight = "${c.night.washInk}";
    // Night mode's "auto": century-series' own sunset reckoning when the
    // host has it (it prints sun=day|night), else the clock.
    var nightStatusCmd = "command -v century-night >/dev/null && century-night status";
    var tvCmd = "${if tvMonitor == null then "" else "${tvScript}"}";
    var monitors = ${builtins.toJSON displays};
    var buttons = ${builtins.toJSON c.buttons};
    var menus = ${builtins.toJSON menus};
    var pages = ${builtins.toJSON pages};
    var startBlade = 2;
    var curveDepth = ${toString c.curve.depth};
    var gamerpic = ${builtins.toJSON gamerpic};
    var zone = "Couch";
    var wtype = "${pkgs.wtype}/bin/wtype";
    var guide = ${builtins.toJSON (c.guide // { messages = appCmd "chatAlt"; party = appCmd "chat"; music = appCmd "music"; })};
    var widgets = ${builtins.toJSON widgets};
    var statusCmd = "${statusCmd}";
    var audioCmd = "${if audioCmd == null then "" else "${audioCmd}"}";
    var volumeCmd = "${pkgs.wireplumber}/bin/wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@";
    var networkEditor = "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
    var updatesCmd = "${updatesCmd}";
    var terminal = ${builtins.toJSON (appCmd "terminal")};
    var gamesCmd = "${gamesCmd}/bin/xbox360-games";
    var gamesConfig = ${builtins.toJSON gamesConfig};
    var jellyfinUrl = ${builtins.toJSON (if xcfg.jellyfinUrl == null then "" else xcfg.jellyfinUrl)};
    var jellyfinPlay = "${jellyfinPlay}/bin/xbox360-jellyfin-play ${pkgs.mpv}/bin/mpv";
    var hostname = ${builtins.toJSON customConfig.system.hostName};
    var hyprctl = "${pkgs.hyprland}/bin/hyprctl";
    var gameClasses = ${builtins.toJSON gameClasses};
    var downloadsCmd = "${downloadsCmd}";
    var silver = ${builtins.toJSON c.silver};
    var motionMs = ${toString c.motion.ms};
    var motionBezier = ${builtins.toJSON (c.motion.points ++ [ 1 1 ])};
    var curveY = ${builtins.toJSON c.curve.y};
    var curveD = ${builtins.toJSON c.curve.d};
    ${lib.concatStrings (lib.mapAttrsToList (k: v: "var ${k} = ${toString v};\n") c.layout)}
  '';

  # blade.frag with the curve knots substituted, so the shader's panel mask is
  # the same curve Geometry.js draws. Floats spelled out: GLSL wants 130.0.
  # Substituted at build time (not builtins.readFile of the package, which
  # would be import-from-derivation).
  glslFloats = xs: lib.concatMapStringsSep ", " (x: toString (x * 1.0)) xs;
  bladeKnots = lib.zipListsWith (k: v: "--replace-fail ${k} ${lib.escapeShellArg v}")
    [ "@N@" "@KY@" "@KD@" "@CI@" "@CR@" ]
    ([ (toString (lib.length c.curve.y)) (glslFloats c.curve.y) (glslFloats c.curve.d) ]
      ++ map (k: glslFloats [ c.layout.${k} ]) [ "cardInset" "cardRadius" ]);

  shellConfig = pkgs.runCommand "xbox360-quickshell" { } ''
    mkdir -p $out
    cp ${share}/shell/* $out/
    cp ${configJs} $out/Config.js
    substitute ${share}/shaders/blade.frag.in blade.frag ${lib.concatStringsSep " " bladeKnots}
    ${lib.getBin pkgs.qt6.qtshadertools}/bin/qsb --glsl "300 es,100 es,120,150,330" --hlsl 50 --msl 12 \
      -o $out/blade.frag.qsb blade.frag
  '';

  # ---- the Guide ----------------------------------------------------------
  apps = customConfig.apps.programs;
  appCmd = role: apps.${role}.command or "";

  # Console Settings in the Guide shows century-series' waybar widgets: the
  # very same scripts, read from the merged waybar config, so the two
  # sessions can never disagree about what "VPN on" means. A widget the host
  # doesn't have simply isn't listed.
  waybarBar =
    let s = config.programs.waybar.settings;
    in if builtins.isAttrs s then s.mainBar or { } else { };
  widgetSpecs = [
    { id = "custom/audio-sink"; label = "Sound Output"; icon = "audio-speakers";
      # waybar's click opens a rofi picker, which no controller can drive.
      click = "cycle-audio-sink next"; right = "toggle-audio-flip"; rightLabel = "swap left and right"; }
    { id = "custom/hyprsunset"; label = "Night Light"; icon = "weather-clear-night"; rightLabel = "back to automatic"; }
    { id = "custom/bluetooth"; label = "Bluetooth"; icon = "bluetooth"; rightLabel = "turn Bluetooth on or off"; }
    { id = "custom/vpn"; label = "VPN"; icon = "network-vpn"; }
    { id = "custom/weather"; label = "Weather"; icon = "weather-few-clouds"; cache = 600; }
    { id = "custom/ckb-color"; label = "Keyboard Lights"; icon = "input-keyboard"; }
    { id = "custom/claude-rwr"; label = "Claude"; icon = "dialog-information"; }
  ];
  widgets = map (w:
    let m = waybarBar.${w.id}; in {
      inherit (w) id label icon;
      exec = m.exec;
      click = w.click or (m.on-click or "");
      right = w.right or (m.on-click-right or "");
      rightLabel = w.rightLabel or "";
      cache = w.cache or 0;
    })
    (lib.filter (w: waybarBar ? ${w.id} && (waybarBar.${w.id}.exec or "") != ""
      # Guide -> Audio replaces the plain output cycle when the host lists its devices.
      && !(w.id == "custom/audio-sink" && audioCmd != null)) widgetSpecs);

  # ---- Audio -----------------------------------------------------------------
  # Guide -> Audio: the host's audioDevices, each an output + microphone pair
  # switched in one go (pad/xbox360-audio.py). null when the host lists none.
  audioCmd = if xcfg.audioDevices == [ ] then null else
    let
      script = "${dashboard}/bin/xbox360-audio";
      devices = pkgs.writeText "xbox360-audio.json" (builtins.toJSON xcfg.audioDevices);
    in pkgs.writeShellScript "xbox360-audio" ''
      # toggle-audio-flip comes from the user's profile.
      export PATH=${lib.makeBinPath [ pkgs.pulseaudio ]}:$PATH:/etc/profiles/per-user/$USER/bin
      exec ${script} ${devices} "$@"
    '';
  audioSh = if audioCmd == null then "false" else "${audioCmd}";
  # The device TV Mode switches to: the one on the TV's own HDMI output.
  tvAudioLabel =
    let d = lib.findFirst (d: tvMonitor != null && tvMonitor.edid != null && d.output == tvMonitor.edid)
      null xcfg.audioDevices;
    in if d == null then "" else d.label;

  # All of Console Settings' values in one go, as a JSON object keyed by widget
  # id (plus volume and network). Slow widgets (weather) are cached.
  statusCmd = pkgs.writeShellScript "xbox360-status" ''
    export PATH=$PATH:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin
    jq=${pkgs.jq}/bin/jq
    cache=''${XDG_RUNTIME_DIR:-/tmp}/xbox360-status
    mkdir -p "$cache"
    widget() {  # id cache-seconds command
      f="$cache/$(printf %s "$1" | tr / _)"
      if [ "$2" -gt 0 ] && [ -s "$f" ] && [ $(( $(date +%s) - $(stat -c %Y "$f") )) -lt "$2" ]; then
        cat "$f"; return
      fi
      out=$(timeout 5 sh -c "$3" 2>/dev/null | tail -n 1)
      printf %s "$out" | $jq -e . >/dev/null 2>&1 || out=$($jq -cn --arg t "$out" '{text: $t}')
      printf %s "$out" > "$f"
      printf %s "$out"
    }
    {
      echo '{'
      ${lib.concatMapStrings (w: ''
        printf '%s:' ${lib.escapeShellArg (builtins.toJSON w.id)}
        widget ${lib.escapeShellArg w.id} ${toString w.cache} ${lib.escapeShellArg w.exec}
        echo ','
      '') widgets}
      printf '"volume": %s,' "$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print ($2 == "" ? "null" : $2)}')"
      printf '"network": %s' "$(${pkgs.networkmanager}/bin/nmcli -t -f NAME connection show --active 2>/dev/null | grep -v '^lo$' | head -n 1 | $jq -R . 2>/dev/null || echo null)"
      echo '}'
    } | $jq -c . 2>/dev/null || echo '{}'
  '';

  # ---- Marketplace -> System Update ----------------------------------------
  # Where the configuration stands, as JSON. Local git only (no fetch): it
  # shows what the last `update` or the weekly updater saw.
  updatesCmd = pkgs.writeShellScript "xbox360-updates" ''
    export PATH=${lib.makeBinPath [ pkgs.git pkgs.jq pkgs.coreutils pkgs.gh ]}
    repo=${config.home.homeDirectory}/nixos-config
    g() { git -C "$repo" "$@" 2>/dev/null; }
    branch=$(g rev-parse --abbrev-ref HEAD)
    commit=$(g rev-parse --short HEAD)
    committed=$(g log -1 --format=%ct)
    behind=$(g rev-list --count HEAD..origin/main || echo null)
    # The symlink's own time is the switch; its target is a store path (epoch 1).
    built=$(stat -c %Y /run/current-system 2>/dev/null || echo 0)
    pr=$(timeout 8 gh pr list --repo landonreekstin/nixos-config --label flake-update \
          --json number,labels --jq '.[0] | if . == null then null else {number, blocked: ([.labels[].name] | index("update-blocked") != null)} end' \
          2>/dev/null || echo '"unknown"')
    [ -n "$pr" ] || pr=null
    jq -cn --arg branch "$branch" --arg commit "$commit" --argjson committed "''${committed:-0}" \
      --argjson behind "''${behind:-null}" --argjson built "$built" --argjson pr "$pr" \
      '{branch: $branch, commit: $commit, committed: $committed, behind: $behind, built: $built,
        pr: (if $pr == "unknown" then false else $pr end)}'
  '';

  # ---- displays ------------------------------------------------------------
  # Guide -> Displays (shell/Displays.qml): every enabled monitor, with the
  # rule that turns it back on (toggle-monitor needs it).
  displayLabel = n: if n == "tv" then "TV" else lib.toUpper (lib.substring 0 1 n) + lib.substring 1 (-1) n;
  displays = map (m: { id = monitorId m; label = displayLabel m.name; rule = monitorRule m; })
    (lib.filter (m: m.enabled) customConfig.desktop.monitors);
  # Each display's dashboard opens on it from the start and lives there.
  # A desc: monitor gets none: the shell (Quickshell) only knows connectors,
  # and finds or makes the workspace itself.
  dashboardRules = lib.concatMapStrings (m:
    lib.optionalString (!lib.hasPrefix "desc:" (monitorId m))
      "workspace = name:dashboard-${monitorId m}, monitor:${monitorId m}, default:true\n")
    (lib.filter (m: m.enabled) customConfig.desktop.monitors);

  # ---- TV mode -------------------------------------------------------------
  # The whole session on the TV alone (the host's monitor named "tv"), and its
  # HDMI audio with it; off puts back the monitors and the sound output from
  # before. It works through the same state file as century-series' monitor
  # toggles (toggle-monitor.nix), which monitor-state-watcher re-applies after
  # every config reload — so a rebuild mid-match doesn't undo it.
  tvMonitor = lib.findFirst (m: m.name == "tv" && m.enabled) null customConfig.desktop.monitors;

  # After a live switch to another desktop (`hypr-desktop switch`), a display
  # still on its dashboard goes to its lowest numbered workspace (where its
  # windows are), or an empty one, as if that desktop had been logged into.
  leaveDashboards = pkgs.writeShellScript "xbox360-leave-dashboards" ''
    export PATH=${lib.makeBinPath [ pkgs.hyprland pkgs.jq ]}:$PATH
    hyprctl monitors -j | jq -r '.[] | select(.activeWorkspace.name | startswith("dashboard-")) | .name' |
      while read -r m; do
        ws=$(hyprctl workspaces -j | jq -r --arg m "$m" '[.[] | select(.monitor == $m and .id > 0) | .id] | min // empty')
        hyprctl dispatch focusmonitor "$m" >/dev/null
        hyprctl dispatch workspace "''${ws:-emptym}" >/dev/null
      done
  '';
  # Hyprland's name for a monitor, as hyprland/functional.nix spells it.
  monitorId = m:
    if lib.hasPrefix "desc:" m.identifier then m.identifier
    else if lib.hasInfix " " m.identifier || lib.hasInfix "." m.identifier then "desc:${m.identifier}"
    else m.identifier;
  monitorRule = m: "${monitorId m}, ${m.resolution}, ${m.position}, ${m.scale}"
    + lib.optionalString (m.transform != null) ", transform,${m.transform}";
  otherMonitors = lib.filter (m: m.enabled && m.identifier != tvMonitor.identifier) customConfig.desktop.monitors;
  tvScript = pkgs.writeShellScript "xbox360-tv" ''
    export PATH=${lib.makeBinPath [ pkgs.hyprland pkgs.jq pkgs.coreutils pkgs.gnugrep pkgs.pulseaudio ]}:$PATH
    state=$HOME/.local/state/hypr/disabled-monitors
    saved=$HOME/.local/state/hypr/xbox360-tv
    tvAudio=${lib.escapeShellArg (if tvMonitor.edid == null then "" else tvMonitor.edid)}
    tvLabel=${lib.escapeShellArg tvAudioLabel}
    mkdir -p "$(dirname "$state")" "$saved"
    # Sinks are matched by alsa.name (the monitor's own name over HDMI/DP):
    # the pro-audio sink NUMBERS move whenever outputs come and go.
    sinkNamed() {
      pactl -f json list sinks 2>/dev/null \
        | jq -r --arg n "$1" '.[] | select(.properties["alsa.name"] == $n) | .name' | head -n 1
    }
    case "''${1:-status}" in
      status)
        [ -e "$saved/on" ] && echo on || echo off ;;
      on)
        [ -e "$saved/on" ] && exit 0
        cp "$state" "$saved/disabled-monitors" 2>/dev/null || : > "$saved/disabled-monitors"
        pactl -f json list sinks 2>/dev/null | jq -r --arg d "$(pactl get-default-sink)" \
          '.[] | select(.name == $d) | .properties["alsa.name"] // ""' > "$saved/sink"
        ${lib.optionalString (audioCmd != null) ''${audioCmd} current > "$saved/audio" 2>/dev/null''}
        touch "$saved/on"
        hyprctl keyword monitor ${lib.escapeShellArg (monitorRule tvMonitor)} >/dev/null
        : > "$state"
        ${lib.concatMapStrings (m: ''
          echo ${lib.escapeShellArg (monitorId m)} >> "$state"
          hyprctl keyword monitor ${lib.escapeShellArg "${monitorId m},disable"} >/dev/null
        '') otherMonitors}
        # The TV's HDMI sink appears once the output is lit. With Guide -> Audio
        # the microphone moves too, and a headset in use stays the output.
        if [ -n "$tvLabel" ]; then
          if ! ${audioSh} keeps-tv; then
            for _ in $(seq 20); do
              ${audioSh} set "$tvLabel" >/dev/null 2>&1 && break
              sleep 0.5
            done
          fi
        elif [ -n "$tvAudio" ]; then
          for _ in $(seq 20); do
            s=$(sinkNamed "$tvAudio"); [ -n "$s" ] && { pactl set-default-sink "$s"; break; }
            sleep 0.5
          done
        fi
        ;;
      off)
        [ -e "$saved/on" ] || exit 0
        cp "$saved/disabled-monitors" "$state" 2>/dev/null || : > "$state"
        ${lib.concatMapStrings (m: ''
          if grep -qxF ${lib.escapeShellArg (monitorId m)} "$state"; then
            hyprctl keyword monitor ${lib.escapeShellArg "${monitorId m},disable"} >/dev/null
          else
            hyprctl keyword monitor ${lib.escapeShellArg (monitorRule m)} >/dev/null
          fi
        '') (lib.filter (m: m.enabled) customConfig.desktop.monitors)}
        prev=$(cat "$saved/sink" 2>/dev/null)
        prevAudio=$(cat "$saved/audio" 2>/dev/null)
        rm -f "$saved/on" "$saved/audio"
        if [ -n "$prevAudio" ]; then
          for _ in $(seq 20); do
            ${audioSh} set "$prevAudio" >/dev/null 2>&1 && break
            sleep 0.5
          done
        elif [ -n "$prev" ]; then
          for _ in $(seq 20); do
            s=$(sinkNamed "$prev"); [ -n "$s" ] && { pactl set-default-sink "$s"; break; }
            sleep 0.5
          done
        fi
        ;;
      toggle)
        if [ -e "$saved/on" ]; then "$0" off; else "$0" on; fi ;;
      forget)
        # Displays turned on or off by hand (Guide -> Displays): what is lit
        # now is the new normal, so TV Mode ends without putting anything back.
        rm -f "$saved/on" ;;
    esac
  '';

  # ---- Games Library and Videos -------------------------------------------
  gamesCmd = dashboard;
  gamesConfig = builtins.toJSON { steam = appCmd "gaming"; heroic = appCmd "gamingAlt"; };
  jellyfinPlay = dashboard;

  # ---- the controller daemon (pad/xbox360-pad.py in the dashboard repo) ----
  pad = dashboard;
  # Window classes that are games themselves (not launchers): the controller
  # passes straight through, and the shell gives one its own app workspace
  # when it opens over Steam or Heroic.
  gameClasses = [
    "^steam_app_" "^gamescope"
    # Windows games under Wine/Proton outside Steam (Heroic: Epic, GOG)
    # are classed by their executable, e.g. rocketleague.exe.
    "\\.exe$"
  ];
  padConfig = pkgs.writeText "xbox360-pad.json" (builtins.toJSON {
    hyprctl = "${pkgs.hyprland}/bin/hyprctl";
    # Window classes that read the controller themselves: they get it
    # untouched (anything fullscreen does too). Everything else gets the
    # desktop emulation.
    passthrough = gameClasses ++ [
      "^steam$" "^heroic$" "^retroarch"
      "^org\\.jellyfin" "^com\\.github\\.iwalton3\\.jellyfin" "^dolphin-emu$"
      "^PCSX2" "^Ryujinx" "^Cemu" "^com\\.moonlight_stream" "^Moonlight"
    ];
    # Apps that get their own key map instead: nixpkgs' mpv has no SDL, so it
    # cannot read a controller itself (the Videos library plays in it).
    profiles = [{
      match = "^mpv$";
      keys = {
        a = "KEY_SPACE"; b = "KEY_Q"; x = "KEY_J"; y = "KEY_O"; start = "KEY_SPACE";
        left = "KEY_LEFT"; right = "KEY_RIGHT"; up = "KEY_UP"; down = "KEY_DOWN";
        lb = "KEY_PAGEDOWN"; rb = "KEY_PAGEUP"; lt = "KEY_9"; rt = "KEY_0"; back = "KEY_TAB";
      };
    }];
    # B is "back" (Alt+Left) in these rather than Escape.
    browsers = [ "^firefox" "^chromium" "^librewolf" "^brave" "^google-chrome" ];
    swapXY = false;
    pointerSpeed = 1500;
    scrollSpeed = 14;
  });

  # Startup and session-only lines, appended after the functional extraConfig.
  extraConfig = ''

    # ---- xbox360 rice ----
    # Every display starts on its own dashboard (a named workspace with
    # nothing tiled on it), and focus on the main one. Without a rule (a VM)
    # the shell moves each display from Hyprland's empty workspace to it.
    ${dashboardRules}
    ${lib.optionalString (primaryOutput != "") "exec-once = ${pkgs.hyprland}/bin/hyprctl dispatch focusmonitor ${primaryOutput}"}
    # The shell is the notification daemon here. dunst (century-series) is a
    # D-Bus-activated user service that may still own the name from another
    # session; two owners means one of them is silently never asked.
    exec-once = systemctl --user stop dunst.service
    exec-once = ${pkgs.quickshell}/bin/qs -c xbox360 > /tmp/xbox360-shell.log 2>&1
    exec-once = ${pkgs.pipewire}/bin/pw-play ${assets}/share/sounds/xbox360/select-a.wav
  '';
in
{
  config = lib.mkIf enabled {
    hyprDesktops.xbox360 = {
      inherit settings extraConfig;
      transformSettings = transform;
      # Back in another desktop, TV Mode is off again: it is this desktop's, and
      # the monitor state it writes is shared with century-series' monitor toggles.
      # And no display is left on a dashboard.
      leaveExtraConfig = lib.optionalString (tvMonitor != null) ''
        exec-once = ${tvScript} off
      '' + ''
        exec-once = ${leaveDashboards}
      '';
      # The shell is the bar, the wallpaper and the lock screen.
      waybar = false;
      # --any-display: swayidle may not carry WAYLAND_DISPLAY.
      lockCommand = "${pkgs.quickshell}/bin/qs ipc --any-display -c xbox360 call ui lock";
    };

    # The controller daemon runs for exactly as long as this desktop's session:
    # it grabs the pads and drives the compositor, so it must not outlive it into
    # another desktop. The session puts the compositor's instance into the user
    # manager's environment before starting the target (hyprland/desktops.nix).
    systemd.user.services.xbox360-pad = lib.recursiveUpdate (desktopLib.bindTo "xbox360") {
      Unit.Description = "Xbox 360 dashboard controller daemon";
      Service = {
        ExecStart = "${pad}/bin/xbox360-pad ${padConfig}";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };

    home.packages = [ assets pkgs.quickshell pkgs.papirus-icon-theme ];
    fonts.fontconfig.enable = true;

    # `qs -c xbox360` reads ~/.config/quickshell/xbox360/shell.qml.
    xdg.configFile."quickshell/xbox360".source = shellConfig;
  };
}

# ~/nixos-config/modules/home-manager/themes/xbox360/session.nix
# Renders ~/.config/hypr/xbox360.conf for the "Xbox 360 Dashboard" display-manager
# session (declared in modules/nixos/desktop/hyprland.nix).
#
# How the config is built: home-manager merges every module's
# wayland.windowManager.hyprland.{settings,extraConfig} into the ONE hyprland.conf,
# and once merged the century-series theme cannot be taken back out. So instead
# of reading the merged value, this re-merges the option's individual
# definitions, keeping every one that does NOT come from a theme directory
# (functional.nix, swayidle.nix, ...) and adding this rice's own on top. The
# functional layer — keybinds, monitors, exec-once, window rules — therefore
# reaches both sessions from a single source, and the default hyprland.conf
# is untouched apart from the one exec-once below.
{ config, options, pkgs, lib, customConfig, ... }:

let
  enabled = lib.elem "hyprland" customConfig.desktop.environments
    && lib.elem "xbox360" customConfig.homeManager.themes.hyprlandExtraSessions;

  c = import ./colors.nix { inherit lib; };
  assets = pkgs.callPackage ../../../../pkgs/xbox360-assets { };

  hyprOpts = options.wayland.windowManager.hyprland;

  # Definitions from any theme are styling for the default session only.
  # Matching on the path is the point: the module system records which file
  # each definition came from, and that is the only thing that tells a theme's
  # contribution apart from the functional layer's.
  notFromATheme = def: !(lib.hasInfix "/modules/home-manager/themes/" (toString def.file));

  mergeWith = opt: extra:
    (lib.modules.mergeDefinitions opt.loc opt.type
      (lib.filter notFromATheme opt.definitionsWithLocations
        ++ [ { file = "xbox360/session.nix"; value = extra; } ])).mergedValue;

  # The blades shell paints the whole background, so the functional layer's
  # wallpaper daemon has no place here: started anyway it would put its own
  # background-layer surface (and its cached century wallpaper) under or over
  # the blades, depending on which mapped first.
  isWallpaperDaemon = line: lib.hasInfix "awww-daemon" line || lib.hasInfix "bin/hyprpaper" line;
  mergedSettings =
    let s = mergeWith hyprOpts.settings settings;
    in s // { "exec-once" = lib.filter (l: !isWallpaperDaemon l) (s."exec-once" or [ ]); };

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

    # SUPER+Space and SUPER+Home: to the dashboard, or back to the last app
    # from it. (The Guide takes SUPER+Space over once it exists.)
    "$menu" = lib.mkForce "${pkgs.quickshell}/bin/qs -c xbox360 ipc call ui home";
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
  };

  # Full-screen pages a menu row can open, by id.
  pages = {
    downloads = "PageDownloads.qml";
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
    // Generated by themes/xbox360/session.nix — edit colors.nix, not this.
    .pragma library
    var primary = ${builtins.toJSON primaryOutput};
    var gamertag = ${builtins.toJSON customConfig.user.name};
    var pwPlay = "${pkgs.pipewire}/bin/pw-play";
    var sounds = "${assets}/share/sounds/xbox360";
    var font = "Convection";
    var blades = ${builtins.toJSON (map (n: { inherit (c.blades.${n}) title stops tab ink base rule; }) bladeOrder)};
    var buttons = ${builtins.toJSON c.buttons};
    var menus = ${builtins.toJSON menus};
    var pages = ${builtins.toJSON pages};
    var startBlade = 2;
    var curveDepth = ${toString c.curve.depth};
    var gamerpic = ${builtins.toJSON gamerpic};
    var zone = "Couch";
    var wtype = "${pkgs.wtype}/bin/wtype";
    var hyprctl = "${pkgs.hyprland}/bin/hyprctl";
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
  glslFloats = xs: lib.concatMapStringsSep ", " (x: toString (x * 1.0)) xs;
  bladeFrag = pkgs.writeText "blade.frag" (lib.replaceStrings
    [ "@N@" "@KY@" "@KD@" "@HB@" "@FH@" "@CI@" "@CR@" ]
    ([ (toString (lib.length c.curve.y)) (glslFloats c.curve.y) (glslFloats c.curve.d) ]
      ++ map (k: glslFloats [ c.layout.${k} ]) [ "headerBottom" "footerHeight" "cardInset" "cardRadius" ])
    (builtins.readFile ./blade.frag.in));

  shellConfig = pkgs.runCommand "xbox360-quickshell" { } ''
    mkdir -p $out
    cp ${./shell}/* $out/
    cp ${configJs} $out/Config.js
    ${lib.getBin pkgs.qt6.qtshadertools}/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 \
      -o $out/blade.frag.qsb ${bladeFrag}
  '';

  # ---- the controller daemon (pad/xbox360-pad.py) -----------------------
  padPython = pkgs.python3.withPackages (ps: [ ps.evdev ]);
  pad = pkgs.writeScriptBin "xbox360-pad"
    ("#!${padPython}/bin/python3\n" + builtins.readFile ./pad/xbox360-pad.py);
  padConfig = pkgs.writeText "xbox360-pad.json" (builtins.toJSON {
    hyprctl = "${pkgs.hyprland}/bin/hyprctl";
    # Window classes that read the controller themselves: they get it
    # untouched (anything fullscreen does too). Everything else gets the
    # desktop emulation.
    passthrough = [
      "^steam_app_" "^steam$" "^gamescope" "^mpv$" "^heroic$" "^retroarch"
      "^org\\.jellyfin" "^com\\.github\\.iwalton3\\.jellyfin" "^dolphin-emu$"
      "^PCSX2" "^Ryujinx" "^Cemu" "^com\\.moonlight_stream" "^Moonlight"
    ];
    # B is "back" (Alt+Left) in these rather than Escape.
    browsers = [ "^firefox" "^chromium" "^librewolf" "^brave" "^google-chrome" ];
    swapXY = false;
    pointerSpeed = 1500;
    scrollSpeed = 14;
  });

  # Startup and session-only lines, appended after the functional extraConfig.
  extraConfig = ''

    # ---- xbox360 rice ----
    env = HYPR_RICE,xbox360
    # Start on the dashboard: a named workspace with nothing tiled on it.
    exec-once = ${pkgs.hyprland}/bin/hyprctl dispatch workspace name:dashboard
    exec-once = ${pkgs.quickshell}/bin/qs -c xbox360 > /tmp/xbox360-shell.log 2>&1
    exec-once = ${pad}/bin/xbox360-pad ${padConfig} > /tmp/xbox360-pad.log 2>&1
    exec-once = ${pkgs.pipewire}/bin/pw-play ${assets}/share/sounds/xbox360/select-a.wav
  '';

  xboxConf =
    lib.hm.generators.toHyprconf {
      attrs = mergedSettings;
      importantPrefixes = config.wayland.windowManager.hyprland.importantPrefixes;
    }
    + mergeWith hyprOpts.extraConfig extraConfig;
in
{
  config = lib.mkIf enabled {
    home.packages = [ assets pkgs.quickshell pkgs.papirus-icon-theme ];
    fonts.fontconfig.enable = true;

    # `qs -c xbox360` reads ~/.config/quickshell/xbox360/shell.qml.
    xdg.configFile."quickshell/xbox360".source = shellConfig;

    xdg.configFile."hypr/xbox360.conf" = {
      text = xboxConf;
      # Same reload home-manager does for hyprland.conf: `hyprctl reload`
      # re-reads whichever file each running instance was started with.
      onChange = ''
        (
          XDG_RUNTIME_DIR=''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
          if [[ -d "$XDG_RUNTIME_DIR/hypr" ]]; then
            for i in $(${pkgs.hyprland}/bin/hyprctl instances -j | ${pkgs.jq}/bin/jq -r ".[].instance"); do
              ${pkgs.hyprland}/bin/hyprctl -i "$i" reload config-only
            done
          fi
        )
      '';
    };

    # The default session forgets any rice a previous session left behind, so
    # waybar-start, century-night and friends (which check this file) run again.
    # extraConfig, not exec-once: see the note on `settings` above.
    wayland.windowManager.hyprland.extraConfig = ''
      exec-once = rm -f "$XDG_RUNTIME_DIR/hypr-rice"
    '';
  };
}

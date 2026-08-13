# ~/nixos-config/modules/home-manager/hyprland/functional.nix

{ config, pkgs, lib, customConfig, ... }:

let
  apps = customConfig.apps.programs;

  # Generates the keybinds for one user application from customConfig.apps.programs.
  #
  # Every app gets "<mods>, <key>" to launch it, plus (unless newWs = false) a
  # "<mods> SHIFT, <key>" variant that jumps to an empty workspace first.
  #
  # An app whose command is empty is skipped entirely, so removing an application
  # from customConfig removes its keybind too rather than leaving a bind that
  # fails silently.
  mkAppBinds =
    { key
    , role
    , mods ? "$mainMod"
    , shiftMods ? "${mods} SHIFT"
    , inTerminal ? false
    , newWs ? true
    }:
    let
      app = apps.${role};
      cmd = if inTerminal then "$terminal -e ${app.command}" else app.command;
    in
      lib.optionals (app.command != "") (
        [ "${mods}, ${key}, exec, ${cmd}" ]
        ++ lib.optionals newWs [
          "${shiftMods}, ${key}, workspace, emptym"
          "${shiftMods}, ${key}, exec, ${cmd}"
        ]
      );

  # Helper function to generate Hyprland monitor configuration
  generateMonitorConfig = monitor:
    let
      # Determine if identifier should use desc: prefix
      identifierString = 
        if lib.strings.hasPrefix "desc:" monitor.identifier
        then monitor.identifier
        else if (lib.strings.hasInfix " " monitor.identifier) || (lib.strings.hasInfix "." monitor.identifier)
        then "desc:${monitor.identifier}"
        else monitor.identifier;
      
      # Build transform string
      transformString = if monitor.transform != null then ", transform,${monitor.transform}" else "";
    in
    "${identifierString}, ${monitor.resolution}, ${monitor.position}, ${monitor.scale}${transformString}";

  # A 0.1-second silent WAV (48kHz stereo 16-bit) built at eval time.
  # Played at login to initialize WirePlumber's mixer node for HDMI pro-audio sinks.
  # Without an audio stream, wpctl get-volume returns hardware level (1.00) instead of
  # the WirePlumber software volume, causing the waybar audio widget to show 100%.
  initSilenceWav = pkgs.runCommand "init-silence.wav" {
    buildInputs = [ pkgs.sox ];
  } ''
    ${pkgs.sox}/bin/sox -n -r 48000 -c 2 -b 16 $out trim 0 0.1
  '';

  # Script to move the active window to a new workspace on the same monitor.
  # When Hyprland creates a new workspace via movetoworkspace, it may assign it
  # to the TV (which has no workspaces) rather than the current monitor.
  # Fix: move silently, then only relocate to the correct monitor if it drifted.
  moveToNewWsOnMonitor = pkgs.writeShellScriptBin "move-to-new-ws-on-monitor" ''
    monitor=$(${pkgs.hyprland}/bin/hyprctl -j activeworkspace | ${pkgs.jq}/bin/jq -r '.monitor')
    workspaces_json=$(${pkgs.hyprland}/bin/hyprctl -j workspaces)
    last_ws=$(echo "$workspaces_json" | ${pkgs.jq}/bin/jq -r \
      --arg mon "$monitor" \
      '[.[] | select(.monitor == $mon) | .id] | sort | last // 0')
    next_ws=$((last_ws + 1))
    # Skip any workspace IDs that already exist (on any monitor) to avoid
    # dragging another monitor's workspace and its windows to this monitor.
    while echo "$workspaces_json" | ${pkgs.jq}/bin/jq -e --argjson id "$next_ws" 'map(.id) | contains([$id])' > /dev/null 2>&1; do
      next_ws=$((next_ws + 1))
    done
    ${pkgs.hyprland}/bin/hyprctl dispatch movetoworkspacesilent "$next_ws"
    ${pkgs.hyprland}/bin/hyprctl dispatch workspace "$next_ws"
  '';

  launcherEnabled = customConfig.desktop.hyprland.launcher.enable;

  # Filter autostart entries for Hyprland and build exec-once commands
  hyprlandAutostart = lib.filter (app:
    app.desktops == [] || lib.elem "hyprland" app.desktops
  ) customConfig.desktop.autostart;

  # Use [workspace N silent] prefix only when no windowClass is provided.
  # When windowClass is set, workspace assignment is handled by windowrulev2 (more reliable for XWayland).
  mkExecOnce = app:
    if app.workspace != null && app.windowClass == null
    then "[workspace ${toString app.workspace} silent] ${app.command}"
    else app.command;

  # Generate windowrulev2 lines for apps with both windowClass and workspace set
  autostartWindowRules = lib.concatMapStrings (app:
    lib.optionalString (app.windowClass != null && app.workspace != null)
      "windowrulev2 = workspace ${toString app.workspace} silent, class:^(${app.windowClass})$\n"
  ) hyprlandAutostart;

  # Generate windowrulev2 lines for utility workspace apps
  utilityWindowRules = lib.concatMapStrings (app:
    "windowrulev2 = workspace special:ckb silent, class:^(${app.windowClass})$\n"
  ) customConfig.desktop.hyprland.utilityApps;

  # Empty submap activated while hyprland-keys is open.
  # Prevents all Hyprland keybinds from firing so the user can explore
  # binds safely. The app activates/deactivates it via hyprctl IPC.
  # Emergency fallback bind: Escape resets + kills a stale process.
  hyprlandKeysSubmap = ''
    submap = hyprland-keys
    bind = , escape, exec, hyprctl dispatch submap reset && pkill -f hyprland-keys
    submap = reset
  '';

  # Get the wayvnc target monitor description
  wayvncTargetMonitor =
    if customConfig.desktop.wayvnc.enable && customConfig.desktop.wayvnc.targetMonitor != null
    then 
      let 
        targetMon = lib.findFirst 
          (m: m.name == customConfig.desktop.wayvnc.targetMonitor) 
          null 
          customConfig.desktop.monitors;
      in
        if targetMon != null 
        then if lib.strings.hasPrefix "desc:" targetMon.identifier
             then targetMon.identifier
             else if (lib.strings.hasInfix " " targetMon.identifier) || (lib.strings.hasInfix "." targetMon.identifier)
             then "desc:${targetMon.identifier}"
             else targetMon.identifier
        else null
    else null;

in
{
  imports = [
    # Import scripts
    ../scripts/set-wayvnc-output.nix
    ../scripts/hyprland-keys.nix
    ../scripts/toggle-monitor.nix
  ];

  config = lib.mkIf ((customConfig.desktop.enable) && (lib.elem "hyprland" customConfig.desktop.environments)) {

    # -------------------------------------------------------------------------- #
    # Functional Services
    # -------------------------------------------------------------------------- #
    services.swaync = {
      enable = true;
    };

    services.cliphist = {
      enable = true;
    };

    # -------------------------------------------------------------------------- #
    # Hyprland Functional Configuration
    # -------------------------------------------------------------------------- #
    wayland.windowManager.hyprland = {
      enable = true;
      package = null; # Assuming you manage Hyprland package via NixOS config

      #enableNvidiaPatches = true; no longer has any effect

      systemd.enable = false;

      extraConfig = autostartWindowRules + utilityWindowRules + hyprlandKeysSubmap;

      settings = {
        # Variables for tools and modifiers
        "$mainMod" = "SUPER";
        "$altMod" = "ALT";
        "$ctrlMod" = "CONTROL";
        "$terminal" = lib.mkDefault apps.terminal.command;
        "$fileManager" = lib.mkDefault apps.fileManager.command;
        "$menu" = "${pkgs.rofi}/bin/rofi -show drun";

        # Monitor configuration from customConfig
        monitor = lib.mkDefault (
          let
            enabledMonitors = lib.filter (m: m.enabled) customConfig.desktop.monitors;
          in
            if (lib.length enabledMonitors) > 0
            then map generateMonitorConfig enabledMonitors
            else [ ",preferred,auto,1" ] # Default catch-all for single monitor systems
        );

        # exec-once: For functional startup applications
        "exec-once" = lib.mkDefault (
          (lib.optionals customConfig.desktop.wayvnc.enable [
            "${pkgs.wayvnc}/bin/wayvnc --render-cursor localhost 5900"
          ] ++ lib.optionals (customConfig.desktop.wayvnc.enable && wayvncTargetMonitor != null) [
            "set-wayvnc-output \"${wayvncTargetMonitor}\" > /tmp/set-wayvnc-output.log 2>&1"
          ])
          ++ (map mkExecOnce hyprlandAutostart)
          ++ (map (app: app.command) customConfig.desktop.hyprland.utilityApps)
          ++ lib.optionals customConfig.homeManager.services.hyprsunset.enable [
            "hyprsunset-init"
          ]
          ++ [
            # Import Wayland session vars into systemd/dbus so user services can use them
            "dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP"
            # Launch waybar via wrapper — splits main/launcher into separate processes
            "sleep 1 && $HOME/.local/bin/waybar-start > /tmp/waybar-start.log 2>&1"
            # Re-apply persisted monitor on/off state (runs after waybar so it can restart cleanly)
            "sleep 2 && restore-monitors"
            # Keep persisted monitor state applied across config reloads (e.g. after a rebuild),
            # not just at startup — watches Hyprland's event socket for configreloaded events.
            "monitor-state-watcher > /tmp/monitor-state-watcher.log 2>&1 &"
            # Initialize WirePlumber mixer by playing silent audio, then refresh waybar.
            # Without this, wpctl get-volume returns 1.00 on HDMI pro-audio sinks until
            # real audio plays, causing the volume widget to display 100% at boot.
            "sleep 3 && ${pkgs.pulseaudio}/bin/paplay --volume=0 ${initSilenceWav} && pkill -RTMIN+11 waybar"
            "${pkgs.hyprpaper}/bin/hyprpaper &"
            "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1 &"
            "${pkgs.networkmanagerapplet}/bin/nm-applet &"
          ]
        );

        # XWayland fractional scaling fix — render at native pixels, not logical resolution.
        # Without this, XWayland apps (Steam, games) render at the scaled logical size
        # and get upscaled by Hyprland, causing blurry UI and wrong game resolutions.
        xwayland = {
          force_zero_scaling = true;
        };

        # Environment variables
        env = [
          "XCURSOR_SIZE,24"
          "QT_QPA_PLATFORMTHEME,qt6ct"
          "LIBVA_DRIVER_NAME,nvidia"
          "__GLX_VENDOR_LIBRARY_NAME,nvidia"
          # Tell GTK/Steam to not apply their own scaling on top of XWayland's native pixels
          "GDK_SCALE,1"
          "STEAM_FORCE_DESKTOPUI_SCALING,1"
          # NixOS sets this to force xdg-open through the portal, but the portal
          # shows an app-chooser dialog even when mimeapps.list has a clear default.
          # Unsetting it restores the direct mimeapps.list lookup which works correctly.
          "NIXOS_XDG_OPEN_USE_PORTAL,"
        ] ++ lib.optional (customConfig.desktop.hyprland.drmDevice != null)
            "AQ_DRM_DEVICES,${customConfig.desktop.hyprland.drmDevice}";

        # Input settings
        input = {
          kb_layout = "us";
          kb_variant = "";
          kb_model = "";
          kb_options = "";
          kb_rules = "";
          follow_mouse = 1;
          touchpad = {
            natural_scroll = lib.mkDefault customConfig.hardware.touchpad.naturalScroll;
          };
          sensitivity = 0;
        };

        # Functional general settings
        general = {
          layout = "dwindle"; # Default layout
          allow_tearing = false;
        };

        # Layout-specific settings (functional behavior)
        dwindle = {
          pseudotile = true;
          preserve_split = true;
        };
        master = {
          # new_is_master = true; # Example if you used this
        };

        # Gestures settings (removed in newer Hyprland versions)
        # gestures = {
        #   workspace_swipe = false;
        # };

        # Miscellaneous functional settings
        misc = {
          force_default_wallpaper = -1; # Important if another tool handles wallpaper
          disable_hyprland_logo = true;
          vfr = false; # Prevents damage tracking artifacts (black lines, stale pixels)
        };

        # Keybindings
        bind = [
          # Launcher and rebuild — infrastructure, not user applications.
          "$mainMod, SPACE, exec, $menu"
          "$ctrlMod $mainMod, R, exec, $terminal -e rebuild"
        ]
        # User application binds, generated from customConfig.apps.programs so
        # that dropping an app from a host also drops its keybind.
        ++ lib.concatMap mkAppBinds [
          { key = "RETURN"; role = "terminal"; }
          { key = "I";      role = "ide"; }
          { key = "T";      role = "editor"; }
          { key = "F";      role = "fileManagerTUI"; inTerminal = true; }
          { key = "F";      role = "fileManager";    mods = "$mainMod $altMod"; shiftMods = "$mainMod SHIFT $altMod"; }
          { key = "B";      role = "browser"; }
          { key = "B";      role = "browserAlt";     mods = "$mainMod $altMod"; shiftMods = "$mainMod SHIFT $altMod"; }
          { key = "M";      role = "music"; }
          { key = "C";      role = "chat"; }
          { key = "G";      role = "gaming"; }
          { key = "G";      role = "gamingAlt";      mods = "$mainMod $altMod"; shiftMods = "$mainMod SHIFT $altMod"; }

          # No new-workspace variant for these.
          { key = "ESCAPE"; role = "taskManager";     mods = "$ctrlMod SHIFT";   inTerminal = true; newWs = false; }
          { key = "C";      role = "chatAlt";         mods = "$mainMod $altMod"; newWs = false; }
          { key = "M";      role = "audioVisualizer"; mods = "$mainMod $altMod"; inTerminal = true; newWs = false; }
          { key = "P";      role = "passwordManager"; newWs = false; }
        ]
        ++ [

          # Window Management
          "$mainMod, Q, killactive,"
          "$mainMod $ctrlMod, F, togglefloating,"
          "$mainMod, left, swapwindow, l"
          "$mainMod, right, swapwindow, r"
          "$mainMod, up, swapwindow, u"
          "$mainMod, down, swapwindow, d"
          "$mainMod, H, movefocus, l"
          "$mainMod, J, movefocus, d"
          "$mainMod, K, movefocus, u"
          "$mainMod, L, movefocus, r"
          "$mainMod, A, movefocus, l"
          "$mainMod, S, movefocus, d"
          "$mainMod, W, movefocus, u"
          "$mainMod, D, movefocus, r"
          "r:CONTROL, left, movefocus, l"
          "r:CONTROL, right, movefocus, r"
          "r:CONTROL, up, movefocus, u"
          "r:CONTROL, down, movefocus, d"
          "$mainMod, F11, fullscreen,"
          "$mainMod, bracketleft, exec, hyprctl keyword general:layout dwindle"
          "$mainMod, bracketright, exec, hyprctl keyword general:layout master"

          # Resize active window
          "$mainMod SHIFT, H, resizeactive, -20 0"
          "$mainMod SHIFT, J, resizeactive, 0 20"
          "$mainMod SHIFT, K, resizeactive, 0 -20"
          "$mainMod SHIFT, L, resizeactive, 20 0"

        ] ++ (lib.lists.concatMap (ws: [
            "$mainMod, ${toString ws}, workspace, ${toString ws}"
            "$mainMod SHIFT, ${toString ws}, movetoworkspace, ${toString ws}"
          ]) (lib.lists.range 1 9)
        ) ++ [
          "$mainMod, 0, workspace, 10"
          "$mainMod SHIFT, 0, movetoworkspace, 10"
          # Focus adjacent monitor
          "$ctrlMod $mainMod, right, focusmonitor, +1"
          "$ctrlMod $mainMod, left, focusmonitor, -1"
          # Workspace navigation (active monitor only)
          "$ctrlMod $mainMod, up, workspace, m+1"
          "$ctrlMod $mainMod, down, workspace, m-1"

          # Move window to adjacent monitor
          "$mainMod SHIFT, right, movewindow, mon:+1"
          "$mainMod SHIFT, left, movewindow, mon:-1"
          # Move window to new workspace on same monitor / prev workspace on same monitor
          "$mainMod SHIFT, up, exec, ${moveToNewWsOnMonitor}/bin/move-to-new-ws-on-monitor"
          "$mainMod SHIFT, down, movetoworkspace, m-1"

          # Special workspace toggle (hidden utility apps like ckb-next)
          "$mainMod, grave, togglespecialworkspace, ckb"
          "$mainMod SHIFT, grave, movetoworkspace, special:ckb"
          "$mainMod $altMod, UP, movetoworkspace, special:ckb"

          # System & Utility Bindings
          "$mainMod, slash, exec, hyprland-keys"
          "$mainMod, ESCAPE, exec, swaylock"
          "$mainMod, BackSpace, exec, wlogout"
          "$mainMod, V, exec, ${pkgs.cliphist}/bin/cliphist list | ${pkgs.rofi}/bin/rofi -dmenu -p 'CLIPBOARD' | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy"
          "$mainMod SHIFT, S, exec, ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" ${config.home.homeDirectory}/Pictures/Screenshots/$(date +'%Y-%m-%d_%H-%M-%S').png"
          "$mainMod SHIFT, R, exec, hyprctl reload"
          "$mainMod SHIFT, Q, exit,"

          # Media Keys
          ", XF86AudioPlay, exec, ${pkgs.playerctl}/bin/playerctl --player=spotify play-pause"
          ", XF86AudioNext, exec, ${pkgs.playerctl}/bin/playerctl --player=spotify next"
          ", XF86AudioPrev, exec, ${pkgs.playerctl}/bin/playerctl --player=spotify previous"
          ", XF86AudioMute, exec, ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && sleep 0.1 && pkill -RTMIN+11 waybar"
          ", XF86AudioLowerVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && sleep 0.1 && pkill -RTMIN+11 waybar"
          ", XF86AudioRaiseVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ && sleep 0.1 && pkill -RTMIN+11 waybar"

          # Audio sink cycling — uses bind (not binde) to prevent rapid-fire concurrent calls
          "$mainMod, XF86AudioRaiseVolume, exec, cycle-audio-sink next"
          "$mainMod, XF86AudioLowerVolume, exec, cycle-audio-sink prev"
          "$ctrlMod $mainMod, A, exec, cycle-audio-sink next"
          "$ctrlMod $mainMod, L, exec, toggle-audio-flip"

        ] ++ (lib.imap1 (i: mon:
          let
            monId =
              if lib.strings.hasPrefix "desc:" mon.identifier
              then mon.identifier
              else if (lib.strings.hasInfix " " mon.identifier) || (lib.strings.hasInfix "." mon.identifier)
              then "desc:${mon.identifier}"
              else mon.identifier;
            configStr = generateMonitorConfig mon;
          in
          "$ctrlMod $mainMod, ${toString i}, exec, toggle-monitor \"${monId}\" \"${configStr}\""
        ) customConfig.desktop.monitors)
        ++ lib.optionals launcherEnabled [
          # Toggle bottom launchbar on/off, state persists across reboots
          "$ctrlMod $mainMod, B, exec, $HOME/.local/bin/toggle-launchbar"
        ];

        # Mouse bindings
        bindm = [
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];

        # Window rules
        windowrulev2 = [
          # hyprland-keys overlay: float, cover full screen, stay on top
          "float,        class:^(land.lando.hyprland-keys)$"
          "center,       class:^(land.lando.hyprland-keys)$"
          "size 1440 820,class:^(land.lando.hyprland-keys)$"
          "pin,          class:^(land.lando.hyprland-keys)$"
          "noborder,     class:^(land.lando.hyprland-keys)$"
          "noshadow,     class:^(land.lando.hyprland-keys)$"
          "stayfocused,  class:^(land.lando.hyprland-keys)$"

          # Steam games: force real fullscreen and enable immediate (raw) input.
          # "immediate" bypasses Hyprland's input processing for lower latency and
          # fixes mouse capture issues in XWayland games.
          "fullscreen,   class:^(steam_app_.*)$"
          "immediate,    class:^(steam_app_.*)$"
        ];
      }; # End of wayland.windowManager.hyprland.settings
    }; # End of wayland.windowManager.hyprland

    # -------------------------------------------------------------------------- #
    # Swaylock - Default configuration (themes can override)
    # -------------------------------------------------------------------------- #
    programs.swaylock = {
      enable = lib.mkDefault true;
      # Basic swaylock package; themes may override with swaylock-effects
      package = lib.mkDefault pkgs.swaylock;
    };

    # -------------------------------------------------------------------------- #
    # Waybar Wrapper Script
    # -------------------------------------------------------------------------- #
    home.file.".local/bin/waybar-start" = {
      text = ''
        #!/usr/bin/env bash
        # Launch waybar, splitting launcherBar into a separate process so it can be
        # toggled independently with toggle-launchbar (SUPER+CTRL+B).

        CONFIG_SOURCE="$HOME/.config/waybar/config"
        STYLE="$HOME/.config/waybar/style.css"
        MAIN_CONFIG="/tmp/waybar-main-config.json"
        LAUNCHER_CONFIG="/tmp/waybar-launcher-config.json"
        STATE_FILE="$HOME/.local/state/hypr/launchbar-hidden"

        if ${pkgs.jq}/bin/jq -e 'type == "object" and has("launcherBar")' "$CONFIG_SOURCE" > /dev/null 2>&1; then
          # Object format — extract each bar as a flat config (not wrapped in a named key;
          # waybar only uses multi-bar format when given 2+ top-level keys)
          ${pkgs.jq}/bin/jq '.mainBar' "$CONFIG_SOURCE" > "$MAIN_CONFIG"
          ${pkgs.jq}/bin/jq '.launcherBar' "$CONFIG_SOURCE" > "$LAUNCHER_CONFIG"

          # Start launcher bar only if not hidden
          if [ ! -f "$STATE_FILE" ]; then
            ${pkgs.waybar}/bin/waybar --config "$LAUNCHER_CONFIG" --style "$STYLE" &
          fi

          # Start main bar (exec replaces this shell — keeps process alive for logging)
          exec ${pkgs.waybar}/bin/waybar --config "$MAIN_CONFIG" --style "$STYLE"

        elif ${pkgs.jq}/bin/jq -e 'type == "array"' "$CONFIG_SOURCE" > /dev/null 2>&1; then
          # Array format (home-manager default) — extract each element as a flat config
          ARRAY_LENGTH=$(${pkgs.jq}/bin/jq 'length' "$CONFIG_SOURCE")
          if [ "$ARRAY_LENGTH" -gt 1 ]; then
            # .[0] = launcherBar, .[1] = mainBar (order from HM config generation)
            ${pkgs.jq}/bin/jq '.[0]' "$CONFIG_SOURCE" > "$LAUNCHER_CONFIG"
            ${pkgs.jq}/bin/jq '.[1]' "$CONFIG_SOURCE" > "$MAIN_CONFIG"
            if [ ! -f "$STATE_FILE" ]; then
              ${pkgs.waybar}/bin/waybar --config "$LAUNCHER_CONFIG" --style "$STYLE" &
            fi
            exec ${pkgs.waybar}/bin/waybar --config "$MAIN_CONFIG" --style "$STYLE"
          else
            ${pkgs.jq}/bin/jq '.[0]' "$CONFIG_SOURCE" > "$MAIN_CONFIG"
            exec ${pkgs.waybar}/bin/waybar --config "$MAIN_CONFIG" --style "$STYLE"
          fi

        else
          # Single bar object — use as-is
          exec ${pkgs.waybar}/bin/waybar "$@"
        fi
      '';
      executable = true;
    };

    home.file.".local/bin/toggle-launchbar" = {
      text = ''
        #!/usr/bin/env bash
        # Toggle the bottom launchbar on/off, persisting state across reboots.
        # State: ~/.local/state/hypr/launchbar-hidden — presence means hidden.

        STATE_FILE="$HOME/.local/state/hypr/launchbar-hidden"
        LAUNCHER_CONFIG="/tmp/waybar-launcher-config.json"
        STYLE="$HOME/.config/waybar/style.css"

        mkdir -p "$(dirname "$STATE_FILE")"

        if [ -f "$STATE_FILE" ]; then
          # Currently hidden — show it
          rm "$STATE_FILE"
          ${pkgs.waybar}/bin/waybar --config "$LAUNCHER_CONFIG" --style "$STYLE" &
          disown
          ${pkgs.libnotify}/bin/notify-send -t 1500 -i desktop "Launchbar" "Panel ONLINE"
        else
          # Currently visible — hide it
          touch "$STATE_FILE"
          pkill -f "waybar --config $LAUNCHER_CONFIG"
          ${pkgs.libnotify}/bin/notify-send -t 1500 -i desktop "Launchbar" "Panel OFFLINE"
        fi
      '';
      executable = true;
    };

    # -------------------------------------------------------------------------- #
    # Home Manager Packages for Functional Elements
    #
    # Compositor infrastructure only. User applications (browser, editors, file
    # manager, media players, chat, ...) are declared in customConfig.apps.programs
    # and installed by modules/home-manager/system/apps.nix, so a host can see and
    # override its own application set instead of inheriting a hidden bundle from
    # whichever window manager it happens to enable.
    # -------------------------------------------------------------------------- #
    home.packages = with pkgs; [
      moveToNewWsOnMonitor
      rofi         # backs the $menu variable and the cliphist picker

      # swaylock provided by programs.swaylock (theme or default)
      grim
      slurp
      wl-clipboard # For cliphist/rofi integration
      playerctl
      pulseaudio # For pactl
    ] ++ lib.optionals customConfig.desktop.wayvnc.enable [
      wayvnc
    ];
  };
}
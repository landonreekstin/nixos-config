# ~/nixos-config/modules/home-manager/hyprland/functional.nix

{ config, pkgs, lib, customConfig, ... }:

let
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
    ../scripts/keybind-help.nix
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

      extraConfig = autostartWindowRules + utilityWindowRules;

      settings = {
        # Variables for tools and modifiers
        "$mainMod" = "SUPER";
        "$altMod" = "ALT";
        "$ctrlMod" = "CONTROL";
        "$terminal" = "${pkgs.kitty}/bin/kitty"; # Ensure kitty is in home.packages or systemPackages
        "$fileManager" = "${pkgs.cosmic-files}/bin/cosmic-files"; # Ensure cosmic-files is available
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
            # Launch waybar directly - it handles array configs natively
            "sleep 1 && ${pkgs.waybar}/bin/waybar > /tmp/waybar-start.log 2>&1 &"
            # Re-apply persisted monitor on/off state (runs after waybar so it can restart cleanly)
            "sleep 2 && restore-monitors"
            "${pkgs.hyprpaper}/bin/hyprpaper &"
            "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1 &"
            "${pkgs.networkmanagerapplet}/bin/nm-applet &"
          ]
        );

        # Environment variables
        env = [
          "XCURSOR_SIZE,24"
          "QT_QPA_PLATFORMTHEME,qt6ct"
          "LIBVA_DRIVER_NAME,nvidia"
          "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        ];

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
          # Applications
          "$mainMod, SPACE, exec, $menu"
          "$mainMod, RETURN, exec, $terminal"
          "$ctrlMod $mainMod, R, exec, $terminal -e rebuild"
          "$mainMod SHIFT, RETURN, workspace, empty"
          "$mainMod SHIFT, RETURN, exec, $terminal"
          "$ctrlMod SHIFT, ESCAPE, exec, $terminal -e ${customConfig.desktop.hyprland.applications.taskManager}"
          "$mainMod, I, exec, ${customConfig.desktop.hyprland.applications.ide}"
          "$mainMod SHIFT, I, workspace, empty"
          "$mainMod SHIFT, I, exec, ${customConfig.desktop.hyprland.applications.ide}"
          "$mainMod, T, exec, ${customConfig.desktop.hyprland.applications.editor}"
          "$mainMod SHIFT, T, workspace, empty"
          "$mainMod SHIFT, T, exec, ${customConfig.desktop.hyprland.applications.editor}"
          "$mainMod, F, exec, $terminal -e ${customConfig.desktop.hyprland.applications.fileManagerTUI}"
          "$mainMod SHIFT, F, workspace, empty"
          "$mainMod SHIFT, F, exec, $terminal -e ${customConfig.desktop.hyprland.applications.fileManagerTUI}"
          "$mainMod $altMod, F, exec, $fileManager"
          "$mainMod SHIFT $altMod, F, workspace, empty"
          "$mainMod SHIFT $altMod, F, exec, $fileManager"
          "$mainMod, B, exec, ${customConfig.desktop.hyprland.applications.browser}"
          "$mainMod SHIFT, B, workspace, empty"
          "$mainMod SHIFT, B, exec, ${customConfig.desktop.hyprland.applications.browser}"
          "$mainMod $altMod, B, exec, ${customConfig.desktop.hyprland.applications.browserAlt}"
          "$mainMod SHIFT $altMod, B, workspace, empty"
          "$mainMod SHIFT $altMod, B, exec, ${customConfig.desktop.hyprland.applications.browserAlt}"
          "$mainMod, M, exec, ${customConfig.desktop.hyprland.applications.music}"
          "$mainMod SHIFT, M, workspace, empty"
          "$mainMod SHIFT, M, exec, ${customConfig.desktop.hyprland.applications.music}"
          "$mainMod, D, exec, ${customConfig.desktop.hyprland.applications.chat}"
          "$mainMod SHIFT, D, workspace, empty"
          "$mainMod SHIFT, D, exec, ${customConfig.desktop.hyprland.applications.chat}"
          "$mainMod, G, exec, ${customConfig.desktop.hyprland.applications.gaming}"
          "$mainMod SHIFT, G, workspace, empty"
          "$mainMod SHIFT, G, exec, ${customConfig.desktop.hyprland.applications.gaming}"
          "$mainMod $altMod, G, exec, ${customConfig.desktop.hyprland.applications.gamingAlt}"
          "$mainMod SHIFT $altMod, G, workspace, empty"
          "$mainMod SHIFT $altMod, G, exec, ${customConfig.desktop.hyprland.applications.gamingAlt}"

          # Window Management
          "$mainMod, Q, killactive,"
          "$mainMod $ctrlMod, F, togglefloating,"
          "$mainMod, left, movefocus, l"
          "$mainMod, right, movefocus, r"
          "$mainMod, up, movefocus, u"
          "$mainMod, down, movefocus, d"
          "$mainMod, H, swapwindow, l"
          "$mainMod, J, swapwindow, d"
          "$mainMod, K, swapwindow, u"
          "$mainMod, L, swapwindow, r"
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
          # Workspace navigation
          "$ctrlMod $mainMod, right, workspace, e+1"
          "$ctrlMod $mainMod, left, workspace, e-1"
          
          # Move window to next/previous workspace
          "$mainMod SHIFT, right, movetoworkspace, e+1"
          "$mainMod SHIFT, left, movetoworkspace, e-1"

          # Special workspace toggle (hidden utility apps like ckb-next)
          "$mainMod, grave, togglespecialworkspace, ckb"
          "$mainMod SHIFT, grave, movetoworkspace, special:ckb"

          # System & Utility Bindings
          "$mainMod, slash, exec, hypr-keybinds"
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
          ", XF86AudioMute, exec, ${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle"
          ", XF86AudioLowerVolume, exec, ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -5%"
          ", XF86AudioRaiseVolume, exec, ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +5%"

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
        ) customConfig.desktop.monitors);

        # Audio sink cycling.
        # SUPER+VolumeUp/Down: fires once per SUPER press (XF86 media keys can't
        # repeat while a modifier is held — Hyprland limitation).
        # SUPER+, / SUPER+. and CTRL+SUPER+A: regular keys, work with binde repeat
        # so you can hold SUPER and keep pressing to cycle through sinks.
        binde = [
          "$mainMod, XF86AudioRaiseVolume, exec, cycle-audio-sink next"
          "$mainMod, XF86AudioLowerVolume, exec, cycle-audio-sink prev"
          "$mainMod, comma,  exec, cycle-audio-sink prev"
          "$mainMod, period, exec, cycle-audio-sink next"
          "$ctrlMod $mainMod, A, exec, cycle-audio-sink next"
        ];

        # Mouse bindings
        bindm = [
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];

        # Window rules (example, uncomment and populate as needed)
        # windowrulev2 = [
        #   "float,class:^(kitty)$,title:^(kitty)$"
        # ];
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
        # Convert home-manager's array config to object format for waybar

        CONFIG_SOURCE="$HOME/.config/waybar/config"
        CONFIG_TEMP="/tmp/waybar-config.json"

        # Check if config is an array
        if ${pkgs.jq}/bin/jq -e 'type == "array"' "$CONFIG_SOURCE" > /dev/null 2>&1; then
          # Get array length
          ARRAY_LENGTH=$(${pkgs.jq}/bin/jq 'length' "$CONFIG_SOURCE")

          if [ "$ARRAY_LENGTH" -gt 1 ]; then
            # Multiple bars - convert to named object format
            # Assuming first element is launcherBar, second is mainBar
            ${pkgs.jq}/bin/jq '{launcherBar: .[0], mainBar: .[1]}' "$CONFIG_SOURCE" > "$CONFIG_TEMP"
          else
            # Single bar - extract first element
            ${pkgs.jq}/bin/jq '.[0]' "$CONFIG_SOURCE" > "$CONFIG_TEMP"
          fi

          exec ${pkgs.waybar}/bin/waybar --config "$CONFIG_TEMP" "$@"
        else
          # Use config as-is
          exec ${pkgs.waybar}/bin/waybar "$@"
        fi
      '';
      executable = true;
    };

    # -------------------------------------------------------------------------- #
    # Home Manager Packages for Functional Elements
    # -------------------------------------------------------------------------- #
    home.packages = with pkgs; [
      # Terminals, Launchers, File Managers (if not specified elsewhere and used in binds)
      kitty
      cosmic-files # if you decide to use this
      rofi

      # Core utilities from your original list, if not pulled by services:
      kdePackages.kate
      kdePackages.konsole # Often a dependency for Kate or other KDE apps
      brave
      discord

      # From Hyprland exec/binds not covered by services:
      (if pkgs ? vscode then vscode else null) # Conditional if package might not exist
      # swaylock provided by programs.swaylock (theme or default)
      grim
      slurp
      wl-clipboard # For cliphist/rofi integration
      playerctl
      pulseaudio # For pactl

    # Only add plain librewolf if the homeManager.librewolf module is not managing it;
    # that module installs its own patched derivation and having both causes a policies.json conflict.
    ] ++ lib.optionals (!customConfig.homeManager.librewolf.enable) [
      pkgs.librewolf
    ] ++ lib.optionals customConfig.desktop.wayvnc.enable [
      wayvnc
    ];
  };
}
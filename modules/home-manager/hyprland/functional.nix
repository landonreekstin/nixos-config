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
    # Import the set-wayvnc-output script
    ../scripts/set-wayvnc-output.nix
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

      settings = {
        # Variables for tools and modifiers
        "$mainMod" = "SUPER";
        "$altMod" = "ALT";
        "$ctrlMod" = "CONTROL";
        "$terminal" = "${pkgs.kitty}/bin/kitty"; # Ensure kitty is in home.packages or systemPackages
        "$fileManager" = "${pkgs.cosmic-files}/bin/cosmic-files"; # Ensure cosmic-files is available
        "$menu" = "${pkgs.wofi}/bin/wofi --show drun"; # Ensure wofi is available

        # Monitor configuration from customConfig
        monitor = lib.mkDefault (
          let
            enabledMonitors = lib.filter (m: m.enabled) customConfig.desktop.monitors;
          in
            if (lib.length enabledMonitors) > 0
            then map generateMonitorConfig enabledMonitors
            else [ "preferred" ] # Default configuration for single monitor systems
        );

        # exec-once: For functional startup applications
        "exec-once" = lib.mkDefault (
          (lib.optionals customConfig.desktop.wayvnc.enable [
            "${pkgs.wayvnc}/bin/wayvnc --render-cursor localhost 5900"
          ] ++ lib.optionals (customConfig.desktop.wayvnc.enable && wayvncTargetMonitor != null) [
            "set-wayvnc-output \"${wayvncTargetMonitor}\" > /tmp/set-wayvnc-output.log 2>&1"
          ]) ++ [
            "${pkgs.waybar}/bin/waybar &"
            "${pkgs.hyprpaper}/bin/hyprpaper &"
            "${pkgs.gammastep}/bin/gammastep &"
            "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1 &"
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
            natural_scroll = false;
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

        # Gestures settings
        gestures = {
          workspace_swipe = false;
        };

        # Miscellaneous functional settings
        misc = {
          force_default_wallpaper = -1; # Important if another tool handles wallpaper
          disable_hyprland_logo = true;
        };

        # Keybindings
        bind = [
          # Applications
          "$mainMod, SPACE, exec, $menu"
          "$mainMod, RETURN, exec, $terminal"
          "$$ctrlMod SHIFT, ESCAPE, exec, $terminal -e ${pkgs.btop-rocm}/bin/btop"
          "$mainMod, I, exec, ${pkgs.vscode}/bin/code"
          "$mainMod, T, exec, ${pkgs.kdePackages.kate}/bin/kate"
          "$mainMod, F, exec, $terminal -e ${pkgs.yazi}/bin/yazi"
          "$mainMod SHIFT, F, exec, ${pkgs.cosmic-files}/bin/cosmic-files"
          "$mainMod, B, exec, ${pkgs.librewolf}/bin/librewolf"
          "$mainMod SHIFT, B, exec, ${pkgs.brave}/bin/brave"
          "$mainMod, M, exec, ${pkgs.spotify}/bin/spotify --enable-features=UseOzonePlatform --ozone-platform=wayland"
          "$mainMod, D, exec, ${pkgs.discord}/bin/discord"
          "$mainMod, G, exec, steam"
          "$mainMod SHIFT, G, exec, ${pkgs.lutris}/bin/lutris" 

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
          "$mainMod, F11, fullscreen,"
          "$mainMod, bracketleft, exec, hyprctl keyword general:layout dwindle"
          "$mainMod, bracketright, exec, hyprctl keyword general:layout master"

          # Resize active window
          "$mainMod SHIFT, H, resizeactive, -20 0"
          "$mainMod SHIFT, J, resizeactive, 0 20"
          "$mainMod SHIFT, K, resizeactive, 0 -20"
          "$mainMod SHIFT, L, resizeactive, 20 0"

        ] ++ (lib.lists.concatMap (ws: [
            "$mainMod $ctrlMod, ${toString ws}, workspace, ${toString ws}"
            "$mainMod $ctrlMod SHIFT, ${toString ws}, movetoworkspace, ${toString ws}"
          ]) (lib.lists.range 1 9)
        ) ++ [
          "$mainMod $ctrlMod, 0, workspace, 10"
          "$mainMod SHIFT, 0, movetoworkspace, 10"
          # Workspace navigation
          "$ctrlMod $mainMod, right, workspace, e+1"
          "$ctrlMod $mainMod, left, workspace, e-1"
          
          # Move window to next/previous workspace
          "$mainMod SHIFT, right, movetoworkspace, e+1"
          "$mainMod SHIFT, left, movetoworkspace, e-1"

          # System & Utility Bindings
          "$ctrlMod, L, exec, ${pkgs.swaylock}/bin/swaylock" # needs full theme overhaul
          "$mainMod, V, exec, ${pkgs.cliphist}/bin/cliphist list | ${pkgs.wofi}/bin/wofi --dmenu | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy"
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
    # Home Manager Packages for Functional Elements
    # -------------------------------------------------------------------------- #
    home.packages = with pkgs; [
      # Terminals, Launchers, File Managers (if not specified elsewhere and used in binds)
      kitty
      cosmic-files # if you decide to use this
      wofi

      # Core utilities from your original list, if not pulled by services:
      yazi
      btop-rocm
      kdePackages.kate
      kdePackages.konsole # Often a dependency for Kate or other KDE apps
      librewolf
      brave
      discord

      # From Hyprland exec/binds not covered by services:
      (if pkgs ? vscode then vscode else null) # Conditional if package might not exist
      swaylock
      grim
      slurp
      wl-clipboard # For cliphist/wofi integration
      playerctl
      pulseaudio # For pactl

    ] ++ lib.optionals customConfig.desktop.wayvnc.enable [
      wayvnc
    ];
  };
}
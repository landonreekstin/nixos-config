# ~/nixos-config/modules/home-manager/rice/century-series/hyprland.nix
{ config, pkgs, lib, ... }:

let
  # For services.hyprpaper and potentially other uses
  wallpaperDir = config.home.homeDirectory + "/.local/share/wallpapers"; # Robust path
  wallpaperF104 = wallpaperDir + "/f104-retro-future.jpg";
  wallpaperHangar3 = wallpaperDir + "/future-aviation-hanger-3.jpg";
  wallpaperHangar1 = wallpaperDir + "/future-aviation-hanger-1.jpg";
  wallpaperSu47 = wallpaperDir + "/su-47-future.jpg";

  # Monitor descriptions (used in hyprland.settings.monitor)
  monitorDescMainDell = "Dell Inc. DELL S2721HGF DZR2123";
  monitorDescLeftVirt = "Dell Inc. OptiPlex 7760 0x36419E0A";
  monitorDescRightVirt = "Samsung Electric Company S27R65x H4TW800293";
  monitorDescTV = "Hisense Electric Co. Ltd. 4Series43 0x00000278";

in
{
  # -------------------------------------------------------------------------- #
  # Wallpaper File Linking (remains the same)
  # -------------------------------------------------------------------------- #
  home.file.".local/share/wallpapers/future-aviation-hanger-3.jpg".source = ../../../../assets/wallpapers/future-aviation-hanger-3.jpg;
  home.file.".local/share/wallpapers/f104-retro-future.jpg".source = ../../../../assets/wallpapers/f104-retro-future.jpg;
  home.file.".local/share/wallpapers/su-47-future.jpg".source = ../../../../assets/wallpapers/su-47-future.jpg;
  home.file.".local/share/wallpapers/future-aviation-hanger-1.jpg".source = ../../../../assets/wallpapers/future-aviation-hanger-1.jpg;

  # -------------------------------------------------------------------------- #
  # Hyprpaper Service (for setting wallpapers)
  # -------------------------------------------------------------------------- #
  services.hyprpaper = {
    enable = true;
    settings = {
      preload = [ wallpaperF104 wallpaperHangar3 wallpaperHangar1 wallpaperSu47 ];
      wallpaper = [
        "desc:${monitorDescMainDell},${wallpaperHangar3}"  # Example: "DP-1,${wallpaperHangar3}"
        "desc:${monitorDescLeftVirt},${wallpaperF104}" # Example: "HDMI-A-1,${wallpaperF104}"
        "desc:${monitorDescRightVirt},${wallpaperSu47}" # Example: "DP-2,${wallpaperSu47}"
        "desc:${monitorDescTV},${wallpaperHangar1}"     # Example: "HDMI-A-2,${wallpaperHangar1}"
      ];
      ipc = false;    # As per your previous setting
      splash = false; # As per your previous setting
    };
  };

  # -------------------------------------------------------------------------- #
  # Other Services (previously in exec-once)
  # -------------------------------------------------------------------------- #

  services.swaync = {
    enable = true;
    # Add any swaynotificationcenter specific config here if needed via its HM options.
  };

  services.cliphist = {
    enable = true; # This enables `wl-paste --watch cliphist store`
  };

  # -------------------------------------------------------------------------- #
  # Hyprland Configuration using Home Manager Module
  # -------------------------------------------------------------------------- #
  wayland.windowManager.hyprland = {
    enable = true;

    # === IMPORTANT FOR NIXOS USERS ===
    # If you have `programs.hyprland.enable = true;` in your NixOS system
    # configuration (`configuration.nix`), set `package` to `null`.
    # Otherwise, Home Manager will manage the Hyprland package.
    package = null; # or `null` if using NixOS module for hyprland package

    # xwayland.enable = true; # Default is true. Uncomment to explicitly set or change to false.
    # systemd.enable = true; # Default is true, good for session management.
    # systemd.enableXdgAutostart = false; # Default. Set to true if you use XDG autostart for some apps.

    settings = {
      # Variables are typically placed at the top by the module.
      "$mainMod" = "SUPER";
      "$altMod" = "ALT";
      "$ctrlMod" = "CONTROL";
      "$terminal" = "${pkgs.kitty}/bin/kitty";
      "$fileManager" = "${pkgs.cosmic-files}/bin/cosmic-files";
      "$menu" = "${pkgs.wofi}/bin/wofi --show drun";

      # Monitor configuration (using descriptions from your original config)
      # Note: These are for Hyprland's internal monitor setup, distinct from hyprpaper.
      monitor = [
        "desc:${monitorDescMainDell}, 1920x1080@144, 0x0, 1"
        "desc:${monitorDescLeftVirt}, preferred, -1080x-410, 1, transform,1"
        "desc:${monitorDescRightVirt}, preferred, 1920x-390, 1, transform,1"
        "desc:${monitorDescTV}, preferred, 0x-1080, 1"
      ];

      # exec-once: For applications not managed by dedicated Home Manager services.
      "exec-once" = [
        "${pkgs.wayvnc}/bin/wayvnc --output=DP-1 --render-cursor localhost 5900"
      ];

      # Environment variables
      env = [
        "XCURSOR_SIZE,24"
        "QT_QPA_PLATFORMTHEME,qt6ct" # Or "kde" if heavily using KDE integration
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
          natural_scroll = false; # Use boolean true/false
        };
        sensitivity = 0; # float, 0 means no modification
      };

      # General settings
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.inactive_border" = "rgba(808080aa)";
        "col.active_border" = "rgba(DAA520ff)";
        layout = "dwindle";
        allow_tearing = false;
      };

      # Decoration settings
      decoration = {
        rounding = 3;
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
        };
        # drop_shadow = true; # Example if you want to enable
        # shadow_range = 4;
        # shadow_render_power = 3;
        # "col.shadow" = "rgba(1a1a1a99)";
      };

      # Animations settings
      animations = {
        enabled = true; # Use boolean
        # Bezier definition (will be placed near the top by the module)
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        # Animation rules (list of strings)
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };

      # Layout-specific settings
      dwindle = {
        pseudotile = true;     # Use boolean
        preserve_split = true; # Use boolean
      };
      master = {
        # new_is_master = true; # Use boolean
      };

      # Gestures settings
      gestures = {
        workspace_swipe = false; # Use boolean
      };

      # Miscellaneous settings
      misc = {
        force_default_wallpaper = -1; # Or 0 or 1
        disable_hyprland_logo = true; # Use boolean
      };

      # Keybindings (list of strings)
      bind = [
        # Applications
        "$mainMod, SPACE, exec, $menu"             # Uses $menu variable
        "$mainMod, RETURN, exec, $terminal"        # Uses $terminal variable
        "$mainMod, I, exec, ${pkgs.vscodium}/bin/vscodium" # Ensure pkgs.vscodium exists
        "$mainMod, T, exec, ${pkgs.kdePackages.kate}/bin/kate"
        "$mainMod, F, exec, $terminal -e ${pkgs.yazi}/bin/yazi" # Uses $terminal
        "$mainMod SHIFT, F, exec, ${pkgs.cosmic-files}/bin/cosmic-files" # Ensure pkgs.cosmic-files exists
        "$mainMod, B, exec, ${pkgs.librewolf}/bin/librewolf"
        "$mainMod SHIFT, B, exec, ${pkgs.brave}/bin/brave"
        "$mainMod, M, exec, ${pkgs.spotify}/bin/spotify --enable-features=UseOzonePlatform --ozone-platform=wayland"
        "$mainMod, D, exec, ${pkgs.discord}/bin/discord"
        "$mainMod, G, exec, ${pkgs.steam.run}/bin/steam" # Using steam.run for proper environment
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
        "$mainMod, bracketleft, exec, hyprctl keyword general:layout dwindle"
        "$mainMod, bracketright, exec, hyprctl keyword general:layout master"

        # Resize active window
        "$mainMod SHIFT, H, resizeactive, -20 0"
        "$mainMod SHIFT, J, resizeactive, 0 20"
        "$mainMod SHIFT, K, resizeactive, 0 -20"
        "$mainMod SHIFT, L, resizeactive, 20 0"

        # Workspace Management (dynamically generated for 1-9)
      ] ++ (lib.lists.concatMap (ws: [
          "$mainMod $ctrlMod, ${toString ws}, workspace, ${toString ws}"
          "$mainMod $ctrlMod SHIFT, ${toString ws}, movetoworkspace, ${toString ws}"
        ]) (lib.lists.range 1 9)
      ) ++ [ # Appending bindings for workspace 10 and next/prev
        "$mainMod $ctrlMod, 0, workspace, 10"
        "$mainMod $ctrlMod SHIFT, 0, movetoworkspace, 10"
        "$mainMod $ctrlMod, greater, movetoworkspace, e+1"
        "$mainMod $ctrlMod, less, movetoworkspace, e-1"

        # System & Utility Bindings
        "$ctrlMod, L, exec, ${pkgs.swaylock}/bin/swaylock" # Ensure swaylock is in home.packages
        # Cliphist + Wofi example (adjust as needed):
        "$mainMod, V, exec, ${pkgs.cliphist}/bin/cliphist list | ${pkgs.wofi}/bin/wofi --dmenu | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy"
        "$mainMod SHIFT, S, exec, ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" ${config.home.homeDirectory}/Pictures/Screenshots/$(date +'%Y-%m-%d_%H-%M-%S').png" # Ensure grim, slurp in home.packages
        "$mainMod SHIFT, R, exec, hyprctl reload"
        "$mainMod SHIFT, Q, exit,"

        # Media Keys (ensure playerctl and pactl/appropriate audio control are in home.packages)
        # You might need to use `pkgs.pulseaudio}/bin/pactl` or `${pkgs.pipewire}/bin/pactl` depending on your audio setup.
        # `pkgs.pactl` might be available directly if your system provides it.
        ", XF86AudioPlay, exec, ${pkgs.playerctl}/bin/playerctl --player=spotify play-pause"
        ", XF86AudioNext, exec, ${pkgs.playerctl}/bin/playerctl --player=spotify next"
        ", XF86AudioPrev, exec, ${pkgs.playerctl}/bin/playerctl --player=spotify previous"
        ", XF86AudioMute, exec, ${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle"
        ", XF86AudioLowerVolume, exec, ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -5%"
        ", XF86AudioRaiseVolume, exec, ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +5%"
      ];

      # Mouse bindings (list of strings)
      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];

      # Window rules (list of strings, example from your original config)
      # windowrulev2 = [
      #   "float,class:^(kitty)$,title:^(kitty)$"
      #   # Add other rules here
      # ];
    }; # End of wayland.windowManager.hyprland.settings

    # Use `extraConfig` for any raw Hyprland config lines that are difficult
    # or impossible to express in the structured `settings` above.
    # extraConfig = ''
    #   # Example: source = ~/.config/hypr/my_extra_settings.conf
    # '';

  }; # End of wayland.windowManager.hyprland

  # -------------------------------------------------------------------------- #
  # Home Manager Packages
  # -------------------------------------------------------------------------- #
  # List packages used in binds/execs if not handled by a service,
  # or not automatically detected and pulled in by the hyprland module.
  # Many packages like kitty, wofi, etc., referenced as ${pkgs...} in settings
  # should be automatically included by the Hyprland module.
  # This list is for explicit dependencies or general tools.
  home.packages = with pkgs; [
    # Core utilities from your original list, if not pulled by services:
    yazi                 # For $terminal -e yazi
    kdePackages.kate     # For editor binding
    kdePackages.konsole  # Used by Kate
    librewolf
    brave
    spotify
    discord

    # From Hyprland exec/binds not covered by services:
    wayvnc
    (if pkgs ? vscodium then vscodium else null) # Check if pkgs.vscodium exists
    (if pkgs ? cosmic-files then cosmic-files else null) # Check if pkgs.cosmic-files exists
    swaylock
    grim
    slurp
    playerctl
    pulseaudio

  ];

}

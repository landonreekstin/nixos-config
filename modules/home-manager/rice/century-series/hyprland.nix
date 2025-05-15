# ~/nixos-config/modules/home-manager/rice/century-series/hyprland.nix
{ config, pkgs, lib, ... }:

{
  # Manage hyprland.conf via home-manager
  # Ref: https://wiki.hyprland.org/Configuring/Configuring-Hyprland/
  # Ref: https://nix-community.github.io/home-manager/options.html#opt-xdg.configFile
  
  # Link wallpaper file into home directory
  home.file.".local/share/wallpapers/soviet-retro-future.jpg" = {
     source = ../../../../assets/wallpapers/soviet-retro-future.jpg;
     recursive = true; # Ensure directory exists
  };
  home.file.".local/share/wallpapers/f104-retro-future.jpg" = {
     source = ../../../../assets/wallpapers/f104-retro-future.jpg;
     recursive = true;
  };

  xdg.configFile."hypr/hyprland.conf" = {
    # Ensure directory ~/.config/hypr exists
    recursive = true;
    # Use nix multiline string to define the content
    text = ''
      # See https://wiki.hyprland.org/Configuring/Monitors/
      # Configure your monitor. Use 'hyprctl monitors' in a running session to get names.
      # Configure monitors: Define settings for BOTH possible identifier pairs
      # Pair 1
      # Vertical Left (HDMI-A-3), Normal Right (HDMI-A-1)
      monitor=HDMI-A-3,1920x1080,0x0,1,transform,1   # Left monitor, rotated 90deg clockwise
      monitor=HDMI-A-1,preferred,1080x0,1            # Right monitor, starting after rotated width of HDMI-A-3

      # Pair 2
      monitor=HDMI-A-4,1920x1080,0x0,1,transform,1
      monitor=HDMI-A-2,preferred,1080x0,1
      # Example for second monitor: monitor=HDMI-A-1,preferred,auto,1,mirror,DP-1
      # Example for vertical monitor: monitor=DP-1,preferred,auto,1,transform,1 # 1=90deg clockwise

      # See https://wiki.hyprland.org/Configuring/Keywords/ for more

      # Execute your favorite apps at launch
      # exec-once = waybar & swaybg -i ~/path/to/wallpaper.png & swaync
      # NOTE: We will configure these properly later via their own modules/options
      exec-once = ${pkgs.swaynotificationcenter}/bin/swaync & # Start notification daemon
      exec-once = ${pkgs.waybar}/bin/waybar # Start Waybar (configure first)
      exec-once = ${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store # Start clipboard manager
      exec-once = ${pkgs.hyprpaper}/bin/hyprpaper & # Set wallpaper using swaybg and the linked path
      exec-once = ${pkgs.wayvnc}/bin/wayvnc --output=HDMI-A-3 --render-cursor localhost 5900

      # Source a file for colors allows easy overriding later
      # source = ~/.config/hypr/themes/theme.conf # We can manage themes later

      # Set programs that you use
      $terminal = ${pkgs.kitty}/bin/kitty # Use kitty package from Nix store path
      $fileManager = ${pkgs.kdePackages.dolphin}/bin/dolphin # Assuming Dolphin is installed system-wide
      $menu = ${pkgs.wofi}/bin/wofi --show drun # Use wofi package path

      # Some default env vars.
      env = XCURSOR_SIZE,24
      env = QT_QPA_PLATFORMTHEME,qt6ct # Or "kde" if using KDE integration heavily

      # For all categories, see https://wiki.hyprland.org/Configuring/Variables/
      input {
          kb_layout = us
          kb_variant =
          kb_model =
          kb_options =
          kb_rules =

          follow_mouse = 1

          touchpad {
              natural_scroll = no
          }

          sensitivity = 0 # -1.0 - 1.0, 0 means no modification.
      }

      general {
          # See https://wiki.hyprland.org/Configuring/Variables/ for more

          gaps_in = 5
          gaps_out = 10
          border_size = 2

          # ==> Define Colors using RGBA Hex <==
          # Base Tones
          col.inactive_border = rgba(808080aa) # Medium Grey, semi-transparent AA alpha
          # col.main_background = rgba(1A1A1AFF) # Near Black, fully opaque (optional, usually set by wallpaper)

          # Accents
          col.active_border = rgba(DAA520ff) # Gradient: Ochre, fully opaque

          # Groups / Tabs (Examples, adjust based on Hyprland group features if used)
          # col.group_border = rgba(5F9EA0ff) # Teal group border
          # col.group_border_active = rgba(FFBF00ff) # Amber active group border


          layout = dwindle # master or dwindle

          # Please see https://wiki.hyprland.org/Configuring/Tearing/ before enabling
          allow_tearing = false
      }

      decoration {
          # See https://wiki.hyprland.org/Configuring/Variables/ for more

          rounding = 3

          # Opacity (can make terminals/windows slightly transparent)
          # active_opacity = 0.95
          # inactive_opacity = 0.85

          blur {
              enabled = true
              size = 3
              passes = 1
          }

          drop_shadow = yes
          shadow_range = 4
          shadow_render_power = 3
          col.shadow = rgba(1a1a1a99)
      }

      animations {
          enabled = yes

          # Some default animations, see https://wiki.hyprland.org/Configuring/Animations/ for more

          bezier = myBezier, 0.05, 0.9, 0.1, 1.05

          animation = windows, 1, 7, myBezier
          animation = windowsOut, 1, 7, default, popin 80%
          animation = border, 1, 10, default
          animation = borderangle, 1, 8, default
          animation = fade, 1, 7, default
          animation = workspaces, 1, 6, default
      }

      dwindle {
          # See https://wiki.hyprland.org/Configuring/Dwindle-Layout/ for more
          pseudotile = yes # master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
          preserve_split = yes # you probably want this
      }

      master {
          # See https://wiki.hyprland.org/Configuring/Master-Layout/ for more
          new_is_master = true
      }

      gestures {
          # See https://wiki.hyprland.org/Configuring/Variables/ for more
          workspace_swipe = off
      }

      misc {
          # See https://wiki.hyprland.org/Configuring/Variables/ for more
          force_default_wallpaper = -1 # Set to 0 or 1 to disable the anime mascot wallpapers
          disable_hyprland_logo = true
      }

      # Example windowrule v1
      # windowrule = float, ^(kitty)$
      # Example windowrule v2
      # windowrulev2 = float,class:^(kitty)$,title:^(kitty)$
      # See https://wiki.hyprland.org/Configuring/Window-Rules/ for more


      # See https://wiki.hyprland.org/Configuring/Keywords/ for more
      $mainMod = SUPER # Sets "Windows" key as main modifier

      # Example binds, see https://wiki.hyprland.org/Configuring/Binds/ for more
      bind = $mainMod, Q, exec, $terminal
      bind = $mainMod, C, killactive,
      bind = $mainMod, M, exit, # WARNING: This exits Hyprland, use wlogout later
      bind = $mainMod, E, exec, $fileManager
      bind = $mainMod, V, togglefloating,
      bind = $mainMod, R, exec, $menu
      bind = $mainMod, P, pseudo, # dwindle
      bind = $mainMod, J, togglesplit, # dwindle

      # Move focus with mainMod + arrow keys
      bind = $mainMod, left, movefocus, l
      bind = $mainMod, right, movefocus, r
      bind = $mainMod, up, movefocus, u
      bind = $mainMod, down, movefocus, d

      # Switch workspaces with mainMod + [0-9]
      bind = $mainMod, 1, workspace, 1
      bind = $mainMod, 2, workspace, 2
      bind = $mainMod, 3, workspace, 3
      bind = $mainMod, 4, workspace, 4
      bind = $mainMod, 5, workspace, 5
      bind = $mainMod, 6, workspace, 6
      bind = $mainMod, 7, workspace, 7
      bind = $mainMod, 8, workspace, 8
      bind = $mainMod, 9, workspace, 9
      bind = $mainMod, 0, workspace, 10

      # Move active window to a workspace with mainMod + SHIFT + [0-9]
      bind = $mainMod SHIFT, 1, movetoworkspace, 1
      bind = $mainMod SHIFT, 2, movetoworkspace, 2
      bind = $mainMod SHIFT, 3, movetoworkspace, 3
      bind = $mainMod SHIFT, 4, movetoworkspace, 4
      bind = $mainMod SHIFT, 5, movetoworkspace, 5
      bind = $mainMod SHIFT, 6, movetoworkspace, 6
      bind = $mainMod SHIFT, 7, movetoworkspace, 7
      bind = $mainMod SHIFT, 8, movetoworkspace, 8
      bind = $mainMod SHIFT, 9, movetoworkspace, 9
      bind = $mainMod SHIFT, 0, movetoworkspace, 10

      # Example special workspace (scratchpad)
      # bind = $mainMod SHIFT, S, movetoworkspace, special
      # bind = $mainMod, S, togglespecialworkspace,

      # Scroll through existing workspaces with mainMod + scroll
      bind = $mainMod, mouse_down, workspace, e+1
      bind = $mainMod, mouse_up, workspace, e-1

      # Move/resize windows with mainMod + LMB/RMB and dragging
      bindm = $mainMod, mouse:272, movewindow
      bindm = $mainMod, mouse:273, resizewindow
    ''; # End of hyprland.conf text
  }; # End xdg.configFile


  xdg.configFile."hypr/hyprpaper.conf" = {
    recursive = true;
    text = ''
      # Preload images for efficiency
      preload = ${config.home.homeDirectory}/.local/share/wallpapers/soviet-retro-future.jpg
      preload = ${config.home.homeDirectory}/.local/share/wallpapers/f104-retro-future.jpg

      # Assign wallpapers to monitors (handling dual identifiers)
      # Main Monitor (Horizontal - HDMI-A-1 or HDMI-A-2)
      wallpaper = HDMI-A-1,${config.home.homeDirectory}/.local/share/wallpapers/soviet-retro-future.jpg
      wallpaper = HDMI-A-2,${config.home.homeDirectory}/.local/share/wallpapers/soviet-retro-future.jpg

      # Vertical Monitor (HDMI-A-3 or HDMI-A-4)
      wallpaper = HDMI-A-3,${config.home.homeDirectory}/.local/share/wallpapers/f104-retro-future.jpg
      wallpaper = HDMI-A-4,${config.home.homeDirectory}/.local/share/wallpapers/f104-retro-future.jpg

      # Optional Fallback for any other monitors
      # wallpaper = ,${config.home.homeDirectory}/.local/share/wallpapers/soviet-retro-future.jpg

      # General settings
      ipc = off
      splash = false
    '';
  }; # End xdg.configFile."hypr/hyprpaper.conf"


  # Ensure necessary packages for the config are installed via HM
  home.packages = with pkgs; [
    # Packages referenced in hyprland.conf ($terminal, $menu, etc.)
    # Many are already in the system Hyprland profile module,
    # but adding here ensures they are available if HM is used independently.
    kitty
    # dolphin # Already installed system-wide via kdePackages.plasma-workspace
    wofi
    wl-clipboard
    cliphist
    swaynotificationcenter
    waybar
    hyprpaper
    dbus
    wayvnc
  ];
  
}
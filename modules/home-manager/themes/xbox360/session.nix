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

  c = import ./colors.nix { };
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
      gaps_out = 28;
      border_size = 2;
      # Games (green) is the neutral default; each blade recolours its own
      # windows through the per-workspace rules below.
      "col.active_border" = bladeBorder "games";
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

    # Each of the first five workspaces is a blade and wears its colour.
    windowrule = lib.imap1 (i: name:
      "border_color ${bladeBorder name}, match:workspace ${toString i}"
    ) c.order;
  };

  # Startup and session-only lines, appended after the functional extraConfig.
  extraConfig = ''

    # ---- xbox360 rice ----
    env = HYPR_RICE,xbox360
    ${lib.optionalString (customConfig.desktop.hyprland.wallpaperEngine == "awww") ''
      # Until the blades shell lands, the backdrop is the Games blade's deep stop.
      exec-once = sleep 1 && ${pkgs.awww}/bin/awww clear ${lib.elemAt c.blades.games.stops 3}
    ''}
    exec-once = ${pkgs.pipewire}/bin/pw-play ${assets}/share/sounds/xbox360/select-a.wav
  '';

  xboxConf =
    lib.hm.generators.toHyprconf {
      attrs = mergeWith hyprOpts.settings settings;
      importantPrefixes = config.wayland.windowManager.hyprland.importantPrefixes;
    }
    + mergeWith hyprOpts.extraConfig extraConfig;
in
{
  config = lib.mkIf enabled {
    home.packages = [ assets ];
    fonts.fontconfig.enable = true;

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

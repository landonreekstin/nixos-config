# ~/nixos-config/modules/nixos/desktop/options.nix
{ lib, ... }:

# Desktop options that no single module owns: the cross-cutting switches every
# desktop module selects on (enable, environments) and the blocks read only by
# home-manager (monitors, autostart, idle, wayvnc), which cannot declare them
# because it receives customConfig as a plain attrset via extraSpecialArgs.
# Per-DE options live with their module: desktop/kde.nix, hyprland.nix,
# xrdp.nix, display-manager.nix.
{
  options.customConfig.desktop = with lib; {
    enable = mkOption {
        type = types.bool;
        default = true; # Usually true if a graphical environment is selected, can be overridden
        # Consider defaulting based on desktop.environment != "none"
        # default = (config.customConfig.desktop.environment != "none");
        description = "Whether to enable a desktop environment.";
      };
    environments = mkOption {
      type = types.listOf (types.enum [ "hyprland" "cosmic" "kde" "xfce" "none" ]);
      default = []; # Default to an empty list
      example = [ "kde" "hyprland" ];
      description = "A list of desktop environments or window managers to make available on the system.";
    };
    monitors = mkOption {
      type = with types; listOf (submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "A descriptive name for this monitor configuration.";
            example = "main";
          };
          identifier = mkOption {
            type = types.str;
            description = "The monitor identifier. Can be a manufacturer description (desc:...) or output name (DP-1, HDMI-A-1, etc.).";
            example = "Dell Inc. DELL S2721HGF DZR2123";
          };
          edid = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Optional EDID description substring (make / model / serial) used ONLY by the
              XFCE X11 monitor resolver to identify this monitor stably regardless of
              connector-name reordering. Hyprland ignores this and matches on `identifier`.
              Needed because X11 (NVIDIA) and Wayland report DIFFERENT connector names for
              the same physical port (e.g. an output that is DP-1 under Wayland is DP-0 under
              X11), so a shared connector name can't drive both sessions. When null, the XFCE
              resolver falls back to `identifier`.
            '';
            example = "LG ULTRAGEAR";
          };
          wallpaper = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              Optional per-monitor wallpaper image. Used by the XFCE windows7 wallpaper script
              to override this monitor's orientation default (portrait → vertical image,
              landscape → Win7 image) — e.g. to mirror the per-monitor wallpapers the Hyprland
              theme shows on the same host. null = use the orientation default.
            '';
            example = literalExpression "../../assets/wallpapers/f-15-satellite.jpg";
          };
          resolution = mkOption {
            type = types.str;
            default = "preferred";
            description = "Monitor resolution and refresh rate.";
            example = "1920x1080@144";
          };
          position = mkOption {
            type = types.str;
            default = "0x0";
            description = "Monitor position in pixels (x,y).";
            example = "1920x0";
          };
          scale = mkOption {
            type = types.str;
            default = "1";
            description = "Monitor scaling factor.";
            example = "1.5";
          };
          transform = mkOption {
            type = types.nullOr (types.enum [ "0" "1" "2" "3" ]);
            default = null;
            description = "Monitor rotation: 0=normal, 1=90°, 2=180°, 3=270°.";
          };
          enabled = mkOption {
            type = types.bool;
            default = true;
            description = "Whether this monitor configuration is enabled.";
          };
        };
      });
      default = [];
      description = "List of monitor configurations for Hyprland.";
      example = literalExpression ''
        [
          {
            name = "main";
            identifier = "Dell Inc. DELL S2721HGF DZR2123";
            resolution = "1920x1080@144";
            position = "0x0";
            scale = "1";
          }
          {
            name = "secondary";
            identifier = "DP-2";
            resolution = "1920x1080@60";
            position = "1920x0";
            scale = "1";
          }
        ]
      '';
    };
    autostart = mkOption {
      type = types.listOf (types.submodule {
        options = {
          command = mkOption {
            type = types.str;
            description = "Command to run on startup.";
            example = "discord";
          };
          desktops = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Desktop environments to autostart on. Empty list means all enabled DEs.";
            example = [ "hyprland" "kde" ];
          };
          workspace = mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Hyprland workspace number to open the app on silently. Null means no preference.";
            example = 2;
          };
          windowClass = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Hyprland window class for workspace assignment via windowrulev2 (more reliable than exec-once prefix for XWayland apps). Use hyprctl clients to find the class.";
            example = "discord";
          };
        };
      });
      default = [];
      description = ''
        Applications to autostart at login. Each entry specifies a command and
        optionally which desktop environments should start it. An empty `desktops`
        list means start on all enabled DEs.
      '';
    };
    idle = {
      screensaverTimeout = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = ''
          Seconds of idle before the screensaver activates (AC power). Currently consumed
          by XFCE (xfce4-screensaver); locking then follows at idle.lockTimeout. Null =
          no separate screensaver stage (saver == lock).
        '';
        example = 900;
      };
      lockTimeout = mkOption {
        type = types.nullOr types.int;
        default = 600;
        description = "Seconds of idle before the screen locks (AC power). Set to null to disable auto-lock.";
        example = 900;
      };
      sleepTimeout = mkOption {
        type = types.nullOr types.int;
        default = 1800;
        description = "Seconds of idle before the display turns off (AC power). Set to null to disable.";
        example = 3600;
      };
      battery = {
        lockTimeout = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Seconds of idle before the screen locks on battery. Null falls back to idle.lockTimeout.";
          example = 600;
        };
        sleepTimeout = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Seconds of idle before the display turns off on battery. Null falls back to idle.sleepTimeout.";
          example = 900;
        };
      };
    };
    wayvnc = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable wayvnc VNC server for Hyprland.";
      };
      targetMonitor = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Name of the monitor to use for wayvnc. Corresponds to monitor.name in desktop.monitors.";
        example = "tv";
      };
    };
  };
}

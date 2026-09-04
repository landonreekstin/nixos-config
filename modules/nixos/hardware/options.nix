# ~/nixos-config/modules/nixos/hardware/options.nix
{ lib, ... }:

# Hardware options that no single module owns. nvidia and peripherals are
# declared by the modules implementing them; what stays here is either read
# only by home-manager (display, kbdBacklight, battery, bluetooth, touchpad —
# all waybar/input consumers) or shared, like monitors, which desktop and
# home-manager both read.
{
  options.customConfig.hardware = with lib; {
    unstable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to source the entire hardware stack (kernel, initrd modules, etc.) from nixpkgs-unstable.";
    };

    monitors = mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Output connector name (e.g., DP-1, HDMI-A-1). Must match the kernel connector name.";
            example = "DP-4";
          };
          width = mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Horizontal resolution in pixels. null = preferred mode.";
          };
          height = mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Vertical resolution in pixels. null = preferred mode.";
          };
          refreshRate = mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Refresh rate in Hz. null = preferred mode.";
          };
          x = mkOption {
            type = types.int;
            default = 0;
            description = "Horizontal position in the virtual display space (pixels from left).";
          };
          y = mkOption {
            type = types.int;
            default = 0;
            description = "Vertical position in the virtual display space (pixels from top).";
          };
          rotation = mkOption {
            type = types.enum [ "Normal" "Rotated90" "Rotated180" "Rotated270" ];
            default = "Normal";
            description = "Display rotation. Rotated90 = 90° clockwise (use for portrait monitors physically rotated CCW).";
          };
          scale = mkOption {
            type = types.float;
            default = 1.0;
            description = "Display scale factor (e.g., 1.25 for 125% scaling).";
          };
          enabled = mkOption {
            type = types.bool;
            default = true;
            description = "Whether this output is active.";
          };
        };
      });
      default = [];
      description = ''
        Declarative monitor configuration. Currently used by SDDM (KWin) for rotation and scale.
        Hyprland and KDE support will be added in future tasks.
        Connector names can be found via: cat ~/.config/kwinoutputconfig.json
      '';
    };
    display = {
      backlight = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable screen backlight control (brightnessctl). Shows brightness widget in Waybar.";
        };
      };
    };
    kbdBacklight = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable keyboard backlight control via brightnessctl. Shows kbd brightness widget in Waybar.";
      };
    };
    battery = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable battery status widget in Waybar. Enable for laptops with a battery.";
      };
    };
    bluetooth = {
      waybar = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Show Bluetooth status widget in Waybar. Enable for hosts that use Bluetooth devices.";
        };
      };
    };
    wifi = {
      waybar = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Show the WiFi status widget in Waybar (Hyprland). Click opens a rofi network picker, right-click opens nmtui. Enable for hosts with a usable wireless adapter.";
        };
      };
    };
    touchpad = {
      naturalScroll = mkOption {
        type = types.bool;
        default = true;
        description = "Enable natural (macOS-style) scrolling for touchpad. Content follows finger direction. Applied to Hyprland and KDE.";
      };
    };
  };
}

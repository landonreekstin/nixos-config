# ~/nixos-config/modules/nixos/desktop/hyprland.nix
{ config, pkgs, lib, ... }:

{
  options.customConfig.desktop.hyprland = with lib; {
    launcher = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable the Hyprland launcher bar (typically at bottom center).";
      };
      pinnedApps = mkOption {
        type = with types; listOf (submodule {
          options = {
            label = mkOption {
              type = types.str;
              description = "Display label for the launcher button (e.g., 'TERM', 'NAV', 'CODE').";
              example = "TERM";
            };
            command = mkOption {
              type = types.str;
              description = "Command to execute when the launcher button is clicked.";
              example = "\${pkgs.kitty}/bin/kitty";
            };
            tooltip = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Optional tooltip text for the launcher button.";
              example = "Launch Terminal";
            };
          };
        });
        default = [];
        description = "List of pinned applications for the launcher bar.";
        example = literalExpression ''
          [
            {
              label = "TERM";
              command = "\${pkgs.kitty}/bin/kitty";
              tooltip = "Terminal";
            }
            {
              label = "FILES";
              command = "\${pkgs.cosmic-files}/bin/cosmic-files";
              tooltip = "File Manager";
            }
          ]
        '';
      };
    };
    drmDevice = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Explicit DRM device path for Hyprland (AQ_DRM_DEVICES). Set this on hosts with
        multiple GPUs (e.g. NVIDIA + AMD iGPU) to pin Hyprland to the correct card.
        Use the stable by-path link: /dev/dri/by-path/pci-<BBBB:DD:FF.f>-card.
        Find your GPU PCI address with: ls -la /dev/dri/by-path/
      '';
      example = "/dev/dri/by-path/pci-0000:01:00.0-card";
    };

    utilityApps = mkOption {
      type = types.listOf (types.submodule {
        options = {
          command = mkOption {
            type = types.str;
            description = "Command to launch the app.";
            example = "ckb-next";
          };
          windowClass = mkOption {
            type = types.str;
            description = "Hyprland window class for the window rule (use hyprctl clients to find).";
            example = "ckb-next";
          };
        };
      });
      default = [];
      description = ''
        Applications to autostart silently into the special utility workspace (special:ckb).
        A windowrulev2 sends each app there on launch; SUPER+` toggles the workspace.
      '';
    };
    weather = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to show a weather widget in the waybar.";
      };
      location = mkOption {
        type = types.str;
        default = "";
        description = "Location for weather lookup (e.g. 'Austin' or 'New York'). Empty string auto-detects by IP.";
        example = "Austin, TX";
      };
      useFahrenheit = mkOption {
        type = types.bool;
        default = true;
        description = "Show temperature in Fahrenheit. Set false for Celsius.";
      };
    };
    audioSinkMappings = mkOption {
      type = types.listOf (types.submodule {
        options = {
          match = mkOption {
            type = types.str;
            description = "Substring to match against the sink description (as shown in pavucontrol Output Devices tab).";
          };
          icon = mkOption {
            type = types.str;
            description = "Nerd Font glyph for this device type (e.g. speaker 󰕾 U+F057E, headphones 󰋋 U+F040B).";
          };
          class = mkOption {
            type = types.str;
            default = "default";
            description = "CSS class applied to the waybar widget when this sink is active (e.g. speakers, headphones).";
          };
          label = mkOption {
            type = types.str;
            default = "";
            description = "Short text label shown alongside the sink name in the rofi sink-switcher menu.";
          };
        };
      });
      default = [];
      description = ''
        Map audio sink description substrings to Nerd Font icons for the waybar audio indicator
        and the rofi sink-switcher menu. Useful on hosts where HDMI audio outputs are ambiguous
        (e.g. an HDMI port feeding a monitor whose audio-out jack connects to headphones).
        Patterns are matched as substrings against the sink description from pactl.
      '';
      example = [
        { match = "Pro 7"; icon = "󰕾"; class = "speakers"; label = "SPKR"; }
        { match = "Pro 8"; icon = "󰋋"; class = "headphones"; label = "HDPH"; }
      ];
    };
  };

  # ==> Configuration (Applied only if profile is enabled) <==
  config = lib.mkIf (lib.elem "hyprland" config.customConfig.desktop.environments) {

    # Enable Hyprland Wayland compositor
    programs.hyprland = {
      enable = true;
      # Use NVIDIA patches if nvidia profile is also enabled
      # Note: This relies on the nvidia module setting hardware.nvidia.modesetting.enable = true;

      # We can add package overrides or extra settings here later if needed
      # package = pkgs.hyprland;
    };

    # Enable XWayland for running X11 apps
    programs.xwayland.enable = true;

    # Install essential Wayland tools and recommended packages for Hyprland
    environment.systemPackages = with pkgs; [
      wayland # Core Wayland libraries
      # wayland-protocols # Included by wayland usually
      wayland-utils     # Tools like wayland-info
      libva             # Hardware video acceleration
      libva-utils

      # Basic utilities often needed
      wl-clipboard      # Wayland clipboard tool
      cliphist          # Clipboard history manager (integrates with wl-clipboard)
      wlogout           # Logout menu often used with WMs
      wlr-randr         # Command-line tool for Wayland display config (like xrandr)
      grim              # Screenshot tool for Wayland
      slurp             # Screen region selection tool (works with grim)
      swaynotificationcenter # Notification daemon (or mako)
      hyprsunset        # Night light adjustment (uses Hyprland CTM, works on NVIDIA)
      # mako            # Alternative notification daemon

      # Need a Wayland-compatible screen locker
      swaylock          # Common screen locker
      # swayidle        # Daemon to trigger locker on idle (configure later)

      # Need a Wayland-compatible status bar
      waybar            # Popular status bar
      # eww             # Alternative widget/bar system

      # Need an application launcher
      wofi              # Popular Wayland launcher (like rofi/dmenu)
      # rofi-wayland    # Rofi fork with Wayland support

      # Recommended font packages
      noto-fonts        # Good general coverage
      noto-fonts-cjk-sans    # For East Asian characters
      noto-fonts-color-emoji  # For emoji
      # Add Nerd Fonts here if not handled by Home Manager rice later
      # (pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
      font-awesome      # Often used for icons in bars/widgets
    ];

    # Ensure PipeWire is handling audio (already done by pipewire.nix module)

    # Set environment variables necessary for Wayland sessions
    # Some might be set automatically by display managers or hyprland itself
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1"; # Hint for Electron apps (like VSCode) to use Wayland
      WLR_NO_HARDWARE_CURSORS = "1"; # Often needed for Nvidia proprietary drivers
      # XDG_SESSION_TYPE = "wayland"; # Should be set automatically
      # XDG_CURRENT_DESKTOP = "Hyprland"; # Should be set automatically
    };

    # Basic security setup for polkit (authentication prompts)
    security.polkit.enable = true;

    # NOTE: Display Manager configuration needs attention.
    # Hyprland doesn't come with one. cosmic-greeter might not offer
    # a Hyprland session. SDDM is often used.
    # We might need to adjust profiles.desktop.displayManager later.

  };
}

# ~/nixos-config/modules/nixos/desktop/hyprland.nix
{ config, pkgs, lib, ... }:

{
  # ==> Configuration (Applied only if profile is enabled) <==
  config = lib.mkIf config.customConfig.programs.hyprland.enable {

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
      noto-fonts-emoji  # For emoji
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

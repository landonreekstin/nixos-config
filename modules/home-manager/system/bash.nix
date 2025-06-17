# ~/nixos-config/modules/home-manager/system/bash.nix
{ config, lib, pkgs, ... }: # This 'config' is the NixOS system config.
                            # customConfig should be an attribute on it if flake.nix is correct.
{
  # The 'programs.bash' attribute set itself is made conditional.
  # This is the correct way to do it.
  programs.bash = lib.mkIf (config.hmCustomConfig.user.shell == pkgs.bash) {
    enable = true; # Explicitly manage bash config files

    shellAliases = {
      c = "clear";
    };

    # This condition checks if Home Manager's Hyprland module is enabled
    profileExtra = lib.mkIf (config.programs.hyprland.enable or false) ''
      # Start Hyprland automatically on TTY1 if not already in a graphical session
      if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
        echo "Attempting to start Hyprland from profileExtra on TTY1..."
        exec ${pkgs.hyprland}/bin/Hyprland
      fi
    ''; # End profileExtra
  }; # End of lib.mkIf for programs.bash
}
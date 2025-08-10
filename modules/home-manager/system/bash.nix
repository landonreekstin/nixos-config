# ~/nixos-config/modules/home-manager/system/bash.nix
{ config, lib, pkgs, customConfig, ... }:

let

  colorMap = {
    "black"   = "0;30";
    "red"     = "0;31";
    "green"   = "0;32"; # This is now dark green
    "yellow"  = "0;33";
    "blue"    = "0;34";
    "magenta" = "0;35";
    "cyan"    = "0;36";
    "white"   = "0;37";

    "bright-black"   = "1;30"; # Often gray
    "bright-red"     = "1;31";
    "bright-green"   = "1;32";
    "bright-yellow"  = "1;33";
    "bright-blue"    = "1;34";
    "bright-magenta" = "1;35";
    "bright-cyan"    = "1;36";
    "bright-white"   = "1;37";
  };

  # Look up the color code from the map using the string from your config
  bashColor = colorMap.${customConfig.user.shell.bash.color};
in
{
  # The 'programs.bash' attribute set itself is made conditional.
  # This is the correct way to do it.
  programs.bash = lib.mkIf (customConfig.user.shell.bash.enable) {
    enable = true; # Explicitly manage bash config files

    shellAliases = {
      c = "clear";
    };

    bashrcExtra = ''
      export PS1="\n\[\033[${bashColor}m\][\[\e]0;\u@\h: \w\a\]\u@\h:\w]\$\[\033[0m\]"
    '';

    # This condition checks if Home Manager's Hyprland module is enabled
    profileExtra = lib.mkIf (customConfig.desktop.environment == "hyprland") ''
      # Start Hyprland automatically on TTY1 if not already in a graphical session
      if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
        echo "Attempting to start Hyprland from profileExtra on TTY1..."
        exec ${pkgs.hyprland}/bin/Hyprland
      fi
    ''; # End profileExtra
  }; # End of lib.mkIf for programs.bash

  # === Enable direnv ===
  programs.direnv = {
    enable = true;
    # This is the crucial part that integrates direnv with Nix Flakes
    nix-direnv.enable = true;
  };
  
}
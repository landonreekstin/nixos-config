# ~/nixos-config/hosts/vm-blaney/desktop.nix
{ config, pkgs, lib, ... }:

{
  customConfig.desktop = {
    environments = [ "kde" "hyprland" "xfce" ];
    hyprland = {
      launcher = {
        enable = true;
        pinnedApps = [
          { label = "TERM"; command = config.customConfig.apps.programs.terminal.command; tooltip = "Terminal Emulator"; }
          { label = "NAV";  command = config.customConfig.apps.programs.browser.command; tooltip = "Web Browser"; }
          { label = "CODE"; command = config.customConfig.apps.programs.ide.command; tooltip = "IDE"; }
        ];
      };
    };
    displayManager = {
      enable = true;
      type = "ly";        # faithful to blaney; log in manually with initialPassword
      ly.theme = "century-series";
      # animationFile / ttyRows / ttyCols dropped — VM framebuffer geometry differs.
    };
  };
}

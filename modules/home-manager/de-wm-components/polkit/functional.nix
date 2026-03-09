# ~/nixos-config/modules/home-manager/de-wm-components/polkit/functional.nix
{ config, pkgs, lib, customConfig, ... }:

let
  isDesktopEnabled = customConfig.desktop.enable;
in
{
  config = lib.mkIf isDesktopEnabled {
    # Enable polkit agent service
    systemd.user.services.polkit-gnome-authentication-agent = {
      Unit = {
        Description = "GNOME Polkit Authentication Agent";
        Wants = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        ConditionEnvironment = [ "WAYLAND_DISPLAY" "XDG_CURRENT_DESKTOP" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };

    # Add polkit agent to home packages
    home.packages = with pkgs; [
      polkit_gnome
    ];
  };
}
# ~/nixos-config/modules/home-manager/services/swayidle.nix
{ config, lib, customConfig, ... }:

let
  isHyprland = lib.elem "hyprland" customConfig.desktop.environments;
  idleCfg = customConfig.desktop.idle;
  # Reference the configured swaylock package (may be swaylock-effects from theme)
  swaylockCmd = "${config.programs.swaylock.package}/bin/swaylock -f";
in
{
  services.swayidle = lib.mkIf (isHyprland && (idleCfg.lockTimeout != null || idleCfg.sleepTimeout != null)) {
    enable = true;
    timeouts =
      lib.optional (idleCfg.lockTimeout != null) {
        timeout = idleCfg.lockTimeout;
        command = swaylockCmd;
      }
      ++ lib.optional (idleCfg.sleepTimeout != null) {
        timeout = idleCfg.sleepTimeout;
        command = "systemctl suspend";
      };
    events = [
      { event = "before-sleep"; command = swaylockCmd; }
      { event = "lock"; command = swaylockCmd; }
    ];
  };
}

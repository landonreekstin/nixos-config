# ~/nixos-config/modules/home-manager/services/swayidle.nix
{ config, lib, customConfig, ... }:

let
  isHyprland = lib.elem "hyprland" customConfig.desktop.environments;
  idleCfg = customConfig.desktop.idle;
  # Reference the configured swaylock package (may be swaylock-effects from theme)
  swaylockCmd = "${config.programs.swaylock.package}/bin/swaylock";
in
{
  # On Hyprland with systemd.enable=false, WAYLAND_DISPLAY isn't in the systemd environment
  # at boot. After hyprland/functional.nix imports it via dbus-update-activation-environment,
  # we explicitly start the service so the ConditionEnvironment check passes.
  wayland.windowManager.hyprland.extraConfig = lib.mkIf (isHyprland && (idleCfg.lockTimeout != null || idleCfg.sleepTimeout != null)) ''
    exec-once = systemctl --user start swayidle
  '';

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

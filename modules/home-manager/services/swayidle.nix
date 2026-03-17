# ~/nixos-config/modules/home-manager/services/swayidle.nix
{ config, pkgs, lib, customConfig, ... }:

let
  isHyprland = lib.elem "hyprland" customConfig.desktop.environments;
  idleCfg = customConfig.desktop.idle;
  # Reference the configured swaylock package (may be swaylock-effects from theme).
  # Run in background (&) so swayidle's -w flag doesn't block it from firing
  # subsequent timeouts (e.g. dpms off) or resume commands while lock is active.
  swaylockCmd = "${config.programs.swaylock.package}/bin/swaylock &";
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
        command = "pidof swaylock || ${swaylockCmd}";
      }
      ++ lib.optional (idleCfg.sleepTimeout != null) {
        timeout = idleCfg.sleepTimeout;
        command = "/run/current-system/sw/bin/hyprctl dispatch dpms off";
        resumeCommand = "/run/current-system/sw/bin/hyprctl dispatch dpms on";
      };
    events = [
      { event = "before-sleep"; command = "pidof swaylock || ${swaylockCmd}"; }
      { event = "lock";         command = "pidof swaylock || ${swaylockCmd}"; }
    ];
  };
}

# ~/nixos-config/modules/home-manager/services/swayidle.nix
{ config, pkgs, lib, customConfig, ... }:

let
  isHyprland = lib.elem "hyprland" customConfig.desktop.environments;
  idleCfg = customConfig.desktop.idle;
  # hyprlock uses ext-session-lock protocol — no keyboard grab race condition.
  # Run in background (&) so swayidle's -w flag doesn't block subsequent timeouts.
  lockCmd = "pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock &";
in
{
  # On Hyprland with systemd.enable=false, WAYLAND_DISPLAY isn't in the systemd environment
  # at boot. After hyprland/functional.nix imports it via dbus-update-activation-environment,
  # we explicitly start the service so the ConditionEnvironment check passes.
  wayland.windowManager.hyprland.extraConfig = lib.mkIf (isHyprland && (idleCfg.lockTimeout != null || idleCfg.sleepTimeout != null)) ''
    exec-once = systemctl --user start swayidle
  '';

  # Prevent swayidle from auto-starting in non-Hyprland sessions (e.g. KDE).
  # The service is started explicitly by Hyprland's exec-once instead.
  systemd.user.services.swayidle.Install.WantedBy = lib.mkIf (isHyprland && (idleCfg.lockTimeout != null || idleCfg.sleepTimeout != null)) (lib.mkForce []);

  services.swayidle = lib.mkIf (isHyprland && (idleCfg.lockTimeout != null || idleCfg.sleepTimeout != null)) {
    enable = true;
    timeouts =
      lib.optional (idleCfg.lockTimeout != null) {
        timeout = idleCfg.lockTimeout;
        command = lockCmd;
      }
      ++ lib.optional (idleCfg.sleepTimeout != null) {
        timeout = idleCfg.sleepTimeout;
        command = "/run/current-system/sw/bin/hyprctl dispatch dpms off";
        resumeCommand = "/run/current-system/sw/bin/hyprctl dispatch dpms on";
      };
    events = [
      { event = "before-sleep"; command = lockCmd; }
      { event = "lock";         command = lockCmd; }
    ];
  };
}

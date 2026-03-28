# ~/nixos-config/modules/home-manager/services/swayidle.nix
# NOTE: despite the filename, this now configures hypridle (hyprlock's companion daemon).
# hypridle is used instead of swayidle because its before_sleep_cmd uses loginctl lock-session
# (returns immediately) while lock_cmd handles the actual hyprlock start — avoiding the
# swayidle inhibitor-deadlock and hyprlock-dies-during-sleep issues.
{ config, pkgs, lib, customConfig, ... }:

let
  isHyprland = lib.elem "hyprland" customConfig.desktop.environments;
  idleCfg = customConfig.desktop.idle;
  hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
  hyprctl = "/run/current-system/sw/bin/hyprctl";
in
lib.mkIf (isHyprland && (idleCfg.lockTimeout != null || idleCfg.sleepTimeout != null)) {

  # Start hypridle via exec-once so it has WAYLAND_DISPLAY in scope.
  # (Hyprland has systemd.enable=false so the systemd env isn't populated at boot.)
  wayland.windowManager.hyprland.extraConfig = ''
    exec-once = systemctl --user start hypridle
  '';

  # Prevent hypridle auto-starting in non-Hyprland sessions (e.g. KDE).
  # Hyprland's exec-once starts it explicitly after WAYLAND_DISPLAY is ready.
  services.hypridle.settings.general.daemon = false;
  systemd.user.services.hypridle.Install.WantedBy = lib.mkForce [];

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # lock_cmd: what to run when a lock is requested (loginctl lock-session triggers this)
        lock_cmd      = "pidof hyprlock || ${hyprlock}";
        # before_sleep_cmd: loginctl lock-session returns immediately — no inhibitor deadlock.
        # hypridle releases the sleep inhibitor right after this, while lock_cmd runs the locker.
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd  = "${hyprctl} dispatch dpms on";
      };

      listener = lib.optional (idleCfg.lockTimeout != null) {
        timeout   = idleCfg.lockTimeout;
        on-timeout = "loginctl lock-session";
      } ++ lib.optional (idleCfg.sleepTimeout != null) {
        timeout    = idleCfg.sleepTimeout;
        on-timeout = "${hyprctl} dispatch dpms off";
        on-resume  = "${hyprctl} dispatch dpms on";
      };
    };
  };
}

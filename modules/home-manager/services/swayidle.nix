# ~/nixos-config/modules/home-manager/services/swayidle.nix
{ config, pkgs, lib, customConfig, ... }:

let
  isHyprland = lib.elem "hyprland" customConfig.desktop.environments;
  idleCfg = customConfig.desktop.idle;
  # Reference the configured swaylock package (may be swaylock-effects from theme).
  # Run in background (&) so swayidle's -w flag doesn't block it from firing
  # subsequent timeouts (e.g. dpms off) or resume commands while lock is active.
  swaylockBin = "${config.programs.swaylock.package}/bin/swaylock";
  playerctlBin = "${pkgs.playerctl}/bin/playerctl";
  # Script that skips locking if any MPRIS player is active (Spotify, browser media,
  # Jellyfin in Librewolf, etc.) or if a microphone stream is open (Discord calls).
  lockIfIdle = pkgs.writeShellScript "lock-if-idle" ''
    # Skip if any MPRIS player is currently playing (Spotify, browser media sessions)
    ${playerctlBin} -a status 2>/dev/null | grep -q Playing && exit 0
    # Skip if any app has an active microphone input (Discord/video calls)
    ${pkgs.pulseaudio}/bin/pactl list short source-outputs 2>/dev/null | grep -q . && exit 0
    # Lock if not already locked
    pidof swaylock || ${swaylockBin} &
  '';
  # Unconditional lock (before-sleep, explicit lock events)
  lockNow = "pidof swaylock || ${swaylockBin} &";
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
        # Use media-aware lock: skip if media is playing or mic is active
        command = "${lockIfIdle}";
      }
      ++ lib.optional (idleCfg.sleepTimeout != null) {
        timeout = idleCfg.sleepTimeout;
        command = "/run/current-system/sw/bin/hyprctl dispatch dpms off";
        resumeCommand = "/run/current-system/sw/bin/hyprctl dispatch dpms on";
      };
    events = [
      # Lock unconditionally on sleep/explicit lock — don't skip for media
      { event = "before-sleep"; command = lockNow; }
      { event = "lock";         command = lockNow; }
    ];
  };
}

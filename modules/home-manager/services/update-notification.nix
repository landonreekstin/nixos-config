# ~/nixos-config/modules/home-manager/services/update-notification.nix
{ config, pkgs, lib, customConfig, ... }:
let
  cfg = customConfig.homeManager.services.updateNotification;
  configDir = "${config.home.homeDirectory}/nixos-config";

  checkScript = pkgs.writeShellScript "nixos-update-check" ''
    set -e
    cd "${configDir}"

    ${pkgs.git}/bin/git fetch origin main --quiet 2>/dev/null || exit 0

    behind=$(${pkgs.git}/bin/git rev-list HEAD..origin/main --count 2>/dev/null || echo 0)

    if [ "$behind" -gt 0 ]; then
      ${pkgs.libnotify}/bin/notify-send \
        --urgency=normal \
        --icon=software-update-available \
        "NixOS config updates available" \
        "$behind commit(s) ahead on origin/main — run 'sync' to pull"
    fi
  '';
in
{
  config = lib.mkIf cfg.enable {
    systemd.user.services.nixos-update-check = {
      Unit.Description = "Check for NixOS config updates";
      Service = {
        Type = "oneshot";
        ExecStart = "${checkScript}";
      };
    };

    systemd.user.timers.nixos-update-check = {
      Unit.Description = "Check for NixOS config updates once at login";
      Timer = {
        OnStartupSec = "2min";
        Unit = "nixos-update-check.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}

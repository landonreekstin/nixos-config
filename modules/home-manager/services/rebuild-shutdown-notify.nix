# ~/nixos-config/modules/home-manager/services/rebuild-shutdown-notify.nix
{ config, pkgs, lib, customConfig, ... }:
let
  cfg = customConfig.homeManager.services.rebuildShutdownNotify;

  # Must match the marker path written by the `rebuild-shutdown` command
  # (modules/nixos/common/commands.nix).
  notifyScript = pkgs.writeShellScript "rebuild-shutdown-notify" ''
    MARKER="$HOME/.local/state/rebuild-shutdown-failed"
    if [ -f "$MARKER" ]; then
      ${pkgs.libnotify}/bin/notify-send --urgency=critical --icon=dialog-error \
        "Update failed" \
        "Your last 'rebuild-shutdown' did not complete. Run smart-rebuild or claude-rebuild-failed, or tell Lando." \
        2>/dev/null || true
      rm -f "$MARKER"
    fi
  '';
in
{
  config = lib.mkIf cfg.enable {
    systemd.user.services.rebuild-shutdown-notify = {
      Unit.Description = "Notify if the last rebuild-shutdown failed";
      Service = {
        Type = "oneshot";
        ExecStart = "${notifyScript}";
      };
    };

    systemd.user.timers.rebuild-shutdown-notify = {
      Unit.Description = "Check for a failed rebuild-shutdown after login";
      Timer = {
        OnStartupSec = "2min";
        Unit = "rebuild-shutdown-notify.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}

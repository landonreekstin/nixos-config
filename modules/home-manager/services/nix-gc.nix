# ~/nixos-config/modules/home-manager/services/nix-gc.nix
{ pkgs, ... }:
{
  # Weekly cleanup of old home-manager profile generations.
  # The system nix.gc handles the store, but HM generations are GC roots
  # that accumulate separately — this removes all but the 3 most recent.
  systemd.user.services.hm-gc = {
    Unit.Description = "Clean old home-manager generations";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.nh}/bin/nh clean user --keep 3";
    };
  };

  systemd.user.timers.hm-gc = {
    Unit.Description = "Weekly home-manager generation cleanup";
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
      Unit = "hm-gc.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}

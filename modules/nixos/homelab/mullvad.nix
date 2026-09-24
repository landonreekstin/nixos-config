# ~/nixos-config/modules/nixos/homelab/mullvad.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.mullvad;
  mullvad = config.services.mullvad-vpn.package;
in
{
  options.customConfig.homelab.mullvad = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Mullvad VPN daemon for system-wide VPN.";
    };

    watchdog = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Periodically recover the daemon from its `Blocked` state.

          Restarting mullvad-daemon -- which every `rebuild` does -- can leave it parked
          in `Blocked: Failure to generate tunnel parameters: Failure to select a matching
          tunnel relay`, and it does not retry on its own. That state drops all egress
          while *keeping* LAN sharing, which is what makes it so easy to misdiagnose: on
          the NAS, SSH still works and unbound still answers `.lan` for the whole network,
          so the host looks healthy from outside while it cannot resolve or reach anything
          itself, and every nix download fails.
        '';
      };

      interval = mkOption {
        type = types.str;
        default = "2min";
        description = "How often to check. systemd time span, see systemd.time(7).";
      };
    };
  };

  config = lib.mkIf cfg.enable {

    services.mullvad-vpn.enable = true;

    # Declaratively apply settings after the daemon starts.
    # Account login still requires a one-time manual `mullvad account login`.
    systemd.services.mullvad-daemon.postStart = ''
      while ! ${mullvad}/bin/mullvad status >/dev/null 2>&1; do sleep 1; done
      ${mullvad}/bin/mullvad auto-connect set on
      ${mullvad}/bin/mullvad lan set allow
    '';

    systemd.services.mullvad-watchdog = lib.mkIf cfg.watchdog.enable {
      description = "Recover mullvad-daemon from the Blocked state";
      after = [ "mullvad-daemon.service" ];
      requires = [ "mullvad-daemon.service" ];
      serviceConfig.Type = "oneshot";

      # Only `Blocked` is treated as a fault. `Disconnected` is deliberately ignored:
      # auto-connect already handles the ordinary case, and reconnecting here would
      # override a human who ran `mullvad disconnect` on purpose.
      #
      # `relay update` before `reconnect` because a stale relay list is one cause of the
      # failure -- and it works even while blocked, since the daemon allowlists the
      # Mullvad API. When the list is already fine (725 entries, as on 2026-09-23) the
      # update is a no-op and the reconnect is what actually recovers it.
      script = ''
        status="$(${mullvad}/bin/mullvad status 2>&1 || true)"
        case "$status" in
          Blocked*)
            echo "mullvad is blocked, recovering: $status"
            ${mullvad}/bin/mullvad relay update || true
            sleep 5
            ${mullvad}/bin/mullvad reconnect || true
            sleep 10
            echo "after recovery: $(${mullvad}/bin/mullvad status 2>&1 || true)"
            ;;
          *)
            exit 0
            ;;
        esac
      '';
    };

    systemd.timers.mullvad-watchdog = lib.mkIf cfg.watchdog.enable {
      description = "Periodically check mullvad for the Blocked state";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        # The boot delay gives the daemon time to make its own first attempt, so the
        # watchdog reacts to a real failure rather than racing normal startup.
        OnBootSec = "2min";
        OnUnitActiveSec = cfg.watchdog.interval;
        AccuracySec = "30s";
      };
    };

  };
}

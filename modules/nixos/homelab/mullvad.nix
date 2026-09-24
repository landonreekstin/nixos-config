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

      maxAttempts = mkOption {
        type = types.ints.positive;
        default = 5;
        description = ''
          Consecutive failed recoveries before the unit gives up attempting and starts
          failing loudly instead.

          Without this the watchdog retries forever on a fault it cannot fix. Verified
          2026-09-23 by pinning the relay to an unsatisfiable constraint: it detected
          `Blocked` and ran `relay update` + `reconnect` 11 times over 21 minutes, logged
          the identical failure each time, and told nobody -- while the NAS, and so the
          whole house's DNS, had no egress. A silent retry loop is nearly
          indistinguishable from no watchdog during the outage it exists for.

          After this many attempts the unit exits non-zero, so it shows up in
          `systemctl --failed`, and stops calling the CLI. It keeps *checking*: the
          counter resets the moment the daemon is no longer blocked, so once the cause
          clears -- by itself or by hand -- the watchdog re-arms with no intervention.
        '';
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
      serviceConfig = {
        Type = "oneshot";
        # systemd defaults Type=oneshot to TimeoutStartSec=infinity, and none of the
        # three CLI calls below has a timeout of its own. A single hung call against a
        # wedged daemon would therefore hang this unit forever -- and systemd will not
        # start a second instance while one is running, so the timer would stop doing
        # anything at all. The watchdog would be silently dead in exactly the situation
        # it exists for. A killed run is harmless: the next tick retries.
        TimeoutStartSec = "60s";
      };

      # Only `Blocked` is treated as a fault. `Disconnected` is deliberately ignored:
      # auto-connect already handles the ordinary case, and reconnecting here would
      # override a human who ran `mullvad disconnect` on purpose.
      #
      # `relay update` before `reconnect` because a stale relay list is one cause of the
      # failure -- and it works even while blocked, since the daemon allowlists the
      # Mullvad API. When the list is already fine (725 entries, as on 2026-09-23) the
      # update is a no-op and the reconnect is what actually recovers it.
      # Consecutive-failure counter. /run, not /var/lib, on purpose: a reboot clears the
      # daemon's state too, so a fresh boot should start the watchdog fresh.
      script = ''
        state=/run/mullvad-watchdog.failures

        status="$(${mullvad}/bin/mullvad status 2>&1 || true)"
        case "$status" in
          Blocked*) ;;
          *)
            # Healthy (or deliberately disconnected) -- clear the count and stop.
            echo 0 > "$state"
            exit 0
            ;;
        esac

        failures="$(cat "$state" 2>/dev/null || echo 0)"
        case "$failures" in ''' | *[!0-9]*) failures=0 ;; esac
        failures=$((failures + 1))
        echo "$failures" > "$state"

        if [ "$failures" -gt ${toString cfg.watchdog.maxAttempts} ]; then
          echo "still blocked after ${toString cfg.watchdog.maxAttempts} recovery attempts; not retrying." >&2
          echo "manual intervention needed -- check 'mullvad relay get' for an unsatisfiable constraint: $status" >&2
          exit 1
        fi

        echo "mullvad is blocked (attempt $failures/${toString cfg.watchdog.maxAttempts}), recovering: $status"
        ${mullvad}/bin/mullvad relay update || true
        sleep 5
        ${mullvad}/bin/mullvad reconnect || true
        sleep 10

        after="$(${mullvad}/bin/mullvad status 2>&1 || true)"
        echo "after recovery: $after"
        case "$after" in
          Blocked*) ;;
          *) echo 0 > "$state" ;;
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

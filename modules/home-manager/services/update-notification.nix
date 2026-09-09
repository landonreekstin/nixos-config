# ~/nixos-config/modules/home-manager/services/update-notification.nix
{ config, pkgs, lib, customConfig, ... }:
let
  cfg = customConfig.homeManager.services.updateNotification;
  configDir = "${config.home.homeDirectory}/nixos-config";

  updateRebuildScript = pkgs.writeShellScript "nixos-update-rebuild" ''
    export PATH=/run/current-system/sw/bin:/run/wrappers/bin:${pkgs.libnotify}/bin:${pkgs.git}/bin:$PATH

    # Send a notification and print its ID (non-blocking).
    # Usage: send_notif urgency icon title body [replace_id]
    send_notif() {
      local urgency="$1" icon="$2" title="$3" body="$4" replace_id="$5"
      local args=( --print-id --urgency="$urgency" --icon="$icon" )
      [ -n "$replace_id" ] && args+=( --replace-id="$replace_id" )
      notify-send "''${args[@]}" "$title" "$body" 2>/dev/null || true
    }

    # Step 1: Update
    notif_id=$(send_notif normal emblem-synchronizing \
      "NixOS Config" "Updating repository...")

    update_log=$(mktemp /tmp/nixos-update-XXXXXX.log)
    if ! update >"$update_log" 2>&1; then
      send_notif critical dialog-error \
        "NixOS Config — Update Failed" \
        "Could not update the repository. See $update_log for details." \
        "$notif_id"
      exit 1
    fi

    # Step 2: Rebuild
    notif_id=$(send_notif normal system-software-update \
      "NixOS Config" \
      "Rebuilding system — this may take a few minutes..." \
      "$notif_id")

    rebuild_log=$(mktemp /tmp/nixos-rebuild-XXXXXX.log)
    if rebuild >"$rebuild_log" 2>&1; then
      send_notif low emblem-ok \
        "NixOS Config — Rebuild Succeeded" \
        "System is up to date." \
        "$notif_id"
    else
      send_notif critical dialog-error \
        "NixOS Config — Rebuild Failed" \
        "See $rebuild_log for details." \
        "$notif_id"
    fi
  '';

  checkScript = pkgs.writeShellScript "nixos-update-check" ''
    set -e
    cd "${configDir}"

    ${pkgs.git}/bin/git fetch origin main --quiet 2>/dev/null || exit 0

    behind=$(${pkgs.git}/bin/git rev-list HEAD..origin/main --count 2>/dev/null || echo 0)

    if [ "$behind" -gt 0 ]; then
      action=$(${pkgs.libnotify}/bin/notify-send \
        --urgency=normal \
        --icon=software-update-available \
        --action="update_rebuild=Update & Rebuild" \
        "NixOS config updates available" \
        "$behind commit(s) ahead on origin/main" || true)

      if [ "$action" = "update_rebuild" ]; then
        systemctl --user start nixos-update-rebuild.service
      fi
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

    systemd.user.services.nixos-update-rebuild = {
      Unit.Description = "Update and rebuild NixOS configuration";
      Service = {
        Type = "oneshot";
        ExecStart = "${updateRebuildScript}";
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

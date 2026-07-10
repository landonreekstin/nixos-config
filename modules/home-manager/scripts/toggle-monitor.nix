# ~/nixos-config/modules/home-manager/scripts/toggle-monitor.nix
{ pkgs, ... }:

let
  stateFile = "$HOME/.local/state/hypr/disabled-monitors";

  toggleMonitorScript = pkgs.writeShellScriptBin "toggle-monitor" ''
    #!${pkgs.stdenv.shell}
    # Toggle a Hyprland monitor output on/off, persisting state across reboots.
    # Usage: toggle-monitor <identifier> <restore-config>
    #   identifier    - Hyprland monitor id (e.g. "DP-4" or "desc:Dell Inc. ...")
    #   restore-config - Full hyprland monitor config string to restore when re-enabling
    #                    (e.g. "DP-4, 2560x1440@180, 0x0, 1.0667, transform,1")

    MON_ID="$1"
    MON_CONFIG="$2"

    if [ -z "$MON_ID" ] || [ -z "$MON_CONFIG" ]; then
      echo "Usage: toggle-monitor <identifier> <restore-config>" >&2
      exit 1
    fi

    STATE_FILE="${stateFile}"
    mkdir -p "$(dirname "$STATE_FILE")"

    # Fetch all monitors (including disabled) as JSON
    MONITORS_JSON=$(${pkgs.hyprland}/bin/hyprctl monitors -j all 2>/dev/null)

    if [ -z "$MONITORS_JSON" ]; then
      echo "toggle-monitor: could not query hyprctl monitors" >&2
      exit 1
    fi

    # Determine if this monitor is currently active (not disabled)
    # desc: identifiers match against the description field; others match by name
    if echo "$MON_ID" | grep -q "^desc:"; then
      DESC="''${MON_ID#desc:}"
      DISABLED=$(echo "$MONITORS_JSON" | ${pkgs.jq}/bin/jq -r \
        --arg desc "$DESC" \
        '.[] | select(.description == $desc) | .disabled' 2>/dev/null)
    else
      DISABLED=$(echo "$MONITORS_JSON" | ${pkgs.jq}/bin/jq -r \
        --arg name "$MON_ID" \
        '.[] | select(.name == $name) | .disabled' 2>/dev/null)
    fi

    if [ "$DISABLED" = "false" ]; then
      # Monitor is active — disable it and persist state
      ${pkgs.hyprland}/bin/hyprctl keyword monitor "$MON_ID",disable
      grep -qxF "$MON_ID" "$STATE_FILE" 2>/dev/null || echo "$MON_ID" >> "$STATE_FILE"
    else
      # Monitor is disabled — restore it and clear from state
      ${pkgs.hyprland}/bin/hyprctl keyword monitor "$MON_CONFIG"
      if [ -f "$STATE_FILE" ]; then
        ${pkgs.gnugrep}/bin/grep -vxF "$MON_ID" "$STATE_FILE" > "$STATE_FILE.tmp"; \
          mv "$STATE_FILE.tmp" "$STATE_FILE"
      fi
    fi

    # Restart waybar to avoid duplicate instances caused by monitoradded/removed events
    pkill waybar 2>/dev/null || true
    sleep 0.5
    ${pkgs.waybar}/bin/waybar > /tmp/waybar-restart.log 2>&1 &
  '';

  restoreMonitorsScript = pkgs.writeShellScriptBin "restore-monitors" ''
    #!${pkgs.stdenv.shell}
    # Re-apply persisted monitor disable state after Hyprland startup.
    # Called from exec-once after monitors have initialized.

    STATE_FILE="${stateFile}"

    if [ ! -f "$STATE_FILE" ]; then
      exit 0
    fi

    CHANGED=0
    while IFS= read -r MON_ID; do
      [ -z "$MON_ID" ] && continue
      ${pkgs.hyprland}/bin/hyprctl keyword monitor "$MON_ID",disable
      CHANGED=1
    done < "$STATE_FILE"

    # Restart waybar only if any monitors were disabled
    if [ "$CHANGED" = "1" ]; then
      pkill waybar 2>/dev/null || true
      sleep 0.5
      ${pkgs.waybar}/bin/waybar > /tmp/waybar-restart.log 2>&1 &
    fi
  '';

  monitorStateWatcherScript = pkgs.writeShellScriptBin "monitor-state-watcher" ''
    #!${pkgs.stdenv.shell}
    # Re-apply persisted monitor disable state whenever Hyprland reloads its config.
    #
    # exec-once only runs restore-monitors at Hyprland startup, so a `hyprctl reload`
    # (which is what a `nixos-rebuild` triggers when home-manager rewrites hyprland.conf)
    # re-applies the declarative `monitor = [...]` list and re-enables any monitor the
    # user had toggled off. This watcher listens on Hyprland's event socket (socket2) and
    # replays restore-monitors on every `configreloaded` event, so runtime disable state
    # survives rebuilds — not just reboots.

    # Resolve the Hyprland instance signature (env var, or newest runtime dir as fallback)
    SIG="''${HYPRLAND_INSTANCE_SIGNATURE:-}"
    if [ -z "$SIG" ]; then
      SIG=$(ls -t "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -n1)
    fi

    if [ -z "$SIG" ]; then
      echo "monitor-state-watcher: no Hyprland instance found" >&2
      exit 1
    fi

    SOCK="$XDG_RUNTIME_DIR/hypr/$SIG/.socket2.sock"

    # Reconnect loop so the watcher survives transient socket drops.
    while true; do
      if [ ! -S "$SOCK" ]; then
        sleep 2
        continue
      fi
      ${pkgs.socat}/bin/socat -U - UNIX-CONNECT:"$SOCK" 2>/dev/null | while IFS= read -r line; do
        case "$line" in
          configreloaded*)
            # Let Hyprland finish applying the reloaded monitor list before re-disabling.
            sleep 0.3
            ${restoreMonitorsScript}/bin/restore-monitors
            ;;
        esac
      done
      # socat exited (Hyprland gone or socket closed); wait and retry.
      sleep 2
    done
  '';
in
{
  home.packages = [
    toggleMonitorScript
    restoreMonitorsScript
    monitorStateWatcherScript
    pkgs.jq
    pkgs.gnugrep
    pkgs.waybar
    pkgs.socat
  ];
}

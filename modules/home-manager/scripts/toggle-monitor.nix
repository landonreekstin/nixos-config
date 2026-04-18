# ~/nixos-config/modules/home-manager/scripts/toggle-monitor.nix
{ pkgs, ... }:

let
  toggleMonitorScript = pkgs.writeShellScriptBin "toggle-monitor" ''
    #!${pkgs.stdenv.shell}
    # Toggle a Hyprland monitor output on/off.
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
      # Monitor is active — disable it
      ${pkgs.hyprland}/bin/hyprctl keyword monitor "$MON_ID",disable
    else
      # Monitor is disabled or not found — restore it
      ${pkgs.hyprland}/bin/hyprctl keyword monitor "$MON_CONFIG"
    fi
  '';
in
{
  home.packages = [
    toggleMonitorScript
    pkgs.jq
  ];
}

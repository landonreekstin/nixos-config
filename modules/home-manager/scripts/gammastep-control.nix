# ~/nixos-config/modules/home-manager/scripts/gammastep-control.nix
#
# gammastep-init: restores the saved temperature on Hyprland login via exec-once.
# The adjust/toggle scripts live inline in waybar/functional.nix so they can be
# referenced by full Nix store path in the waybar config (avoids PATH ambiguity).
{ pkgs, ... }:

let
  gammastepInitScript = pkgs.writeShellScriptBin "gammastep-init" ''
    STATE_FILE="$HOME/.cache/gammastep-state"

    if [ ! -f "$STATE_FILE" ]; then
      echo "2500:enabled" > "$STATE_FILE"
    fi

    STATE_LINE=$(cat "$STATE_FILE")
    TEMP="''${STATE_LINE%%:*}"
    STATUS="''${STATE_LINE##*:}"

    if [ "$STATUS" = "enabled" ]; then
      ${pkgs.gammastep}/bin/gammastep -O "''${TEMP}"
    fi
  '';

in
{
  home.packages = [ gammastepInitScript ];
}

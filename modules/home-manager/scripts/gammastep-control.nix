# ~/nixos-config/modules/home-manager/scripts/gammastep-control.nix
#
# All scripts use gammastep -O (one-shot mode): applies gamma immediately and
# exits. No daemon is tracked. This avoids geoclue2 D-Bus timing issues and
# prevents waybar from blocking on a hung process.
{ pkgs, ... }:

let
  stateFile = "$HOME/.cache/gammastep-state";
  defaultState = "2500:enabled";

  # Adjust night temperature up or down by 250K
  # Usage: gammastep-adjust up|down
  gammastepAdjustScript = pkgs.writeShellScriptBin "gammastep-adjust" ''
    STATE_FILE="${stateFile}"

    if [ ! -f "$STATE_FILE" ]; then
      echo "${defaultState}" > "$STATE_FILE"
    fi

    STATE_LINE=$(cat "$STATE_FILE")
    TEMP="''${STATE_LINE%%:*}"
    STATUS="''${STATE_LINE##*:}"

    STEP=250
    if [ "''${1:-up}" = "up" ]; then
      TEMP=$((TEMP + STEP))
      [ "$TEMP" -gt 6500 ] && TEMP=6500
    else
      TEMP=$((TEMP - STEP))
      [ "$TEMP" -lt 1000 ] && TEMP=1000
    fi

    echo "''${TEMP}:''${STATUS}" > "$STATE_FILE"

    if [ "$STATUS" = "enabled" ]; then
      ${pkgs.gammastep}/bin/gammastep -O "''${TEMP}"
    fi

    pkill -RTMIN+12 waybar 2>/dev/null || true
  '';

  # Toggle gammastep on or off
  gammastepToggleScript = pkgs.writeShellScriptBin "gammastep-toggle" ''
    STATE_FILE="${stateFile}"

    if [ ! -f "$STATE_FILE" ]; then
      echo "${defaultState}" > "$STATE_FILE"
    fi

    STATE_LINE=$(cat "$STATE_FILE")
    TEMP="''${STATE_LINE%%:*}"
    STATUS="''${STATE_LINE##*:}"

    if [ "$STATUS" = "enabled" ]; then
      echo "''${TEMP}:disabled" > "$STATE_FILE"
      ${pkgs.gammastep}/bin/gammastep -x
    else
      echo "''${TEMP}:enabled" > "$STATE_FILE"
      ${pkgs.gammastep}/bin/gammastep -O "''${TEMP}"
    fi

    pkill -RTMIN+12 waybar 2>/dev/null || true
  '';

  # Called from Hyprland exec-once to restore saved temperature on login
  gammastepInitScript = pkgs.writeShellScriptBin "gammastep-init" ''
    STATE_FILE="${stateFile}"

    if [ ! -f "$STATE_FILE" ]; then
      echo "${defaultState}" > "$STATE_FILE"
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
  home.packages = [
    gammastepAdjustScript
    gammastepToggleScript
    gammastepInitScript
  ];
}

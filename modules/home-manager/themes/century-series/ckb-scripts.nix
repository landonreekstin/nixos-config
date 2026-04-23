# ~/nixos-config/modules/home-manager/themes/century-series/ckb-scripts.nix
# Pure Nix file — import with: import ./ckb-scripts.nix { inherit pkgs; }
# Returns shell scripts for century-series keyboard color cycling and brightness control.
{ pkgs }:

# Century-series keyboard color palette.
# These 4 colors are theme constants — not customConfig options.
# Index: 0=RADAR green, 1=AMBER orange, 2=RED deep, 3=MIG turquoise
# Must match the same array in modules/nixos/hardware/peripherals.nix boot script.

{
  # Output JSON for the waybar custom/ckb-color module.
  colorStatusScript = pkgs.writeShellScript "ckb-color-status" ''
    COLORS=("39ff14" "ff7a1a" "cc0000" "00c8b4")
    LABELS=("RADAR"  "AMBER"  "RED"    "MIG"  )
    STATE_FILE="$HOME/.cache/ckb-color-state"
    [ ! -f "$STATE_FILE" ] && echo "0:80" > "$STATE_FILE"
    STATE=$(cat "$STATE_FILE")
    IDX="''${STATE%%:*}"
    BRIGHT="''${STATE##*:}"
    [[ "$IDX" =~ ^[0-3]$ ]]         || IDX=0
    [[ "$BRIGHT" =~ ^[0-9]+$ ]] && [ "$BRIGHT" -le 100 ] || BRIGHT=80
    LABEL="''${LABELS[$IDX]}"
    CLASS=$(echo "$LABEL" | tr '[:upper:]' '[:lower:]')
    printf '{"text":"%s","class":"%s","tooltip":"KBD: %s %s%% — click to cycle — scroll for brightness"}' \
      "$LABEL" "$CLASS" "$LABEL" "$BRIGHT"
  '';

  # Advance to the next color in the palette, apply immediately, signal waybar.
  colorCycleScript = pkgs.writeShellScript "ckb-color-cycle" ''
    COLORS=("39ff14" "ff7a1a" "cc0000" "00c8b4")
    STATE_FILE="$HOME/.cache/ckb-color-state"
    [ ! -f "$STATE_FILE" ] && echo "0:80" > "$STATE_FILE"
    STATE=$(cat "$STATE_FILE")
    IDX="''${STATE%%:*}"
    BRIGHT="''${STATE##*:}"
    [[ "$IDX" =~ ^[0-3]$ ]]         || IDX=0
    [[ "$BRIGHT" =~ ^[0-9]+$ ]] && [ "$BRIGHT" -le 100 ] || BRIGHT=80
    IDX=$(( (IDX + 1) % 4 ))
    echo "''${IDX}:''${BRIGHT}" > "$STATE_FILE"
    CMD_PIPE=$(ls /dev/input/ckb*/cmd 2>/dev/null | grep -v '/ckb0/' | head -1)
    if [ -n "$CMD_PIPE" ]; then
      echo "rgb ''${COLORS[$IDX]}" > "$CMD_PIPE"
      echo "brightness $BRIGHT"    > "$CMD_PIPE"
    fi
    pkill -RTMIN+14 waybar 2>/dev/null || true
  '';

  # Adjust brightness by ±10. Takes "up" or "down" (default: down).
  brightnessScript = pkgs.writeShellScript "ckb-brightness" ''
    DIRECTION="''${1:-down}"
    COLORS=("39ff14" "ff7a1a" "cc0000" "00c8b4")
    STATE_FILE="$HOME/.cache/ckb-color-state"
    [ ! -f "$STATE_FILE" ] && echo "0:80" > "$STATE_FILE"
    STATE=$(cat "$STATE_FILE")
    IDX="''${STATE%%:*}"
    BRIGHT="''${STATE##*:}"
    [[ "$IDX" =~ ^[0-3]$ ]]         || IDX=0
    [[ "$BRIGHT" =~ ^[0-9]+$ ]] && [ "$BRIGHT" -le 100 ] || BRIGHT=80
    STEP=10
    if [ "$DIRECTION" = "up" ]; then
      BRIGHT=$(( BRIGHT + STEP ))
      [ "$BRIGHT" -gt 100 ] && BRIGHT=100
    else
      BRIGHT=$(( BRIGHT - STEP ))
      [ "$BRIGHT" -lt 0 ] && BRIGHT=0
    fi
    echo "''${IDX}:''${BRIGHT}" > "$STATE_FILE"
    CMD_PIPE=$(ls /dev/input/ckb*/cmd 2>/dev/null | grep -v '/ckb0/' | head -1)
    if [ -n "$CMD_PIPE" ]; then
      echo "rgb ''${COLORS[$IDX]}" > "$CMD_PIPE"
      echo "brightness $BRIGHT"    > "$CMD_PIPE"
    fi
    pkill -RTMIN+14 waybar 2>/dev/null || true
  '';
}

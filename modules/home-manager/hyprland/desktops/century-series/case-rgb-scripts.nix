# ~/nixos-config/modules/home-manager/hyprland/desktops/century-series/case-rgb-scripts.nix
# Pure Nix file — import with: import ./case-rgb-scripts.nix { inherit pkgs; }
# Waybar glue for the case fans, the twin of ckb-scripts.nix (the keyboard).
#
# All state handling lives in the `case-rgb` CLI (modules/nixos/hardware/case-rgb.nix),
# which keeps colour index, brightness and effect in ~/.cache/case-rgb-state. Its palette
# is the same RADAR / AMBER / RED / MIG cycle as ckb-scripts.nix, so the CASE widget can
# reuse the KBD widget's CSS classes and the @c_kbd_* colour tokens.
#
# LINK: while ~/.cache/rgb-link exists, colour and brightness are shared with the keyboard.
# A change here is copied into ~/.cache/ckb-color-state and applied; a change on the
# keyboard side is mirrored back by ckb-scripts.nix. Turning the link on makes the
# keyboard the master (the fans take its colour and brightness). The effect
# (STEADY/PULSE) stays fans-only: the keyboard has no equivalent.
#
# Waybar refreshes CASE on SIGRTMIN+18 and KBD on SIGRTMIN+14.
{ pkgs }:

let
  caseRgb = import ../../../../nixos/hardware/case-rgb.nix { inherit pkgs; };
  ckbScripts = import ./ckb-scripts.nix { inherit pkgs; };
  bin = "${caseRgb}/bin/case-rgb";
  pkill = "${pkgs.procps}/bin/pkill";
  refresh = "${pkill} -RTMIN+18 waybar 2>/dev/null || true";

  # Copy the fans' colour/brightness onto the keyboard when linked.
  mirrorToKbd = ''
    if [ -f "$HOME/.cache/rgb-link" ]; then
      read -r IDX BRIGHT _ < <(${bin} get)
      echo "$IDX:$BRIGHT" > "$HOME/.cache/ckb-color-state"
      ${ckbScripts.applyCurrentScript}
      ${pkill} -RTMIN+14 waybar 2>/dev/null || true
    fi
  '';
in
{
  inherit caseRgb;

  # Output JSON for the waybar custom/case-rgb module.
  statusScript = pkgs.writeShellScript "case-rgb-status" ''
    LABELS=("RADAR" "AMBER" "RED" "MIG")
    read -r IDX BRIGHT EFFECT < <(${bin} get)
    LABEL="''${LABELS[$IDX]}"
    CLASS=$(echo "$LABEL" | tr '[:upper:]' '[:lower:]')
    if [ "$EFFECT" = "pulse" ]; then TEXT="$LABEL·P"; EFF="PULSE"; else TEXT="$LABEL"; EFF="STEADY"; fi
    LINK=""; LINKCLASS=""
    if [ -f "$HOME/.cache/rgb-link" ]; then LINK=" — LINKED to KBD"; LINKCLASS=',"linked"'; fi
    printf '{"text":"%s","class":["%s"%s],"tooltip":"CASE: %s %s%% %s%s — click: colour — right-click: effect — scroll: brightness — middle-click: link with KBD"}' \
      "$TEXT" "$CLASS" "$LINKCLASS" "$LABEL" "$BRIGHT" "$EFF" "$LINK"
  '';

  colorCycleScript = pkgs.writeShellScript "case-rgb-color-cycle" ''
    ${bin} cycle-color
    ${refresh}
    ${mirrorToKbd}
  '';

  effectCycleScript = pkgs.writeShellScript "case-rgb-effect-cycle" ''
    ${bin} cycle-effect
    ${refresh}
  '';

  # Takes "up" or "down" (default: down), like ckb-scripts' brightnessScript.
  brightnessScript = pkgs.writeShellScript "case-rgb-brightness" ''
    ${bin} bright "''${1:-down}"
    ${refresh}
    ${mirrorToKbd}
  '';

  # Middle-click on KBD or CASE. Linking makes the keyboard the master.
  linkToggleScript = pkgs.writeShellScript "rgb-link-toggle" ''
    FLAG="$HOME/.cache/rgb-link"
    if [ -f "$FLAG" ]; then
      rm -f "$FLAG"
    else
      mkdir -p "$HOME/.cache" && touch "$FLAG"
      STATE=$(cat "$HOME/.cache/ckb-color-state" 2>/dev/null || echo "0:80")
      IDX="''${STATE%%:*}"; BRIGHT="''${STATE##*:}"
      [[ "$IDX" =~ ^[0-3]$ ]] || IDX=0
      [[ "$BRIGHT" =~ ^[0-9]+$ ]] && [ "$BRIGHT" -le 100 ] || BRIGHT=80
      ${bin} set "$IDX" "$BRIGHT" || true
    fi
    ${refresh}
    ${pkill} -RTMIN+14 waybar 2>/dev/null || true
  '';
}

# ~/nixos-config/modules/home-manager/scripts/stream-wall.nix
#
# stream-wall: arrange every Firefox Picture-in-Picture window on the focused
# monitor into an exact grid that fills the whole panel.
#
# Why a script rather than a layout/windowrule:
#
#   * dwindle cannot produce a 2x2. It splits the focused window along its
#     longer axis, so four windows on a 16:9 panel come out as one half, one
#     quarter and two eighths -- never quadrants. A 2x2 from dwindle is a
#     coincidence of the starting geometry, not something you can rely on.
#   * A windowrule cannot place four windows in four different spots: every PiP
#     window has the identical class (firefox) and title (Picture-in-Picture),
#     so one rule matches all of them and they would stack.
#   * Tiled windows are confined to the area left over by waybar/launcherBar
#     (95px on this setup). Floating windows are not, so placing them by pixel
#     is also what buys back a true 16:9 quadrant.
#
# Firefox allows many concurrent PiP windows (one per video); Chromium permits
# exactly one process-wide and tears down the previous one, so the wall is a
# Firefox-only trick.
#
# Usage:
#   stream-wall            arrange into a 2x2 and hide the bars
#   stream-wall 3x2        arrange into an explicit COLSxROWS grid
#   stream-wall off        restore the bars and return the windows to tiling
{ pkgs, lib, ... }:

let
  streamWallScript = pkgs.writeShellScriptBin "stream-wall" ''
    set -euo pipefail

    hyprctl=${pkgs.hyprland}/bin/hyprctl
    jq=${pkgs.jq}/bin/jq

    if [ "$(printenv XDG_CURRENT_DESKTOP 2>/dev/null || true)" != "Hyprland" ]; then
      echo "stream-wall: not in a Hyprland session" >&2
      exit 1
    fi

    # waybar toggles its own visibility on SIGUSR1. Both bars (waybar and the
    # split-out launcherBar) are waybar processes, so this catches both.
    #
    # NOT -x. Under the NixOS wrapper the process comm is ".waybar-wrapped", so
    # an exact-name match finds nothing and silently no-ops. pkill's default
    # substring match on comm is what hits it -- the same reason every
    # `pkill -RTMIN+N waybar` in waybar/functional.nix omits -x.
    #
    # SIGUSR1 is a blind toggle, so it has to be gated on whether the bars are
    # ALREADY hidden, or the wall fights them: arranging twice would hide then
    # re-show, and `off` with no wall up would hide them outright.
    #
    # Gate on the compositor's reserved area, not on a state file. A state file
    # goes stale the moment anything restarts waybar -- a rebuild, a crash,
    # toggle-launchbar -- because the bars come back visible while the file
    # still claims they are hidden, and the next arrange then skips hiding them.
    # The reserved area is ground truth: a hidden bar drops its exclusive zone,
    # so the sum is 0 exactly when nothing is reserving space.
    bars_hidden() {
      [ "$("$hyprctl" -j monitors \
            | "$jq" -r '[.[] | select(.focused) | .reserved[]] | add')" = "0" ]
    }

    signal_bars() {
      ${pkgs.procps}/bin/pkill -SIGUSR1 waybar 2>/dev/null || true
      # Let the compositor apply the new exclusive zone, so an immediately
      # following invocation reads the updated reserved area rather than
      # toggling a second time.
      ${pkgs.coreutils}/bin/sleep 0.2
    }

    hide_bars() { if ! bars_hidden; then signal_bars; fi; }
    show_bars() { if   bars_hidden; then signal_bars; fi; }

    PIP_TITLE='^Picture-in-Picture$'

    # Addresses of every PiP window, in creation order.
    mapfile -t ADDRS < <(
      "$hyprctl" -j clients \
        | "$jq" -r --arg t "$PIP_TITLE" '.[] | select(.title | test($t)) | .address'
    )

    if [ "''${#ADDRS[@]}" -eq 0 ]; then
      echo "stream-wall: no Picture-in-Picture windows found." >&2
      echo "Pop out a video in Firefox first (Chromium only allows one)." >&2
      exit 1
    fi

    if [ "''${1:-}" = "off" ]; then
      for a in "''${ADDRS[@]}"; do
        "$hyprctl" dispatch settiled "address:$a" >/dev/null
      done
      show_bars
      echo "stream-wall: released ''${#ADDRS[@]} window(s), bars restored."
      exit 0
    fi

    # Grid geometry. Default 2x2 -- the four-stream case this exists for.
    COLS=2; ROWS=2
    if [ -n "''${1:-}" ]; then
      if [[ "$1" =~ ^([0-9]+)x([0-9]+)$ ]]; then
        COLS="''${BASH_REMATCH[1]}"; ROWS="''${BASH_REMATCH[2]}"
      else
        echo "stream-wall: expected COLSxROWS (e.g. 3x2) or 'off', got '$1'" >&2
        exit 1
      fi
    fi

    # Focused monitor, in LOGICAL coordinates. hyprctl reports .width/.height as
    # the physical mode, so a rotated monitor (transform 1/3) needs the swap or
    # the grid is computed against the wrong axis.
    read -r MX MY MW MH < <(
      "$hyprctl" -j monitors | "$jq" -r '
        .[] | select(.focused) |
        (if (.transform % 2) == 1
         then [(.height / .scale), (.width / .scale)]
         else [(.width / .scale), (.height / .scale)] end) as $d |
        "\(.x) \(.y) \($d[0] | floor) \($d[1] | floor)"'
    )

    CW=$(( MW / COLS ))
    CH=$(( MH / ROWS ))
    CELLS=$(( COLS * ROWS ))

    i=0
    for a in "''${ADDRS[@]}"; do
      if [ "$i" -ge "$CELLS" ]; then
        echo "stream-wall: ''${#ADDRS[@]} windows exceed the ''${COLS}x''${ROWS} grid;" \
             "leaving the extras alone." >&2
        break
      fi
      col=$(( i % COLS ))
      row=$(( i / COLS ))
      x=$(( MX + col * CW ))
      y=$(( MY + row * CH ))

      # Float first: a tiled window ignores an exact resize, and only a floating
      # window may extend under the bars' reserved area.
      "$hyprctl" dispatch setfloating "address:$a" >/dev/null
      "$hyprctl" dispatch resizewindowpixel "exact $CW $CH,address:$a" >/dev/null
      "$hyprctl" dispatch movewindowpixel  "exact $x $y,address:$a" >/dev/null
      i=$(( i + 1 ))
    done

    hide_bars
    echo "stream-wall: placed $i window(s) in a ''${COLS}x''${ROWS} grid of ''${CW}x''${CH}."
  '';
in
{
  home.packages = [ streamWallScript ];
}

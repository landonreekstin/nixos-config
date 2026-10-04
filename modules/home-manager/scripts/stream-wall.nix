# ~/nixos-config/modules/home-manager/scripts/stream-wall.nix
#
# Two commands for a wall of Firefox Picture-in-Picture video windows:
#
#   stream-wall   arrange every PiP window into an exact grid filling its
#                 monitor -- one independent grid per monitor.
#   stream-audio  pick which single video is audible.
#
# Why a script rather than a layout/windowrule:
#
#   * dwindle cannot produce a 2x2. It splits the focused window along its
#     longer axis, so four windows on a 16:9 panel come out as one half, one
#     quarter and two eighths. A 2x2 from dwindle is a coincidence of the
#     starting geometry, not something you can rely on.
#   * A windowrule cannot place four windows in four different spots: every PiP
#     window has the identical class (firefox) and title (Picture-in-Picture),
#     so one rule matches all of them and they would stack.
#   * Tiled windows are confined to the area left over by waybar/launcherBar
#     (95px here). Floating windows are not, so placing them by pixel is also
#     what buys back a true 16:9 quadrant.
#
# Firefox allows many concurrent PiP windows (one per video); Chromium permits
# exactly one process-wide and tears down the previous one, so this is a
# Firefox-only trick.
#
# WALLS. A Hyprland named workspace lives on exactly one monitor, so one wall
# per workspace: `streams` (wall 1), `streams-2`, `streams-3`. New PiP windows
# auto-route to `streams`; move one to another wall with $mainMod $altMod SHIFT
# plus the wall number. stream-wall then grids each monitor separately, to that
# monitor's own geometry -- a 2560x1440 wall and a 1920x1080 wall at once are
# fine.
#
# AUDIO. Firefox mixes every video into a SINGLE PipeWire stream (one node for
# the whole process, however many videos play), so wpctl/pactl cannot isolate
# one video -- they can only mute all of Firefox. The per-video control that
# does exist is in the PiP window's own overlay, and Hyprland can drive it:
# `dispatch sendshortcut , up/down, address:0x...` adjusts THAT video's volume,
# and it works on an UNFOCUSED window, so switching audio never disturbs focus
# or the wall.
#
# Those arrows are relative steps with no readable state, so stream-audio
# saturates instead of tracking: volumeSteps presses of `down` on every window
# (guaranteed silent from any starting point), then the same count of `up` on
# the chosen one. At ~8ms per press a four-window switch is well under a second.
#
# Usage:
#   stream-wall            arrange every wall into 2x2 and hide the bars
#   stream-wall 3x2        arrange with an explicit COLSxROWS grid
#   stream-wall off        restore the bars and return the windows to tiling
#
#   stream-audio 3         give audio to the 3rd window (walls in order, then
#                          row-major within a wall: 1-4 wall 1, 5-8 wall 2, ...)
#   stream-audio next      advance to the next window (best effort, see below)
#   stream-audio none      mute every window
{ pkgs, lib, ... }:

let
  # How many arrow presses are enough to drive a PiP video's volume from one
  # extreme to the other. Measured at roughly 8-10% per press, so 20 saturates
  # with margin; the ends clamp, making an overshoot harmless.
  volumeSteps = 20;

  # Wall workspaces, in the order their windows are numbered by stream-audio.
  wallWorkspaces = [ "streams" "streams-2" "streams-3" ];

  # jq: every PiP window, ordered the way the user sees them -- walls in order,
  # then row-major (top row left-to-right, then the next row) within each wall.
  # A PiP window parked somewhere other than a wall sorts last, so it is still
  # addressable rather than silently missing.
  orderedPipFilter = ''
    def wallrank:
      . as $n
      | ${builtins.toJSON wallWorkspaces} as $walls
      | ($walls | index($n)) // 99;
    [ .[] | select(.title == "Picture-in-Picture") ]
    | sort_by([ (.workspace.name | wallrank), .at[1], .at[0] ])
  '';

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
    # The reserved area is ground truth: a hidden bar drops its exclusive zone.
    # Summed over ALL monitors, not just the focused one, because the walls may
    # be on monitors the user is not currently focused on.
    bars_hidden() {
      [ "$("$hyprctl" -j monitors | "$jq" -r '[.[] | .reserved[]] | add')" = "0" ]
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

    CLIENTS="$("$hyprctl" -j clients)"

    mapfile -t ALL_ADDRS < <(printf '%s' "$CLIENTS" | "$jq" -r '${orderedPipFilter} | .[].address')

    if [ "''${#ALL_ADDRS[@]}" -eq 0 ]; then
      echo "stream-wall: no Picture-in-Picture windows found." >&2
      echo "Pop out a video in Firefox first (Chromium only allows one)." >&2
      exit 1
    fi

    if [ "''${1:-}" = "off" ]; then
      for a in "''${ALL_ADDRS[@]}"; do
        "$hyprctl" dispatch settiled "address:$a" >/dev/null
      done
      show_bars
      echo "stream-wall: released ''${#ALL_ADDRS[@]} window(s), bars restored."
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
    CELLS=$(( COLS * ROWS ))

    MONITORS="$("$hyprctl" -j monitors)"
    PLACED=0
    WALLS=0

    # One independent grid per monitor. Grouping on the window's own .monitor
    # (not the focused one) is what lets several walls exist at once; a window
    # is laid out against the geometry of the monitor it is actually on.
    for mid in $(printf '%s' "$CLIENTS" \
                   | "$jq" -r '${orderedPipFilter} | .[].monitor' | sort -un); do

      # Monitor box in LOGICAL coordinates. hyprctl reports .width/.height as
      # the physical mode, so a rotated monitor (transform 1/3) needs the swap
      # or the grid is computed against the wrong axis.
      read -r MX MY MW MH MNAME < <(
        printf '%s' "$MONITORS" | "$jq" -r --argjson id "$mid" '
          .[] | select(.id == $id) |
          (if (.transform % 2) == 1
           then [(.height / .scale), (.width / .scale)]
           else [(.width / .scale), (.height / .scale)] end) as $d |
          "\(.x) \(.y) \($d[0] | floor) \($d[1] | floor) \(.name)"'
      )

      CW=$(( MW / COLS ))
      CH=$(( MH / ROWS ))

      mapfile -t ADDRS < <(
        printf '%s' "$CLIENTS" \
          | "$jq" -r --argjson id "$mid" '${orderedPipFilter} | .[] | select(.monitor == $id) | .address'
      )

      i=0
      for a in "''${ADDRS[@]}"; do
        if [ "$i" -ge "$CELLS" ]; then
          echo "stream-wall: $MNAME has ''${#ADDRS[@]} windows, more than the" \
               "''${COLS}x''${ROWS} grid holds; leaving the extras alone." >&2
          break
        fi
        col=$(( i % COLS ))
        row=$(( i / COLS ))
        x=$(( MX + col * CW ))
        y=$(( MY + row * CH ))

        # Float first: a tiled window ignores an exact resize, and only a
        # floating window may extend under the bars' reserved area.
        "$hyprctl" dispatch setfloating      "address:$a" >/dev/null
        "$hyprctl" dispatch resizewindowpixel "exact $CW $CH,address:$a" >/dev/null
        "$hyprctl" dispatch movewindowpixel   "exact $x $y,address:$a" >/dev/null
        i=$(( i + 1 ))
      done

      echo "stream-wall: $MNAME -> $i window(s) in ''${COLS}x''${ROWS} of ''${CW}x''${CH}"
      PLACED=$(( PLACED + i ))
      WALLS=$(( WALLS + 1 ))
    done

    hide_bars
    echo "stream-wall: placed $PLACED window(s) across $WALLS wall(s)."
  '';

  streamAudioScript = pkgs.writeShellScriptBin "stream-audio" ''
    set -euo pipefail

    hyprctl=${pkgs.hyprland}/bin/hyprctl
    jq=${pkgs.jq}/bin/jq
    STEPS=${toString volumeSteps}

    if [ "$(printenv XDG_CURRENT_DESKTOP 2>/dev/null || true)" != "Hyprland" ]; then
      echo "stream-audio: not in a Hyprland session" >&2
      exit 1
    fi

    mapfile -t ADDRS < <("$hyprctl" -j clients | "$jq" -r '${orderedPipFilter} | .[].address')
    COUNT="''${#ADDRS[@]}"

    if [ "$COUNT" -eq 0 ]; then
      echo "stream-audio: no Picture-in-Picture windows found." >&2
      exit 1
    fi

    # Best-effort memory of the last selection, for `next`. Volume is not
    # readable back from the window, so this cannot be derived. A stale hint
    # only ever costs one wrong step, so it is not worth more than a file.
    ARG="''${1:-}"

    HINT="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr/stream-audio-active"
    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$HINT")"

    # Drive a single window's volume to one extreme. The arrows are relative
    # steps that clamp at the ends, so overshooting is how this stays correct
    # without being able to read the current level.
    saturate() {
      local addr="$1" key="$2" n
      for n in $(seq "$STEPS"); do
        "$hyprctl" dispatch sendshortcut ", $key, address:$addr" >/dev/null
      done
    }

    TARGET=""
    case "$ARG" in
      none)
        TARGET=0
        ;;
      next)
        prev=0
        [ -r "$HINT" ] && prev="$(cat "$HINT" 2>/dev/null || echo 0)"
        [[ "$prev" =~ ^[0-9]+$ ]] || prev=0
        TARGET=$(( prev % COUNT + 1 ))
        ;;
      ""|*[!0-9]*)
        echo "stream-audio: expected a window number (1-$COUNT), 'next' or 'none', got: $ARG" >&2
        exit 1
        ;;
      *)
        TARGET="$ARG"
        if [ "$TARGET" -lt 1 ] || [ "$TARGET" -gt "$COUNT" ]; then
          echo "stream-audio: $TARGET is out of range; $COUNT window(s) open." >&2
          exit 1
        fi
        ;;
    esac

    # Silence everything first, so exactly one video can be audible regardless
    # of what state the windows were left in.
    for a in "''${ADDRS[@]}"; do saturate "$a" down; done

    if [ "$TARGET" -eq 0 ]; then
      echo 0 > "$HINT"
      echo "stream-audio: muted all $COUNT window(s)."
      exit 0
    fi

    saturate "''${ADDRS[$(( TARGET - 1 ))]}" up
    echo "$TARGET" > "$HINT"
    echo "stream-audio: window $TARGET of $COUNT is now the audible one."
  '';
in
{
  home.packages = [ streamWallScript streamAudioScript ];
}

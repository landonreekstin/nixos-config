# ~/nixos-config/modules/home-manager/hyprland/desktops/glade/snap.nix
#
# Windows snap together like on Windows, as insideabush asked: drag one by its title bar
# to the left or right edge of a screen and let go, and it fills that half; drag it off
# again and it goes back to the size it had. Dropped near another window or a screen
# edge, it lines up against it (Hyprland's own general.snap). The top edge does nothing
# special on purpose: he hates Windows' drag-to-the-top maximise.
#
# Hyprland has no event for "a drag ended", and hyprbars swallows the clicks on its bar,
# so a small patch (hyprbars-drag-hooks.patch, applied in desktop.nix) gives hyprbars
# on_drag_start / on_drag_end commands, which run glade-snap.
{ config, pkgs, lib, customConfig, ... }:

let
  desktop = (import ../lib.nix { inherit lib; }).state customConfig "glade";

  # Space around a snapped window and between windows that snap together.
  gap = 12;

  gladeSnap = pkgs.writeShellApplication {
    name = "glade-snap";
    runtimeInputs = [ pkgs.hyprland pkgs.jq ];
    text = ''
      state="''${XDG_RUNTIME_DIR:-/tmp}/glade-snap"
      mkdir -p "$state"
      edge=4 # how close to the screen's edge the pointer must be, in pixels
      gap=${toString gap}

      win=$(hyprctl -j activewindow)
      addr=$(jq -r '.address // empty' <<<"$win")
      [ -n "$addr" ] || exit 0
      [ "$(jq -r '.floating and (.fullscreen == 0)' <<<"$win")" = true ] || exit 0
      saved="$state/$addr" # its size from before it snapped, while it is snapped

      case "''${1:-}" in
        start)
          # Picked up off a half: back to its old size, under the pointer.
          if [ -f "$saved" ]; then
            read -r w h < "$saved"; rm -f "$saved"
            read -r cx _ < <(hyprctl -j cursorpos | jq -r '"\(.x) \(.y)"')
            y=$(jq '.at[1]' <<<"$win")
            hyprctl --batch "dispatch resizewindowpixel exact $w $h,address:$addr ; dispatch movewindowpixel exact $((cx - w / 2)) $y,address:$addr" >/dev/null
          fi
          ;;
        end)
          read -r cx cy < <(hyprctl -j cursorpos | jq -r '"\(.x) \(.y)"')
          mon=$(hyprctl -j monitors | jq -c --argjson x "$cx" --argjson y "$cy" '
            [.[] | select($x >= .x and $x < .x + (.width / .scale) and $y >= .y and $y < .y + (.height / .scale))][0] // empty')
          [ -n "$mon" ] || exit 0
          read -r mx my mw mh rl rt rr rb < <(jq -r '"\(.x) \(.y) \(.width / .scale | floor) \(.height / .scale | floor) \(.reserved | join(" "))"' <<<"$mon")

          if [ "$cx" -le $((mx + edge)) ]; then side=left
          elif [ "$cx" -ge $((mx + mw - 1 - edge)) ]; then side=right
          else exit 0
          fi

          # Kept from before the first snap only, so left -> right keeps the old size.
          [ -f "$saved" ] || jq -r '.size | join(" ")' <<<"$win" > "$saved"

          # The title bar sits above the window and the border around it: leave room.
          bar=$(hyprctl -j getoption plugin:hyprbars:bar_height | jq '.int // 0')
          bd=$(hyprctl -j getoption general:border_size | jq '.int // 0')
          ax=$((mx + rl + gap + bd)); ay=$((my + rt + gap + bd + bar))
          aw=$((mw - rl - rr - 2 * gap - 2 * bd)); ah=$((mh - rt - rb - 2 * gap - 2 * bd - bar))
          hw=$(((aw - gap - 2 * bd) / 2))
          if [ "$side" = left ]; then x=$ax; else x=$((ax + aw - hw)); fi
          hyprctl --batch "dispatch resizewindowpixel exact $hw $ah,address:$addr ; dispatch movewindowpixel exact $x $ay,address:$addr" >/dev/null
          ;;
      esac
    '';
  };
in
{
  config = lib.mkIf desktop.enabled {
    home.packages = [ gladeSnap ];

    hyprDesktops.glade.settings = {
      general.snap = {
        enabled = true;
        window_gap = gap;
        monitor_gap = gap;
      };
      plugin.hyprbars = {
        on_drag_start = "glade-snap start";
        on_drag_end = "glade-snap end";
      };
    };
  };
}

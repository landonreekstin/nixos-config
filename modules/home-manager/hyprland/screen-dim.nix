# ~/nixos-config/modules/home-manager/hyprland/screen-dim.nix
# Per-screen software dimming (customConfig.homeManager.services.screenDim).
#
# Some screens can't be dimmed from the PC at all: the TV on gaming-pc has no
# DDC/CI and is already on its darkest preset. So this dims the picture
# instead. wl-gammarelay-rs holds a gamma ramp per output (wlr-gamma-control)
# and offers it over D-Bus at /outputs/<NAME>, with "-" spelled "_".
#
# The gamma ramp is a separate stage from the colour matrix hyprsunset uses, so
# night light and dimming stack and neither one resets the other. Software
# dimming darkens whites and colours only; black can't get blacker, because the
# screen's backlight stays where it is.
#
# Levels persist per output in $XDG_STATE_HOME/screen-dim/<NAME> and are put
# back when the daemon starts (login, desktop switch, rebuild).
{ config, pkgs, lib, customConfig, ... }:

let
  cfg = customConfig.homeManager.services.screenDim;
  on = lib.elem "hyprland" customConfig.desktop.environments && cfg.enable;
  desktopLib = import ./desktops/lib.nix { inherit lib; };

  screenDim = pkgs.writeShellApplication {
    name = "screen-dim";
    runtimeInputs = with pkgs; [ systemd hyprland jq gawk coreutils libnotify ];
    text = ''
      usage() {
        echo "usage: screen-dim [OUTPUT|focused] +N|-N|N|reset|get" >&2
        echo "       screen-dim restore" >&2
        exit 2
      }

      bus=rs.wl-gammarelay
      iface=rs.wl.gammarelay
      min=${toString cfg.minPercent}
      state="''${XDG_STATE_HOME:-$HOME/.local/state}/screen-dim"

      path_of() { echo "/outputs/''${1//-/_}"; }
      focused() { hyprctl monitors -j | jq -r '.[] | select(.focused) | .name'; }

      # Current level of output $1 as a whole percent.
      get() {
        busctl --user get-property "$bus" "$(path_of "$1")" "$iface" Brightness \
          | awk '{ printf "%d\n", $2 * 100 + 0.5 }'
      }

      set_level() {
        busctl --user set-property "$bus" "$(path_of "$1")" "$iface" Brightness d \
          "$(awk -v p="$2" 'BEGIN { printf "%.2f", p / 100 }')"
      }

      # Put back every saved level. The daemon may not have registered its
      # outputs yet when this runs right after it starts, so wait for each one.
      restore() {
        [ -d "$state" ] || return 0
        for f in "$state"/*; do
          [ -f "$f" ] || continue
          out=$(basename "$f")
          for _ in $(seq 1 50); do
            if busctl --user get-property "$bus" "$(path_of "$out")" "$iface" Brightness >/dev/null 2>&1; then
              set_level "$out" "$(cat "$f")" || true
              break
            fi
            sleep 0.1
          done
        done
      }

      [ $# -ge 1 ] || usage
      if [ "$1" = restore ]; then restore; exit 0; fi

      if [ $# -eq 1 ]; then out=focused; arg=$1; else out=$1; arg=$2; fi
      [ "$out" = focused ] && out=$(focused)
      [ -n "$out" ] || { echo "screen-dim: no output" >&2; exit 1; }

      cur=$(get "$out")
      case "$arg" in
        get) echo "$cur"; exit 0 ;;
        reset) new=100 ;;
        [+-][0-9]*) new=$((cur + arg)) ;;
        [0-9]*) new=$arg ;;
        *) usage ;;
      esac
      # Never fully black: a screen you can't see is a screen you can't fix.
      [ "$new" -lt "$min" ] && new=$min
      [ "$new" -gt 100 ] && new=100

      set_level "$out" "$new"
      mkdir -p "$state"
      if [ "$new" -eq 100 ]; then rm -f "$state/$out"; else echo "$new" > "$state/$out"; fi

      notify-send -a screen-dim -t 1500 \
        -h string:x-canonical-private-synchronous:screen-dim -h "int:value:$new" \
        "Screen brightness" "$out: $new%" || true
    '';
  };
in
{
  config = lib.mkIf on {
    home.packages = [ screenDim ];

    # Lives as long as the Hyprland session, across desktop switches: it binds
    # to the session service, and every desktop's target pulls it in.
    systemd.user.services.wl-gammarelay = {
      Unit = {
        Description = "Per-output gamma (screen-dim) for Hyprland";
        BindsTo = [ "hypr-desktop-session.service" ];
        After = [ "hypr-desktop-session.service" ];
      };
      Service = {
        ExecStart = "${pkgs.wl-gammarelay-rs}/bin/wl-gammarelay-rs run";
        ExecStartPost = "-${screenDim}/bin/screen-dim restore";
        # At login it can start before WAYLAND_DISPLAY reaches the user manager.
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install.WantedBy = map desktopLib.target customConfig.homeManager.hyprland.desktops.enabled;
    };
  };
}

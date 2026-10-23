# ~/nixos-config/modules/home-manager/services/audio-balance.nix
{ config, pkgs, lib, customConfig, ... }:
let
  cfg = customConfig.homeManager.services.audioBalance;
  pactl = "${pkgs.pulseaudio}/bin/pactl";
  awk = "${pkgs.gawk}/bin/awk";
  peak = lib.max cfg.left cfg.right;

  # `volume-step` — change a sink's volume without flattening its channel balance.
  #
  # `wpctl set-volume` writes ONE value to every channel, computed from channel 0 alone
  # (from 60/75, "5%+" gives 65/65), so any balance dies on the first volume key press.
  # This scales the channels together instead. On the balanced sink they are rebuilt
  # from left/right every time, so the ratio is exact at any volume and survives a trip
  # through 0%; any other sink keeps whatever ratio it already has. The loudest channel
  # is the volume — balancing only ever turns the other one down.
  #
  # Installed on every host because the Hyprland volume keys and waybar scroll call it;
  # with audioBalance disabled it is just a ratio-preserving `wpctl set-volume`.
  #
  # Usage:
  #   volume-step +5 | -5          step the default sink by N percent of full scale
  #   volume-step --sink NAME +5   step a specific sink
  #   volume-step --apply-balance  set every balanced sink to left/right at its current
  #                                loudest-channel level (the login unit below)
  volumeStep = pkgs.writeShellScriptBin "volume-step" ''
    #!${pkgs.stdenv.shell}

    # One line per sink: name<TAB>active port<TAB>"name|description|alsa.name". alsa.name
    # is the display's EDID name on HDMI/DP, e.g. "LG ULTRAGEAR" — the same triple
    # audioSinkMappings matches against. HDMI/DP pro-audio sinks have no port at all, so
    # an empty port prints as "-": tab is IFS whitespace, and `read` would collapse the
    # empty field and shift the triple into PORT.
    list_sinks() {
      ${pactl} list sinks | ${awk} '
        function flush() { if (name != "") print name "\t" (port == "" ? "-" : port) "\t" name "|" desc "|" dev; name = ""; port = ""; desc = ""; dev = "" }
        /^Sink #/ { flush(); next }
        /^[[:space:]]*Name:/ { name = $2; next }
        /^[[:space:]]*Description:/ { sub(/^[[:space:]]*Description:[[:space:]]*/, ""); desc = $0; next }
        /^[[:space:]]*Active Port:/ { port = $3; next }
        /^[[:space:]]*alsa\.name = / { match($0, /"[^"]*"/); dev = substr($0, RSTART + 1, RLENGTH - 2); next }
        END { flush() }'
    }

    # is_balanced PORT TRIPLE — does the audioBalance target cover this sink?
    is_balanced() {
      ${if !cfg.enable then "return 1"
        else if cfg.match != null then ''case "$2" in *${lib.escapeShellArg cfg.match}*) return 0 ;; esac; return 1''
        else ''[ "$1" = ${lib.escapeShellArg cfg.port} ]''}
    }

    # step_sink SINK DELTA_PERCENT
    step_sink() {
      SINK="$1"; DELTA="$2"; GAINS=""
      LINE=$(list_sinks | ${awk} -F '\t' -v s="$SINK" '$1 == s')
      if is_balanced "$(printf '%s' "$LINE" | cut -f2)" "$(printf '%s' "$LINE" | cut -f3)"; then
        GAINS="${toString cfg.left} ${toString cfg.right}"
      fi

      # Raw channel volumes (65536 = 100%), from "aux0: 49152 / 75% / ..., aux1: ...".
      RAW=$(${pactl} get-sink-volume "$SINK" 2>/dev/null | head -n1 \
        | grep -oE ': [0-9]+ /' | grep -oE '[0-9]+' | tr '\n' ' ')
      [ -z "$RAW" ] && return 1

      NEW=$(${awk} -v raw="$RAW" -v gains="$GAINS" -v peak=${toString peak} -v delta="$DELTA" 'BEGIN {
        n = split(raw, v, " "); ng = split(gains, g, " ")
        if (ng != n) ng = 0          # left/right on a sink that is not stereo: leave it
        m = 0
        for (i = 1; i <= n; i++) if (v[i] > m) m = v[i]
        target = m + delta * 65536 / 100
        top = (m > 65536) ? m : 65536   # never raise past 100%, never cut an existing boost
        if (target > top) target = top
        if (target < 0) target = 0
        out = ""
        for (i = 1; i <= n; i++) {
          if (ng)         x = target * g[i] / peak
          else if (m > 0) x = v[i] * target / m
          else            x = target
          out = out sprintf("%d ", x + 0.5)
        }
        print out
      }')
      # shellcheck disable=SC2086
      ${pactl} set-sink-volume "$SINK" $NEW
    }

    case "$1" in
      --apply-balance)
        # Right after login WirePlumber may not have created the ALSA sinks yet. Wait for
        # the balanced one itself, not just any sink: before WirePlumber runs, PipeWire
        # already answers with a placeholder "auto_null" sink, which once let this finish
        # at login having found nothing. Gives up after 30s (e.g. the monitor is off).
        balanced_sinks() {
          list_sinks | while IFS="$(printf '\t')" read -r S PORT TRIPLE; do
            is_balanced "$PORT" "$TRIPLE" && printf '%s\n' "$S"
          done
        }
        for _ in $(seq 30); do
          [ -n "$(balanced_sinks)" ] && break
          sleep 1
        done
        balanced_sinks | while read -r S; do step_sink "$S" 0; done
        exit 0 ;;
      --sink)
        SINK="$2"; shift 2 ;;
      *)
        SINK=$(${pactl} get-default-sink) ;;
    esac

    DELTA="''${1:?usage: volume-step [--sink NAME] +N|-N | --apply-balance}"
    step_sink "$SINK" "''${DELTA#+}" || exit 1
    pkill -RTMIN+11 waybar 2>/dev/null || true
  '';
in
{
  config = lib.mkMerge [
    { home.packages = [ volumeStep ]; }

    # WirePlumber already persists each sink's per-channel volumes, so this is a safety
    # net for a sink whose saved volumes were flattened (or predate the setting).
    (lib.mkIf cfg.enable {
      systemd.user.services.audio-balance = {
        Unit = {
          Description = "Apply left/right balance to ${if cfg.match != null then cfg.match else cfg.port}";
          After = [ "wireplumber.service" "pipewire-pulse.service" ];
          Wants = [ "wireplumber.service" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${volumeStep}/bin/volume-step --apply-balance";
        };
        Install.WantedBy = [ "default.target" ];
      };
    })
  ];
}

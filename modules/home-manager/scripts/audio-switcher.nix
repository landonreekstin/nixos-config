# ~/nixos-config/modules/home-manager/scripts/audio-switcher.nix
{ pkgs, lib, config, customConfig, ... }:

let
  sinkMappings = customConfig.desktop.hyprland.audioSinkMappings;

  # 0.1s silent WAV — played after sink switches to initialize WirePlumber's mixer node.
  # Without this, wpctl get-volume returns 1.00 on the new sink until real audio plays.
  initSilenceWav = pkgs.runCommand "init-silence.wav" {
    buildInputs = [ pkgs.sox ];
  } ''
    ${pkgs.sox}/bin/sox -n -r 48000 -c 2 -b 16 $out trim 0 0.1
  '';

  # Generate a shell case body that maps a "name|description|device" string to icon+label+class.
  # Used in both the switcher and cycle scripts.
  # Expects NAME, DESC and DEVNAME variables to be set; sets ICON, LABEL, CLASS.
  # Match patterns can target the sink name (e.g. "pro-output-7"), the description, or the
  # device's own name (alsa.name — the display's EDID name on HDMI/DP, e.g. "LG ULTRAGEAR").
  mappingCasesShell = lib.concatMapStrings (m: ''
    *"${m.match}"*)
      ICON="${m.icon}"; LABEL="${lib.optionalString (m.label != "") "${m.label}  "}"; CLASS="${m.class}" ;;
  '') sinkMappings;

  # Script: interactively pick an audio output via rofi (century-series themed).
  # Shows icon + label + description for each sink, then switches to the selection.
  switchAudioSinkScript = pkgs.writeShellScriptBin "switch-audio-sink" ''
    #!${pkgs.stdenv.shell}

    # Reset any active L/R flip first so we switch between real hardware sinks
    # (and the virtual flip sink never appears in the picker).
    if [ -f "$XDG_RUNTIME_DIR/audio-flip-lr.state" ]; then
      toggle-audio-flip off
    fi

    # Build a list of "name|description|device" triples from pactl. The device name is
    # alsa.name, which on HDMI/DP is the display's EDID name ("LG ULTRAGEAR") — both the
    # stable thing to match a mapping against and the only human-readable label here,
    # since every output on one GPU shares a description ("... Controller Pro 7").
    # It is printed per sink rather than on the Description line because alsa.name comes
    # later, inside the sink's Properties block.
    SINK_DATA=$(${pkgs.pulseaudio}/bin/pactl list sinks | ${pkgs.gawk}/bin/awk '
      function flush() { if (name != "") print name "|" desc "|" dev; name = ""; desc = ""; dev = "" }
      /^Sink #/ { flush(); next }
      /^[[:space:]]*Name:/ { name = $2; next }
      /^[[:space:]]*Description:/ {
        sub(/^[[:space:]]*Description:[[:space:]]*/, "")
        desc = $0; next
      }
      /^[[:space:]]*alsa\.name = / {
        match($0, /"[^"]*"/)
        dev = substr($0, RSTART + 1, RLENGTH - 2); next
      }
      END { flush() }
    ' | grep -v '^flip-lr-sink|')

    if [ -z "$SINK_DATA" ]; then
      exit 1
    fi

    # Build display lines for rofi: "ICON LABEL  device-or-description"
    DISPLAY_LINES=""
    while IFS='|' read -r NAME DESC DEVNAME; do
      ICON="󰕾"; LABEL=""; CLASS="default"
      case "$NAME|$DESC|$DEVNAME" in
        ${mappingCasesShell}
        *) ICON="󰕾"; LABEL=""; CLASS="default" ;;
      esac
      DISPLAY_LINES="$DISPLAY_LINES$ICON $LABEL''${DEVNAME:-$DESC}\n"
    done <<< "$SINK_DATA"

    # Present rofi menu
    CHOSEN=$(printf '%b' "$DISPLAY_LINES" | ${pkgs.rofi}/bin/rofi -dmenu -p "SELECT OUTPUT" -i)

    if [ -z "$CHOSEN" ]; then
      exit 0
    fi

    # Find the sink name corresponding to the chosen display line
    # Match by stripping the icon/label prefix and comparing descriptions
    CHOSEN_SINK=""
    while IFS='|' read -r NAME DESC DEVNAME; do
      ICON="󰕾"; LABEL=""; CLASS="default"
      case "$NAME|$DESC|$DEVNAME" in
        ${mappingCasesShell}
        *) ICON="󰕾"; LABEL=""; CLASS="default" ;;
      esac
      DISPLAY="$ICON $LABEL''${DEVNAME:-$DESC}"
      if [ "$DISPLAY" = "$CHOSEN" ]; then
        CHOSEN_SINK="$NAME"
        break
      fi
    done <<< "$SINK_DATA"

    if [ -n "$CHOSEN_SINK" ]; then
      ${pkgs.pulseaudio}/bin/pactl set-default-sink "$CHOSEN_SINK"
      # Move all active streams to the new sink
      ${pkgs.pulseaudio}/bin/pactl list short sink-inputs | ${pkgs.gawk}/bin/awk '{print $1}' | while read -r INPUT_ID; do
        ${pkgs.pulseaudio}/bin/pactl move-sink-input "$INPUT_ID" "$CHOSEN_SINK"
      done
      # Initialize WirePlumber's mixer node for the new sink so wpctl get-volume works
      # immediately (without this, the widget shows 100% until real audio plays through it)
      ${pkgs.pulseaudio}/bin/paplay --volume=0 ${initSilenceWav} 2>/dev/null
      # Signal waybar to refresh the audio widget
      pkill -RTMIN+11 waybar 2>/dev/null || true
    fi
  '';

  # Script: cycle to the next or previous audio output sink.
  # Usage: cycle-audio-sink next|prev
  cycleAudioSinkScript = pkgs.writeShellScriptBin "cycle-audio-sink" ''
    #!${pkgs.stdenv.shell}

    DIRECTION="''${1:-next}"

    # Reset any active L/R flip first so we cycle between real hardware sinks.
    if [ -f "$XDG_RUNTIME_DIR/audio-flip-lr.state" ]; then
      toggle-audio-flip off
    fi

    # Get ordered list of sink names (exclude monitor sources and the flip sink)
    SINKS=$(${pkgs.pulseaudio}/bin/pactl list sinks short | ${pkgs.gawk}/bin/awk '{print $2}' | grep -v '\.monitor$' | grep -v '^flip-lr-sink$')

    if [ -z "$SINKS" ]; then
      exit 1
    fi

    SINK_COUNT=$(echo "$SINKS" | wc -l)
    if [ "$SINK_COUNT" -le 1 ]; then
      exit 0  # Nothing to cycle
    fi

    CURRENT=$(${pkgs.pulseaudio}/bin/pactl get-default-sink 2>/dev/null)

    # Find current index (0-based)
    CURRENT_IDX=0
    IDX=0
    while IFS= read -r SINK; do
      if [ "$SINK" = "$CURRENT" ]; then
        CURRENT_IDX=$IDX
      fi
      IDX=$((IDX + 1))
    done <<< "$SINKS"

    # Compute next index with wrap
    if [ "$DIRECTION" = "prev" ]; then
      NEXT_IDX=$(( (CURRENT_IDX - 1 + SINK_COUNT) % SINK_COUNT ))
    else
      NEXT_IDX=$(( (CURRENT_IDX + 1) % SINK_COUNT ))
    fi

    # Select the sink at NEXT_IDX
    NEXT_SINK=$(echo "$SINKS" | ${pkgs.gnused}/bin/sed -n "$((NEXT_IDX + 1))p")

    if [ -n "$NEXT_SINK" ]; then
      ${pkgs.pulseaudio}/bin/pactl set-default-sink "$NEXT_SINK"
      # Move all active streams to the new sink
      ${pkgs.pulseaudio}/bin/pactl list short sink-inputs | ${pkgs.gawk}/bin/awk '{print $1}' | while read -r INPUT_ID; do
        ${pkgs.pulseaudio}/bin/pactl move-sink-input "$INPUT_ID" "$NEXT_SINK"
      done
      # Initialize WirePlumber's mixer node for the new sink so wpctl get-volume works
      # immediately (without this, the widget shows 100% until real audio plays through it)
      ${pkgs.pulseaudio}/bin/paplay --volume=0 ${initSilenceWav} 2>/dev/null
      # Signal waybar to refresh the audio widget
      pkill -RTMIN+11 waybar 2>/dev/null || true
    fi
  '';

in
{
  home.packages = [
    switchAudioSinkScript
    cycleAudioSinkScript
    pkgs.pulseaudio  # For pactl commands
    pkgs.gawk
    pkgs.gnused
    # rofi is managed by hyprland/functional.nix
  ];
}

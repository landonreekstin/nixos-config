# ~/nixos-config/modules/home-manager/scripts/audio-switcher.nix
{ pkgs, lib, config, customConfig, ... }:

let
  sinkMappings = customConfig.desktop.hyprland.audioSinkMappings;

  # Generate a shell function body that maps a description string to icon+label+class.
  # Used in both the switcher and cycle scripts.
  # Expects DESC variable to be set; sets ICON, LABEL, CLASS.
  mappingCasesShell = lib.concatMapStrings (m: ''
    *"${m.match}"*)
      ICON="${m.icon}"; LABEL="${lib.optionalString (m.label != "") "${m.label}  "}"; CLASS="${m.class}" ;;
  '') sinkMappings;

  # Script: interactively pick an audio output via rofi (century-series themed).
  # Shows icon + label + description for each sink, then switches to the selection.
  switchAudioSinkScript = pkgs.writeShellScriptBin "switch-audio-sink" ''
    #!${pkgs.stdenv.shell}

    # Build a list of "name|description" pairs from pactl
    SINK_DATA=$(${pkgs.pulseaudio}/bin/pactl list sinks | ${pkgs.gawk}/bin/awk '
      /^\s*Name:/ { name = $2 }
      /^\s*Description:/ {
        sub(/^\s*Description:\s*/, "")
        desc = $0
        print name "|" desc
      }
    ')

    if [ -z "$SINK_DATA" ]; then
      exit 1
    fi

    # Build display lines for rofi: "ICON LABEL  description  (name)"
    DISPLAY_LINES=""
    while IFS='|' read -r NAME DESC; do
      ICON="󰕾"; LABEL=""; CLASS="default"
      case "$DESC" in
        ${mappingCasesShell}
        *) ICON="󰕾"; LABEL=""; CLASS="default" ;;
      esac
      DISPLAY_LINES="$DISPLAY_LINES$ICON $LABEL$DESC\n"
    done <<< "$SINK_DATA"

    # Present rofi menu
    CHOSEN=$(printf '%b' "$DISPLAY_LINES" | ${pkgs.rofi}/bin/rofi -dmenu -p "SELECT OUTPUT" -i)

    if [ -z "$CHOSEN" ]; then
      exit 0
    fi

    # Find the sink name corresponding to the chosen display line
    # Match by stripping the icon/label prefix and comparing descriptions
    CHOSEN_SINK=""
    while IFS='|' read -r NAME DESC; do
      ICON="󰕾"; LABEL=""; CLASS="default"
      case "$DESC" in
        ${mappingCasesShell}
        *) ICON="󰕾"; LABEL=""; CLASS="default" ;;
      esac
      DISPLAY="$ICON $LABEL$DESC"
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
      # Signal waybar to refresh the audio widget
      pkill -RTMIN+11 waybar 2>/dev/null || true
    fi
  '';

  # Script: cycle to the next or previous audio output sink.
  # Usage: cycle-audio-sink next|prev
  cycleAudioSinkScript = pkgs.writeShellScriptBin "cycle-audio-sink" ''
    #!${pkgs.stdenv.shell}

    DIRECTION="''${1:-next}"

    # Get ordered list of sink names (exclude monitor sources)
    SINKS=$(${pkgs.pulseaudio}/bin/pactl list sinks short | ${pkgs.gawk}/bin/awk '{print $2}' | grep -v '\.monitor$')

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

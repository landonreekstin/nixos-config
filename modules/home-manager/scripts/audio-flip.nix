# ~/nixos-config/modules/home-manager/scripts/audio-flip.nix
{ pkgs, lib, config, customConfig, ... }:

let
  # 0.1s silent WAV — played after a sink switch to initialize WirePlumber's mixer
  # node so `wpctl get-volume` (and the waybar scroll handlers) track immediately.
  # Same pattern as audio-switcher.nix.
  initSilenceWav = pkgs.runCommand "init-silence.wav" {
    buildInputs = [ pkgs.sox ];
  } ''
    ${pkgs.sox}/bin/sox -n -r 48000 -c 2 -b 16 $out trim 0 0.1
  '';

  # State marker: existence = flip is ON, contents = the wrapped real sink name.
  # Lives in $XDG_RUNTIME_DIR so it clears on logout (won't outlive the loopback).
  stateFile = "\"$XDG_RUNTIME_DIR/audio-flip-lr.state\"";

  # Script: toggle a left/right channel swap on the current default output.
  #
  # Mechanism: spawn a transient pw-loopback that presents a virtual sink
  # "flip-lr-sink" (a plain stereo pass-through), with its playback stream's
  # autoconnect disabled. We then manually cross-link the loopback's output
  # ports to the real sink's input ports (FL -> R, FR -> L). Doing the swap with
  # explicit pw-link (rather than channel-position relabeling) makes it work on
  # any sink: HDMI/DP sinks expose unpositioned AUX ports while Bluetooth/analog
  # sinks expose named FL/FR ports, and position tricks only swap the former.
  # Finally we make flip-lr-sink the default and move existing streams onto it.
  #
  # Usage: toggle-audio-flip [on|off|toggle]  (default: toggle)
  toggleAudioFlipScript = pkgs.writeShellScriptBin "toggle-audio-flip" ''
    #!${pkgs.stdenv.shell}

    STATE=${stateFile}
    SINK_NAME="flip-lr-sink"
    PLAYBACK_NAME="flip-lr-playback"
    UNIT="audio-flip-lr"
    ACTION="''${1:-toggle}"

    flip_off() {
      # Restore the wrapped real sink, move streams back, tear down the loopback.
      REAL=$(cat "$STATE" 2>/dev/null)
      if [ -n "$REAL" ]; then
        ${pkgs.pulseaudio}/bin/pactl set-default-sink "$REAL" 2>/dev/null
        ${pkgs.pulseaudio}/bin/pactl list short sink-inputs | ${pkgs.gawk}/bin/awk '{print $1}' | while read -r ID; do
          ${pkgs.pulseaudio}/bin/pactl move-sink-input "$ID" "$REAL" 2>/dev/null
        done
      fi
      ${pkgs.systemd}/bin/systemctl --user stop "$UNIT" 2>/dev/null || true
      [ -n "$REAL" ] && ${pkgs.pulseaudio}/bin/paplay --volume=0 -d "$REAL" ${initSilenceWav} 2>/dev/null
      rm -f "$STATE"
      pkill -RTMIN+11 waybar 2>/dev/null || true
    }

    flip_on() {
      REAL=$(${pkgs.pulseaudio}/bin/pactl get-default-sink 2>/dev/null)
      # Refuse to wrap ourselves (defensive against a stale default).
      if [ -z "$REAL" ] || [ "$REAL" = "$SINK_NAME" ]; then
        exit 0
      fi

      # Snapshot existing app streams BEFORE the loopback exists, so we never move
      # the loopback's own playback stream (which would create a feedback loop).
      STREAMS=$(${pkgs.pulseaudio}/bin/pactl list short sink-inputs | ${pkgs.gawk}/bin/awk '{print $1}')

      # Plain stereo pass-through sink; playback stream must NOT autoconnect so we
      # can wire the crossed links ourselves (WirePlumber would otherwise add
      # straight FL->FL / FR->FR links and undo the swap).
      ${pkgs.systemd}/bin/systemd-run --user --unit="$UNIT" --collect \
        ${pkgs.pipewire}/bin/pw-loopback \
          --capture-props="media.class=Audio/Sink node.name=$SINK_NAME node.description=Flip-L/R audio.position=[FL,FR]" \
          --playback-props="node.name=$PLAYBACK_NAME node.autoconnect=false node.dont-reconnect=true audio.position=[FL,FR]"

      # Wait for the virtual sink AND the playback node's two output ports.
      for _ in $(seq 1 25); do
        if ${pkgs.pulseaudio}/bin/pactl list short sinks | grep -q "$SINK_NAME" \
           && [ "$(${pkgs.pipewire}/bin/pw-link -o 2>/dev/null | ${pkgs.gawk}/bin/awk -v n="$PLAYBACK_NAME:" 'index($0,n)==1' | wc -l)" -ge 2 ]; then
          break
        fi
        sleep 0.2
      done

      # Enumerate the loopback outputs and the real sink's inputs (sorted so
      # index 0 = left, index 1 = right for both), then cross-link to swap.
      mapfile -t OUTS < <(${pkgs.pipewire}/bin/pw-link -o 2>/dev/null | ${pkgs.gawk}/bin/awk -v n="$PLAYBACK_NAME:" 'index($0,n)==1' | sort)
      mapfile -t INS  < <(${pkgs.pipewire}/bin/pw-link -i 2>/dev/null | ${pkgs.gawk}/bin/awk -v n="$REAL:" 'index($0,n)==1' | sort)

      if [ "''${#OUTS[@]}" -lt 2 ] || [ "''${#INS[@]}" -lt 2 ]; then
        ${pkgs.systemd}/bin/systemctl --user stop "$UNIT" 2>/dev/null || true
        exit 1
      fi

      # Crossed links = the swap. Also defensively drop any straight links.
      ${pkgs.pipewire}/bin/pw-link -d "''${OUTS[0]}" "''${INS[0]}" 2>/dev/null || true
      ${pkgs.pipewire}/bin/pw-link -d "''${OUTS[1]}" "''${INS[1]}" 2>/dev/null || true
      ${pkgs.pipewire}/bin/pw-link "''${OUTS[0]}" "''${INS[1]}"
      ${pkgs.pipewire}/bin/pw-link "''${OUTS[1]}" "''${INS[0]}"

      ${pkgs.pulseaudio}/bin/pactl set-default-sink "$SINK_NAME"
      for ID in $STREAMS; do
        ${pkgs.pulseaudio}/bin/pactl move-sink-input "$ID" "$SINK_NAME" 2>/dev/null
      done
      # Initialize WirePlumber's mixer node for the new default sink.
      ${pkgs.pulseaudio}/bin/paplay --volume=0 ${initSilenceWav} 2>/dev/null
      printf '%s' "$REAL" > "$STATE"
      pkill -RTMIN+11 waybar 2>/dev/null || true
    }

    case "$ACTION" in
      on)  [ -f "$STATE" ] || flip_on ;;
      off) [ -f "$STATE" ] && flip_off ;;
      *)   if [ -f "$STATE" ]; then flip_off; else flip_on; fi ;;
    esac
  '';

in
{
  home.packages = [
    toggleAudioFlipScript
    pkgs.pipewire     # pw-loopback
    pkgs.pulseaudio   # pactl / paplay
    pkgs.systemd      # systemd-run / systemctl --user
    pkgs.gawk
  ];
}

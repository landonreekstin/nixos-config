# ~/nixos-config/modules/home-manager/scripts/audio-switcher.nix
{ pkgs, lib, config, ... }:

let
  # Script to switch audio output sink
  # Dependencies: pactl, wofi, awk (from pkgs.gawk), sed (from pkgs.gnused)
  switchAudioSinkScript = pkgs.writeShellScriptBin "switch-audio-sink" ''
    #!${pkgs.stdenv.shell}

    SINK_OPTIONS=$(${pkgs.pulseaudio}/bin/pactl list sinks short | ${pkgs.gawk}/bin/awk '{print $2}' | ${pkgs.gnused}/bin/sed 's/\.monitor$//' | sort -u)

    if [ -z "$SINK_OPTIONS" ]; then
        echo "No sinks found." | ${pkgs.wofi}/bin/wofi --dmenu --prompt "Error"
        exit 1
    fi

    CHOSEN_SINK=$(echo -e "$SINK_OPTIONS" | ${pkgs.wofi}/bin/wofi --dmenu --prompt "Select Audio Output:")

    if [ -n "$CHOSEN_SINK" ]; then
        ${pkgs.pulseaudio}/bin/pactl set-default-sink "$CHOSEN_SINK"
        echo "Default sink set to $CHOSEN_SINK"

        ${pkgs.pulseaudio}/bin/pactl list short sink-inputs | ${pkgs.gawk}/bin/awk '{print $1}' | while read -r INPUT_ID; do
            ${pkgs.pulseaudio}/bin/pactl move-sink-input "$INPUT_ID" "$CHOSEN_SINK"
        done
        echo "Moved active streams to $CHOSEN_SINK"
    else
        echo "No sink selected."
    fi
  '';
in
{
  # Expose the script path for other modules to use, if needed, though direct
  # inclusion in home.packages is usually sufficient for PATH.
  # config.custom.scripts.switchAudioSink = switchAudioSinkScript; # Optional if you want to reference it by a config option

  home.packages = [
    switchAudioSinkScript # Makes the script available in PATH
    pkgs.pulseaudio       # For pactl commands
    pkgs.gawk             # Explicitly include gawk for awk
    pkgs.gnused           # Explicitly include gnused for sed
    # wofi is managed by hyprland.nix or a global packages list,
    # but referencing via config.programs.wofi.package is robust.
  ];
}
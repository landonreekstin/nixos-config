# ~/nixos-config/modules/home-manager/themes/windows7-xfce/sounds.nix
{ config, pkgs, lib, customConfig, ... }:

# Windows 7 event sounds. The "Windows 7" libcanberra theme (windows7-xfce-sounds) is
# made discoverable under ~/.local/share/sounds; xsettings enables event sounds and selects
# it, so libcanberra-using apps play the mapped Win7 sounds (errors, notifications, device
# add/remove, etc.). The iconic startup jingle isn't an automatic event, so a login autostart
# plays desktop-login explicitly.
let
  win7XfceCondition = lib.elem "xfce" customConfig.desktop.environments
    && customConfig.homeManager.themes.xfce == "windows7";

  # The jingle with 5s of leading silence prepended (sox `pad <start> <end>`). The default
  # sink here is DP/HDMI audio (pro-output-8 → monitor → 3.5mm), and a cold monitor takes
  # several seconds to lock the DP audio stream before any sound reaches the jack. Priming
  # with a *separate* short play didn't work — the gap between two paplay streams let the
  # monitor drop the lock, so the jingle re-locked from scratch and only its final chord
  # survived. Prepending the silence into ONE continuous stream keeps the device fed while
  # it warms up; the inaudible lead absorbs the whole cold-lock window.
  primedJingle = pkgs.runCommand "win7-login-primed.wav" { buildInputs = [ pkgs.sox ]; } ''
    ${pkgs.sox}/bin/sox "${pkgs.windows7-xfce-sounds}/share/sounds/Windows 7/stereo/desktop-login.wav" $out pad 5 0
  '';

  # Play the startup jingle to the default sink on login. Two robustness measures learned
  # the hard way on gaming-pc:
  #  1. Autostart can fire before audio is up / while the default is a stale virtual sink,
  #     so wait for a real, currently-active default sink first (skip flip-lr-sink/auto_null).
  #  2. WirePlumber's stream-restore can persist mute=yes for the "paplay" application name,
  #     silencing every play regardless of --volume. So after launching, find THIS stream by
  #     its process id and explicitly unmute + set full volume. (No-op on hosts without the
  #     saved-mute quirk, e.g. blaney-pc.)
  loginSound = pkgs.writeShellScript "win7-login-sound" ''
    pactl=${pkgs.pulseaudio}/bin/pactl
    wav="${primedJingle}"

    for _ in $(seq 1 30); do
      sink=$("$pactl" get-default-sink 2>/dev/null)
      case "$sink" in
        "" | "flip-lr-sink" | "auto_null" ) sleep 0.5 ;;
        * ) if "$pactl" list short sinks 2>/dev/null | ${pkgs.gawk}/bin/awk '{print $2}' | grep -qx "$sink"; then break; fi; sleep 0.5 ;;
      esac
    done

    # Single continuous stream: the 5s of silence baked into $wav warms the cold DP/HDMI
    # sink (see primedJingle above) so the jingle proper is never clipped.
    ${pkgs.pulseaudio}/bin/paplay "$wav" &
    pid=$!
    for _ in $(seq 1 20); do
      id=$("$pactl" list sink-inputs 2>/dev/null | ${pkgs.gawk}/bin/awk -v pid="$pid" '
        /^Sink Input #/{id=$3; sub("#","",id)}
        /application.process.id = /{ if ($0 ~ ("\"" pid "\"")) {print id; exit} }')
      if [ -n "$id" ]; then
        "$pactl" set-sink-input-mute "$id" 0
        "$pactl" set-sink-input-volume "$id" 100%
        break
      fi
      sleep 0.15
    done
    wait "$pid"
  '';
in {
  config = lib.mkIf win7XfceCondition {

    # Discoverable-by-name (canberra searches XDG data dirs incl. ~/.local/share/sounds).
    home.file.".local/share/sounds/Windows 7".source =
      "${pkgs.windows7-xfce-sounds}/share/sounds/Windows 7";

    xdg.configFile."autostart/win7-login-sound.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Windows 7 login sound
      Exec=${loginSound}
      OnlyShowIn=XFCE;
      X-XFCE-Autostart-enabled=true
    '';
  };
}

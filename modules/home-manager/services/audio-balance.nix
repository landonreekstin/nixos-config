# ~/nixos-config/modules/home-manager/services/audio-balance.nix
{ config, pkgs, lib, customConfig, ... }:
let
  cfg = customConfig.homeManager.services.audioBalance;
  pactl = "${pkgs.pulseaudio}/bin/pactl";

  # Scale the louder channel to the sink's current loudest channel, the other one
  # proportionally — so re-running it never drifts the overall volume.
  balanceScript = pkgs.writeShellScript "audio-balance" ''
    # WirePlumber may not have created the sinks yet right after login.
    for _ in $(seq 30); do
      ${pactl} list short sinks 2>/dev/null | grep -q . && break
      sleep 1
    done

    ${pactl} list sinks | ${pkgs.gawk}/bin/awk '
      /^\tName: /        { name = $2 }
      /^\tVolume: /      { vol = $0 }
      /^\tActive Port: / { if ($3 == "${cfg.port}") print name "\t" vol }
    ' | while IFS="$(printf '\t')" read -r sink vol; do
      # Raw (0–65536) per-channel values from "front-left: 49149 / 75% / ...".
      base=$(printf '%s\n' "$vol" | grep -oE ': [0-9]+ /' | tr -dc '0-9\n' | sort -n | tail -1)
      [ -n "$base" ] || continue
      max=${toString (lib.max cfg.left cfg.right)}
      ${pactl} set-sink-volume "$sink" \
        $(( base * ${toString cfg.left} / max )) \
        $(( base * ${toString cfg.right} / max ))
    done
  '';
in
{
  config = lib.mkIf cfg.enable {
    systemd.user.services.audio-balance = {
      Unit = {
        Description = "Apply left/right balance to ${cfg.port}";
        After = [ "wireplumber.service" "pipewire-pulse.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${balanceScript}";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}

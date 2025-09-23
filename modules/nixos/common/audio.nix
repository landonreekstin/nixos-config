# ~/nixos-config/modules/nixos/services/audio.nix
{ config, pkgs, lib, ... }:

{
  # Disable PulseAudio (replaced by PipeWire's implementation)
  services.pulseaudio.enable = false;

  # Enable PipeWire
  security.rtkit.enable = true; # Recommended for PipeWire
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true; # Enable PulseAudio emulation
    # jack.enable = true; # Enable JACK emulation if needed
  };

  environment.systemPackages = with pkgs; [
    pavucontrol
  ];

  hardware.bluetooth.enable = true;
}

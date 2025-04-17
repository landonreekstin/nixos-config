# ~/nixos-config/modules/nixos/services/pipewire.nix
{ config, pkgs, lib, ... }:

{
  # Disable PulseAudio (replaced by PipeWire's implementation)
  services.pulseaudio.enable = false;
  hardware.pulseaudio.enable = false; # Just to be sure

  # Enable PipeWire
  security.rtkit.enable = true; # Recommended for PipeWire
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true; # Enable PulseAudio emulation
    # jack.enable = true; # Enable JACK emulation if needed
  };
}

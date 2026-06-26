# ~/nixos-config/modules/nixos/homelab/wyoming.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.wyoming;
in
{
  config = lib.mkIf cfg.enable {
    # wyoming-satellite's systemd service only puts alsa-utils in PATH by default;
    # extend it with sox for the TTS sound output conversion pipe.
    systemd.services.wyoming-satellite.path = [ pkgs.sox ];
    # The nixpkgs module sets PrivateUsers=true and PrivateDevices=true + DevicePolicy=closed,
    # which (a) breaks GID mapping for SupplementaryGroups=audio and (b) hides /dev/snd/*
    # entirely from the service. Both must be disabled for ALSA mic/speaker access.
    systemd.services.wyoming-satellite.serviceConfig = {
      PrivateUsers = lib.mkForce false;
      PrivateDevices = lib.mkForce false;
      DevicePolicy = lib.mkForce "auto";
    };

    users.users.wyoming-satellite = {
      isSystemUser = true;
      group = "wyoming-satellite";
    };
    users.groups.wyoming-satellite = {};

    services.wyoming.satellite = {
      enable = true;
      user = "wyoming-satellite";
      name = cfg.satellite.name;
      # USB mic via plughw (ALSA plug layer handles any rate/format conversion).
      # Record at 16000 Hz directly — the TKGOU mic natively supports this rate.
      # No pipe needed, so no /bin/sh -c wrapper required.
      microphone.command = "arecord -D ${cfg.satellite.micDevice} -r 16000 -c 1 -f S16_LE -t raw";
      # HDA Intel PCH (hw:0,0): convert mono 22050 Hz to stereo 48000 Hz via sox
      # VERIFY device index with `aplay -l` after install
      sound.command = "/bin/sh -c 'sox -t raw -r 22050 -c 1 -e signed-integer -b 16 - -t raw -r 48000 -c 2 -e signed-integer -b 16 - | aplay -D ${cfg.satellite.sndDevice} -r 48000 -c 2 -f S16_LE -t raw'";
      sounds.awake = cfg.satellite.awakeWav;
      sounds.done = cfg.satellite.doneWav;
      extraArgs = [
        "--wake-uri" "tcp://127.0.0.1:10400"
        "--wake-word-name" cfg.satellite.wakeWord
      ];
    };

    services.wyoming.faster-whisper.servers."home" = {
      enable = true;
      uri = "tcp://127.0.0.1:10300";
      model = cfg.whisper.model;
      language = cfg.whisper.language;
    };

    services.wyoming.piper.servers."home" = {
      enable = true;
      uri = "tcp://127.0.0.1:10200";
      voice = cfg.piper.voice;
    };

    services.wyoming.openwakeword = {
      enable = true;
      uri = "tcp://127.0.0.1:10400";
      # preloadModels removed in wyoming-openwakeword 2.0; wake word selected by satellite
    };

    # home-assistant starts before Wyoming services are fully ready by default,
    # causing its wyoming config entries to fail. Ordering it after the Wyoming
    # units ensures clean connections on every boot.
    systemd.services.home-assistant = {
      wants = [
        "wyoming-satellite.service"
        "wyoming-openwakeword.service"
        "wyoming-faster-whisper-home.service"
        "wyoming-piper-home.service"
      ];
      after = [
        "wyoming-satellite.service"
        "wyoming-openwakeword.service"
        "wyoming-faster-whisper-home.service"
        "wyoming-piper-home.service"
      ];
    };
  };
}

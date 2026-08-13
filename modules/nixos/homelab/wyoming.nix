# ~/nixos-config/modules/nixos/homelab/wyoming.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.wyoming;
in
{
  options.customConfig.homelab.wyoming = with lib; {
    enable = mkEnableOption "Wyoming voice pipeline (Whisper + Piper + openWakeWord + satellite)";
    satellite = {
      name = mkOption {
        type = types.str;
        default = "home";
        description = "Friendly name for the Wyoming satellite shown in Home Assistant.";
      };
      micDevice = mkOption {
        type = types.str;
        default = "hw:1,0";
        description = "ALSA device string for the microphone. Verify with `arecord -l` after install.";
      };
      sndDevice = mkOption {
        type = types.str;
        default = "hw:0,0";
        description = "ALSA device string for speaker output. Verify with `aplay -l` after install.";
      };
      awakeWav = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to WAV played when the wake word fires. Null uses wyoming-satellite's built-in sound.";
      };
      doneWav = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to WAV played when TTS finishes. Null uses wyoming-satellite's built-in sound.";
      };
      wakeWord = mkOption {
        type = types.str;
        default = "hey_jarvis";
        description = "openWakeWord model name passed to wyoming-satellite (e.g. hey_jarvis, ok_nabu).";
      };
      noiseSuppression = mkOption {
        type = types.ints.between 0 4;
        default = 0;
        description = "WebRTC noise-suppression level on the mic (0 = off, 4 = max — may distort).";
      };
      autoGain = mkOption {
        type = types.ints.between 0 31;
        default = 0;
        description = "Automatic gain control in dbFS (0 = off, 31 = loudest). Off is usually best in noisy rooms.";
      };
    };
    openwakeword = {
      threshold = mkOption {
        type = types.numbers.between 0.0 1.0;
        default = 0.5;
        description = "openWakeWord activation threshold (0.0-1.0). Higher = fewer false triggers.";
      };
      triggerLevel = mkOption {
        type = types.ints.unsigned;
        default = 1;
        description = "Consecutive activations required before a wake event fires. Higher = fewer detections.";
      };
    };
    whisper = {
      model = mkOption {
        type = types.str;
        default = "tiny-int8";
        description = "Whisper model variant (tiny, base, small, medium; append -int8 for quantized).";
      };
      language = mkOption {
        type = types.str;
        default = "en";
        description = "Language code for Whisper STT.";
      };
    };
    piper = {
      voice = mkOption {
        type = types.str;
        default = "en_US-lessac-medium";
        description = "Piper TTS voice identifier (e.g. en_US-lessac-medium).";
      };
    };
  };

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
      microphone.noiseSuppression = cfg.satellite.noiseSuppression;
      microphone.autoGain = cfg.satellite.autoGain;
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
      threshold = cfg.openwakeword.threshold;
      triggerLevel = cfg.openwakeword.triggerLevel;
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

# ~/nixos-config/hosts/mini-server/homelab.nix
{ config, pkgs, lib, unstablePkgs, ... }:

{
  customConfig.homelab = {
    nasClient = {
      enable = true;
      # NAS is on this same server subnet post-migration; mount Samba directly
      # rather than via the firewall's legacy 192.168.1.76 alias (which doesn't
      # forward 445/139). Traffic stays within the trusted server segment.
      serverAddress = "192.168.100.76";
    };

    # Reach the NAS nix binary cache directly on the server subnet (the legacy
    # 192.168.1.76 alias isn't reachable from behind the firewall).
    nixCache.clientHost = "192.168.100.76";

    vaultwarden.enable = true;

    homeAssistant = {
      enable = true;
      # nixpkgs 25.11 ships HA 2025.11.x; backup requires >= 2026.2.1 — use unstable
      package = unstablePkgs.home-assistant;
    };

    wyoming = {
      enable = true;
      satellite.name = "mini-server";
      # Reference cards by ALSA card *name* (stable) rather than numeric index —
      # USB re-enumeration on reboot has swapped card 0/1 twice now.
      # MIC = Generalplus USB mic, PCH = onboard HDA Intel (analog line-out).
      satellite.micDevice = "plughw:MIC,0";
      satellite.sndDevice = "plughw:PCH,0";
      satellite.awakeWav = "${../../modules/nixos/homelab/wyoming-sounds/awake.wav}";
      satellite.doneWav = "${../../modules/nixos/homelab/wyoming-sounds/done.wav}";
      # ok_nabu is a more robust openWakeWord model than hey_jarvis and handles most
      # false-trigger rejection on its own; WebRTC noise suppression covers TV/background,
      # and threshold/trigger-level are kept near defaults for good far-field response.
      satellite.wakeWord = "ok_nabu";
      satellite.noiseSuppression = 2;
      satellite.autoGain = 0;
      openwakeword.threshold = 0.6;
      openwakeword.triggerLevel = 1;
      whisper.model = "small-int8";
      whisper.language = "en";
      piper.voice = "en_US-lessac-medium";
    };

    gameServers = {
      astroneer.enable = true;
      minecraftSurvival.enable = true;
      minecraftMinigames.enable = true;
      minecraftBedrock.enable = true;
    };

    gameControl.enable = true;

    gameBackup.enable = true;

    localCA.enable = true;
    localCA.trustCA = true;

    reverseProxy.enable = true;
  };

  # State dirs for game-control watchdog idle timers and game server volumes
  systemd.tmpfiles.rules = [
    "d /var/lib/game-control 0755 root root - -"
    "d /var/lib/game-servers 0755 root root - -"
  ];

  # Version-control HA config files alongside this host config.
  # The NixOS HA module manages configuration.yaml the same way.
  environment.etc."home-assistant/automations.yaml".source = ./home-assistant/automations.yaml;
  systemd.services.home-assistant.preStart = lib.mkAfter ''
    ln -sf /etc/home-assistant/automations.yaml /var/lib/hass/automations.yaml
  '';
}

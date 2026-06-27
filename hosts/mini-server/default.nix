# ~/nixos-config/hosts/mini-server/default.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/default.nix
    ./disko-config.nix
  ];

  # Kernel 6.17 caused a kernel panic on this hardware; 6.14 reached EOL in nixpkgs.
  # Pin to 6.12 LTS (maintained through Dec 2026) — re-test with newer kernels periodically.
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_6_12;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # GNOME desktop — keep for TV use; flip to headless when a dedicated TV device exists.
  # customConfig.desktop doesn't model GNOME yet; configure directly here.
  services.xserver.enable = true;
  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true;
  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "gnome-session";
  services.xrdp.openFirewall = true;

  # Prevent GNOME/logind from suspending or hibernating — this is a server.
  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';
  services.logind.settings.Login = {
    IdleAction = "ignore";
    HandleSuspendKey = "ignore";
    HandleHibernateKey = "ignore";
    HandleLidSwitch = "ignore";
  };

  # State dirs for game-control watchdog idle timers and game server volumes
  systemd.tmpfiles.rules = [
    "d /var/lib/game-control 0755 root root - -"
    "d /var/lib/game-servers 0755 root root - -"
  ];

  customConfig = {

    user = {
      name = "lando";
      email = "landonreekstin@gmail.com";
      shell.bash.color = "yellow";
      sopsPassword = true;
    };

    system = {
      hostName = "mini-server";
      stateVersion = "25.05";
      timeZone = "America/Chicago";
      locale = "en_US.UTF-8";
    };

    networking = {
      networkmanager.enable = false;
      staticIP = {
        enable = true;
        interface = "enp1s0";
        address = "192.168.100.103";
        gateway = "192.168.100.1";
      };
      firewall.enable = false;
    };

    # Headless from customConfig perspective; GNOME is configured via raw NixOS options above
    desktop = {
      environments = [ "none" ];
      displayManager = {
        enable = false;
        type = "none";
      };
    };

    homeManager = {
      enable = true;
      themes = {
        kde = "none";
        hyprland = "none";
      };
    };

    packages = {
      nixos = with pkgs; [ wget git vim htop claude-code restic ];
      homeManager = [];
    };

    programs.claudeCode.enable = true;

    profiles = {
      gaming.enable = false;
      development.kernel.enable = false;
      development.fpga-ice40.enable = false;
    };

    services = {
      ssh.enable = true;
      vscodeServer.enable = true;
    };

    homelab = {
      nasClient.enable = true;

      vaultwarden.enable = true;

      homeAssistant = {
        enable = true;
        # nixpkgs 25.11 ships HA 2025.11.x; backup requires >= 2026.2.1 — use unstable
        package = unstablePkgs.home-assistant;
      };

      wyoming = {
        enable = true;
        satellite.name = "mini-server";
        satellite.micDevice = "plughw:0,0";
        satellite.sndDevice = "hw:1,0";
        satellite.awakeWav = "${../../modules/nixos/homelab/wyoming-sounds/awake.wav}";
        satellite.doneWav = "${../../modules/nixos/homelab/wyoming-sounds/done.wav}";
        whisper.model = "tiny-int8";
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
    };
  };

  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    extraSpecialArgs = { inherit inputs unstablePkgs; customConfig = config.customConfig; };
    users.${config.customConfig.user.name} = {};
  };
}

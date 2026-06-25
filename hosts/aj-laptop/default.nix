# ~/nixos-config/hosts/aj-laptop/default.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }:

{
  imports = [
    # Import the hardware profile for the Zephyrus G14 (GA401 model)
    inputs.nixos-hardware.nixosModules.asus-zephyrus-ga401

    # Hardware-specific configuration generated for this host.
    # This file will be replaced with machine-generated output during installation.
    ./hardware-configuration.nix

    # Declarative disk layout (managed by disko)
    ./disko-config.nix

    # Top level nixos modules import.
    ../../modules/nixos/default.nix
  ];

  # === AJ Laptop (Asus ROG Zephyrus G14) ===
  customConfig = {

    user = {
      name = "aj";
      email = "";
      sopsPassword = true;
    };

    bootloader = {
      quietBoot = true;
    };

    system = {
      hostName = "aj-laptop";
      stateVersion = "25.11"; # DO NOT CHANGE
      timeZone = "America/Chicago";
      locale = "en_US.UTF-8";
    };

    desktop = {
      environments = [ "kde" ];
      idle = {
        lockTimeout  = 900;   # 15 min (AC)
        sleepTimeout = 1200;  # 20 min (AC)
        battery = {
          lockTimeout  = 600; # 10 min
          sleepTimeout = 900; # 15 min
        };
      };
      displayManager = {
        enable = true;
        type = "sddm";
      };
    };

    hardware = {
      nvidia = {
        enable = true;
        laptop = {
          enable = true;
          amdgpuID = "PCI:4:0:0"; # GA401 model — verify with lspci at install time
          nvidiaID = "PCI:1:0:0";
        };
      };
      display.backlight.enable = true;
      kbdBacklight.enable = true;
      battery.enable = true;
    };

    apps = {
      defaultSet = "kde";
    };

    programs = {
      partydeck.enable = false;
    };

    homeManager = {
      enable = true;
      themes = {
        kde = "none";
      };
    };

    packages = {
      nixos = with pkgs; [];
      homeManager = with pkgs; [
        librewolf
        vesktop
      ];
      flatpak.enable = false;
    };

    profiles = {
      gaming.enable = true;
    };

    services = {
      ssh.enable = true;
    };

  };

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    extraSpecialArgs = { inherit inputs unstablePkgs; customConfig = config.customConfig; };
    users.${config.customConfig.user.name} = {};
  };

}

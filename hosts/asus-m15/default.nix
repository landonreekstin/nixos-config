# ~/nixos-config/hosts/asus-m15/default.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }:

{
  imports = [
    # Import the hardware profile for the Zephyrus M15 (GA502 model)
    inputs.nixos-hardware.nixosModules.asus-zephyrus-gu605my

    # Hardware-specific configuration generated for this host.
    # We will generate this file in the install script.
    ./hardware-configuration.nix

    ./disko-config.nix
    
    # Top level nixos modules import.
    ../../modules/nixos/default.nix
  ];

  # === Zephyrus G14 Specific Values for `customConfig` ===
  customConfig = {
    
    user = {
      name = "em";
      email = "landonreekstin@gmail.com";
    };
    
    system = {
      hostName = "asus-m15";
      stateVersion = "25.05"; # DO NOT CHANGE
      timeZone = "America/Chicago";
      locale = "en_US.UTF-8";
    };
    
    desktop = {
      environments = [ "kde" ];
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
          intelBusID = "PCI:0:2:0";
          nvidiaID = "PCI:1:0:0"; 
        };
      };
    };

    programs = {
      partydeck.enable = false;
      flatpak.enable = true;
    };

    homeManager = {
      enable = true;
      themes = {
        kde = "bigsur";
        plasmaOverride = true;
        wallpaper = ../../assets/wallpapers/big-sur.jpg;
      };
    };

    packages = {
      nixos = with pkgs; [ 
      
      ];
      unstable-override = [ 
        "discord-canary" 
        "vscode"
        "chromium"
      ];
      homeManager = with pkgs; [ 
        vscode
        chromium
        discord-canary
      ];
    };

    apps = {
      defaultBrowser = "librewolf";
    };

    profiles = {
      gaming.enable = true;
      development.fpga-ice40.enable = false;
      development.kernel.enable = false;
    };

    services = {
      ssh.enable = true;
      vscodeServer.enable = true;
      nixai.enable = false;
    };

  };

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs unstablePkgs; customConfig = config.customConfig; };
    users.${config.customConfig.user.name} = {
      imports = [
        ../../modules/home-manager/default.nix
      ];
    };
  };
  
}
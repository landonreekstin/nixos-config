# ~/nixos-config/hosts/asus-m15/default.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }:

{
  imports = [
    # Import the hardware profile for the Zephyrus M15 (GA502 model)
    inputs.nixos-hardware.nixosModules.asus-zephyrus-gu603h

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
      sudoPassword = true;
    };
    
    system = {
      hostName = "asus-m15";
      stateVersion = "25.05"; # DO NOT CHANGE
      timeZone = "America/Los_Angeles";
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
        "vscode"
        "chromium"
        "firefox"
      ];
      homeManager = with pkgs; [ 
        vscode
        chromium
        firefox
      ];
      flatpak = {
        enable = false;
        packages = [
          "com.spotify.Client"
          "com.discordapp.Discord"
        ];
      };
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
# ~/nixos-config/hosts/atl-mini-pc/default.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }: # Standard module arguments. `config` is the final NixOS config.

{
  imports = [
    # Hardware-specific configuration for this host
    ./hardware-configuration.nix
    
    # Top level nixos modules import. All other nixos modules and option definitions are nested.
    ../../modules/nixos/default.nix

    # Host specific disk configuration
    ./disko-config.nix

  ];

  # These values are for the options defined in `../../modules/nixos/common-options.nix`.
  customConfig = {
    
    user = {
      name = "heather";
      email = "landonreekstin@gmail.com";
      updateCmdPermission = false; 
    };
    
    system = {
      hostName = "atl-mini-pc"; # Actual hostname for this machine
      stateVersion = "25.05"; # DO NOT CHANGE
      timeZone = "America/New_York";
      locale = "en_US.UTF-8"; 
    };

    bootloader = {
      quietBoot = true;
    };
    
    desktop = {
      environments = [ "kde" ];
      displayManager = {
        enable = true; # false will go to TTY but not autolaunch a DE
        type = "sddm";
      };
    };

    hardware = {
      nvidia = {
        enable = false;
      };
    };

    programs = {
      partydeck.enable = false;
    };

    homeManager = {
      enable = true; # Enable Home Manager for this host
      themes = {
        kde = "default";
        wallpaper = ../../assets/wallpapers/soviet-retro-future.jpg;
      };
    };

    packages = {
      nixos = with pkgs; [

      ];
      unstable-override = [
        "firefox"
        "chromium"
      ];
      homeManager = with pkgs; [
        notes
        chromium
        firefox
        libreoffice
      ];
      flatpak.enable = true;
    };

    apps = {
      defaultBrowser = "firefox";
    };

    profiles = {
      gaming.enable = false;
    };

    services = {
      ssh.enable = true;
      vscodeServer.enable = true;
      wireguard.server = {
        enable = false;
        address = "10.100.100.1/24";
        listenPort = 51824;
        privateKeyFile = "/etc/nixos/secrets/wireguard/server-privatekey"; # IMPORTANT: Use a secret path
        peers = [
          {
            # Example Peer 1: A Phone
            publicKey = "PKvb7VKgYKXobS0MjVg68NbkObZVO9Bdakjv7Hi5NGw=";
            allowedIPs = [ "10.200.200.2/32" ];
          }
        ];
      };
    };

  };

  # === Host-specific NixOS configuration ===
  services.xserver.videoDrivers = [ "i810" ];

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup"; # Your existing setting
    extraSpecialArgs = { inherit inputs unstablePkgs; customConfig = config.customConfig; };
    # Use the username from customConfig
    users.${config.customConfig.user.name} = { pkgs', lib', config'', ... }: { # config'' here is the HM config being built for this user
      imports = [
        # === Plasma Manager ===
        inputs.plasma-manager.homeModules.plasma-manager
        # === Common User Environment Modules ===
        ../../modules/home-manager/default.nix
      ];
    };
  };
  
}

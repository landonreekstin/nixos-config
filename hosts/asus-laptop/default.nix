# ~/nixos-config/hosts/zephyrus-g14/default.nix
{ inputs, pkgs, lib, config, ... }:

{
  imports = [
    # Import the hardware profile for the Zephyrus G14 (GA401 model)
    inputs.nixos-hardware.nixosModules.asus-zephyrus-ga401

    # Hardware-specific configuration generated for this host.
    # We will generate this file in the install script.
    ./hardware-configuration.nix
    
    # Top level nixos modules import.
    ../../modules/nixos/default.nix
  ];

  # === Zephyrus G14 Specific Values for `customConfig` ===
  customConfig = {
    
    user = {
      name = "lando";
      email = "landonreekstin@gmail.com";
    };
    
    system = {
      hostName = "asus-laptop";
      stateVersion = "25.05"; # DO NOT CHANGE
      timeZone = "America/Chicago";
      locale = "en_US.UTF-8";
    };
    
    desktop = {
      environment = "kde";
      displayManager = {
        enable = true;
        type = "ly";
      };
    };

    hardware = {
      nvidia = {
        enable = true;
        laptop = {
          enable = true;
          amdgpuID = "PCI:4:0:0";
          nvidiaID = "PCI:1:0:0"; 
        };
      };
    };

    programs = {
      hyprland.enable = false;
      kde.enable = true;
      cosmic.enable = false;
    };

    homeManager = {
      enable = true;
      themes = {
        kde = "none";
        hyprland = "future-aviation";
      };
    };

    packages = {
      nixos = with pkgs; [ 
        wget
        fd
        kitty
        htop
        pavucontrol
        mullvad-vpn
      ];
      homeManager = with pkgs; [ 
        jamesdsp
        remmina
        vscode
        librewolf
        brave
        discord-canary
      ];
    };

    apps = {
      defaultBrowser = "librewolf";
    };

    profiles = {
      gaming.enable = true; # Enable the gaming profile
      #gaming.partydeck.enable = true; # Enable PartyDeck for splitscreen gaming
      flatpak.enable = true;
      development.fpga-ice40.enable = false;
      development.kernel.enable = false;
    };

    services = {
      ssh.enable = true;
      vscodeServer.enable = true;
      nixai.enable = false;
    };

  };

  # === Additional nixos configuration for this host ===
  services.mullvad-vpn.enable = true;
  # In your NixOS configuration
  services.flatpak.enable = true;
  services.keyd = {
    enable = true;
    keyboards = {
      # This name comes from your keyd monitor output
      "Asus Keyboard" = {
        ids = [ "*" ]; # Match any ID for this named device

        # 'settings' is the correct option that builds the .conf file.
        # This block will generate a config file with a [main] section.
        settings = {
          main = {
            # This line creates the entry 'f4 = minus' inside the [main] section.
            f4 = "minus";
          };
        };
      };
    };
  };

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs; customConfig = config.customConfig; };
    users.${config.customConfig.user.name} = {
      imports = [
        ../../modules/home-manager/default.nix
        ../../modules/home-manager/themes/future-aviation/default.nix
      ];
    };
  };
  
}
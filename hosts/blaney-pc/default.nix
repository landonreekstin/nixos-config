# ~/nixos-config/hosts/blaney-pc/default.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }: # Standard module arguments. `config` is the final NixOS config.

{
  imports = [
    # Hardware-specific configuration for this host
    ./hardware-configuration.nix
    
    # Top level nixos modules import. All other nixos modules and option definitions are nested.
    ../../modules/nixos/default.nix

  ];

  customConfig = {
    
    user = {
      name = "insideabush";
      email = "cblaney00@gmail.com";
      updateCmdPermission = false; 
    };
    
    system = {
      hostName = "blaney-pc"; # Actual hostname for this machine
      stateVersion = "25.05"; # DO NOT CHANGE
      timeZone = "America/New_York"; # As per your old core.nix
      locale = "en_US.UTF-8"; # As per your old core.nix
    };
    
    desktop = {
      environments = [ "kde" ];
      displayManager = {
        enable = true; # false will go to TTY but not autolaunch a DE
        type = "sddm";
        sddm = {
          theme = "sddm-astronaut";
          embeddedTheme = "pixel_sakura";
          screensaver = {
            enable = true;
            timeout = 25; # e.g., 10 minutes
          };
        };
      };
    };

    hardware = {
      unstable = true;
      nvidia = {
        enable = true; # Set to true if Optiplex has an NVIDIA GPU needing proprietary drivers
      };
      peripherals = {
        enable = true; # Enable peripheral configurations
        openrgb.enable = true; # Enable OpenRGB for RGB control
        openrazer.enable = true; # Enable OpenRazer for Razer device support
        ckb-next.enable = false; # Enable CKB-Next for Corsair device support
        input-remapper.enable = true;
        solaar.enable = true;
      };
    };

    programs = {
      partydeck.enable = false;
    };

    homeManager = {
      enable = true; # Enable Home Manager for this host
      themes = {
        kde = "windows7";
      };
    };

    packages = {
      nixos = with pkgs; [

      ];
      unstable-override = [ 
        "discord-canary" 
        "obs-studio" 
        "vscode"
        "librewolf"
        "brave"
        "ungoogled-chromium"
        "desmume"
        "mgba"
      ];
      homeManager = with pkgs; [
        kitty
        vscode
        librewolf
        brave
        #discord-canary
        #discord
        obs-studio
        notes
        CuboCore.corepaint
        kdePackages.kdenlive
        desmume
        mgba
      ];
      flatpak = {
        enable = true;
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
    };

    services = {
      ssh.enable = false;
      vscodeServer.enable = false;
      passwordManager.enable = true;
    };

  };
  
  # === Additional nixos configuration for this host ===

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup"; # Your existing setting
    extraSpecialArgs = { inherit inputs unstablePkgs; customConfig = config.customConfig; };
    # Use the username from customConfig
    users.${config.customConfig.user.name} = { pkgs', lib', config'', ... }: { # config'' here is the HM config being built for this user
      imports = [
        # === Common User Environment Modules ===
        ../../modules/home-manager/default.nix
      ];
    };
  };
  
}

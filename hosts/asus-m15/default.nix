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

    bootloader = {
      quietBoot = true;
    };
    
    desktop = {
      environments = [ "kde" ];
      displayManager = {
        enable = true;
        type = "sddm";
        sddm = {
          theme = "sddm-astronaut";
          customTheme = {
            enable = true;
            wallpaper = ../../assets/wallpapers/spooky-sddm.mp4;
            blur = 2.0;
            roundCorners = 20;
            colors = {
              formBackground = "#1e1e2e";
              dimBackground = "#1e1e2e";
              headerText = "#cdd6f4";
              dateText = "#cdd6f4";
              timeText = "#cdd6f4";
              placeholderText = "#a6adc8";
              loginButtonBackground = "#89b4fa";
              loginButtonText = "#1e1e2e";
              highlightBackground = "#89b4fa";
              systemButtonsIcons = "#cdd6f4";
            };
          };
          screensaver = {
            enable = false;
          };
        };
      };
    };

    hardware = {
      unstable = true;
      nvidia = {
        enable = true;
        laptop = {
          enable = true;
          intelBusID = "PCI:0:2:0";
          nvidiaID = "PCI:1:0:0"; 
        };
      };
      peripherals = {
        enable = true;
        asus.enable = true;
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
        plasmaOverride = false;
        wallpaper = ../../assets/wallpapers/big-sur.jpg;
        pinnedApps = [
          "applications:org.kde.konsole.desktop"
          "applications:systemsettings.desktop"
          "applications:org.kde.dolphin.desktop"
          "applications:chromium-browser.desktop"
          "applications:net.lutris.Lutris.desktop"
          "applications:com.heroicgameslauncher.hgl.desktop"
          "applications:steam.desktop"
          "applications:com.discordapp.Discord.desktop"
          "applications:com.spotify.Client.desktop"
        ];
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
        enable = true;
        packages = [
          "com.spotify.Client"
          "com.discordapp.Discord"
        ];
      };
    };

    apps = {
      defaultBrowser = "chromium"; # Placeholder, no effect yet
    };

    profiles = {
      gaming.enable = true;
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
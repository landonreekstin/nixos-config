# ~/nixos-config/hosts/optiplex/default.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }: # Standard module arguments. `config` is the final NixOS config.

{
  imports = [
    # Hardware-specific configuration for this host
    ./hardware-configuration.nix
    
    # Top level nixos modules import. All other nixos modules and option definitions are nested.
    ../../modules/nixos/default.nix
  ];

  # === Optiplex Specific Values for `customConfig` ===
  # These values are for the options defined in `../../modules/nixos/common-options.nix`.
  customConfig = {
    
    user = {
      name = "lando"; # Your username for the Optiplex
      # home = "/home/lando"; # Defaults correctly based on user.name
      email = "landonreekstin@gmail.com";
      shell.bash.color = "bright-cyan";
    };
    
    system = {
      hostName = "optiplex"; # Actual hostname for this machine
      stateVersion = "24.11"; # DO NOT CHANGE
      timeZone = "America/Chicago"; # As per your old core.nix
      locale = "en_US.UTF-8"; # As per your old core.nix
    };
    
    desktop = {
      environments = [ "hyprland" "kde" ];
      displayManager = {
        enable = true; # false will go to TTY but not autolaunch a DE
        type = "ly";
      };
      monitors = [
        {
          name = "main";
          identifier = "Dell Inc. DELL S2721HGF DZR2123";
          resolution = "1920x1080@144";
          position = "0x0";
          scale = "1";
        }
        {
          name = "left";
          identifier = "Dell Inc. OptiPlex 7760 0x36419E0A";
          resolution = "preferred";
          position = "-1080x-410";
          scale = "1";
          transform = "1";
        }
        {
          name = "right";
          identifier = "Samsung Electric Company S27R65x H4TW800293";
          resolution = "preferred";
          position = "1920x-390";
          scale = "1";
          transform = "1";
        }
        {
          name = "tv";
          identifier = "Hisense Electric Co. Ltd. 4Series43 0x00000278";
          resolution = "preferred";
          position = "0x-1080";
          scale = "1";
        }
      ];
      wayvnc = {
        enable = true;
        targetMonitor = "tv";
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
      enable = true;
      themes = {
        plasmaOverride = false;
        kde = "windows7-alt";
        hyprland = "future-aviation";
        wallpaper = ../../assets/wallpapers/windows7-wallpaper.jpg;
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
          "applications:org.kde.plasma-systemmonitor.desktop"
          "applications:org.kde.kcalc.desktop"
          "applications:code.desktop"
          "applications:polychromatic.desktop"
          "applications:input-remapper-gtk.desktop"
          "applications:librewolf.desktop"
          "applications:OpenRGB.desktop"
          "applications:io.github.nuttyartist.notes.desktop"
        ];
      };
    };

    packages = {
      nixos = with pkgs; [
        firefox
        kitty
        claude-code
      ];
      unstable-override = [ 
        "vscode"
        "librewolf"
        "ungoogled-chromium"
      ];
      homeManager = with pkgs; [ 
        jamesdsp
        remmina
        vscode
        librewolf
        ungoogled-chromium
        notes
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

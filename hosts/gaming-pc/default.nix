# ~/nixos-config/hosts/gaming-pc/default.nix
{ inputs, pkgs, lib, config, unstablePkgs, ... }: # Standard module arguments. `config` is the final NixOS config.

{
  imports = [
    # Hardware-specific configuration for this host
    ./hardware-configuration.nix

    # Top level nixos modules import. All other nixos modules and option definitions are nested.
    ../../modules/nixos/default.nix

  ];

  # === Gaming PC Specific Values for `customConfig` ===
  # These values are for the options defined in `../../modules/nixos/common-options.nix`.
  customConfig = {

    user = {
      name = "lando";
      # home = "/home/lando"; # Defaults correctly based on user.name
      email = "landonreekstin@gmail.com";
      shell.bash.color = "blue";
    };

    system = {
      hostName = "gaming-pc"; # Actual hostname for this machine
      stateVersion = "24.11"; # DO NOT CHANGE
      timeZone = "America/Chicago";
      locale = "en_US.UTF-8";
    };

    bootloader = {
      quietBoot = false; # show boot messages
    };

    desktop = {
      environments = [ "kde" ]; # Set to "hyprland", "cosmic", or "kde" based on your preference
      displayManager = {
        enable = true; # false will go to TTY but not autolaunch a DE
        type = "ly"; # Or "greetd", "gdm", or "none" based on your preference for Optiplex
        sddm = {
          theme = "sddm-astronaut";
          #embeddedTheme = "pixel_sakura";
          customTheme = {
            enable = true;
            wallpaper = ../../assets/wallpapers/soviet-retro-future.jpg;
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
            timeout = 20; # e.g., 10 minutes
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
        openrazer.enable = false; # Enable OpenRazer for Razer device support
        ckb-next.enable = true; # Enable CKB-Next for Corsair device support
      };
    };

    programs = {
      partydeck.enable = false;
      firefox = {
        enable = true;
        package = pkgs.firefox;

        extensions = with pkgs.nur.repos.rycee.firefox-addons; [
          ublock-origin
          darkreader
          facebook-container
        ];

        bookmarks = [
          { name = "YouTube"; url = "https://www.youtube.com"; }
          { name = "Netflix"; url = "https://www.netflix.com"; }
          { name = "GitHub";  url = "https://github.com"; }
        ];
      };
    };

    homeManager = {
      enable = true;
      themes = {
        #hyprland = "future-aviation"; # Set to the theme you want for Hyprland
      };
    };

    packages = {
      nixos = with pkgs; [
        kitty
        mullvad-vpn

        # smbclient and kio-extras for Dolphin network shares
        kdePackages.kio-extras
        cifs-utils
        samba
      ];
      unstable-override = [ 
        "discord-canary" 
        "obs-studio" 
        "vscode"
        "librewolf"
        "brave"
        "ungoogled-chromium"
        "claude-code"
      ];
      homeManager = with pkgs; [
        jamesdsp
        remmina
        vscode
        librewolf
        brave
        ungoogled-chromium
        discord-canary
        qbittorrent
        obs-studio
        kdePackages.konversation
        kdePackages.kdenlive
        claude-code
      ];
      flatpak = {
        enable = true;
        packages = [
          "com.spotify.Client"
        ];
      };
    };

    apps = {
      defaultBrowser = "librewolf";
    };

    profiles = {
      gaming.enable = true;
      development = {
        fpga-ice40.enable = true;
        kernel.enable = true;
        embedded-linux.enable = true;
        gbdk.enable = true;
      };
    };

    services = {
      ssh.enable = true;
      vscodeServer.enable = true;
      passwordManager.enable = true;
    };

  };

  # === Additional nixos configuration for this host ===
  services.mullvad-vpn.enable = true;
  # Enable the Samba client-side name resolution daemon (nmbd).
  # This allows the PC to discover other Samba hosts (like optiplex-nas)
  # on the local network by their hostname.
  services.samba.nmbd.enable = true;
  networking.firewall.allowedTCPPorts = [ 139 445 4445 ];
  networking.firewall.allowedUDPPorts = [ 137 138 ];
  networking.extraHosts = ''
    192.168.1.76  optiplex-nas
  '';

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

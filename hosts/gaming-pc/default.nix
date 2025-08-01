# ~/nixos-config/hosts/gaming-pc/default.nix
{ inputs, pkgs, lib, config, ... }: # Standard module arguments. `config` is the final NixOS config.

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
      shell = pkgs.bash;
    };

    system = {
      hostName = "gaming-pc"; # Actual hostname for this machine
      stateVersion = "24.11"; # DO NOT CHANGE
      timeZone = "America/Chicago";
      locale = "en_US.UTF-8";
    };

    desktop = {
      environment = "kde"; # Set to "hyprland", "cosmic", or "kde" based on your preference
      displayManager = {
        enable = true; # false will go to TTY but not autolaunch a DE
        type = "ly"; # Or "greetd", "gdm", or "none" based on your preference for Optiplex
      };
    };

    hardware = {
      nvidia = {
        enable = true; # Set to true if Optiplex has an NVIDIA GPU needing proprietary drivers
      };
    };

    programs = {
      hyprland.enable = true; # Defaults based on desktop.environment
      cosmic.enable = false;   # Set this true if desktop.environment is "cosmic"
      kde.enable = true; # Enable KDE Plasma as the desktop environment
                                # You had both enabled before, decide which is primary
                                # or if both can be installed system-wide and chosen at login.
                                # For now, let's assume only one is active for its full setup.
      # If you want both *installed* but only one *active* for session management,
      # the enable flags here could control installation, and another option for session.
      # Based on your old default.nix, you were trying to set 'displayManager = "none"'
      # which implies Hyprland might be started manually or via a login shell.
      # Let's assume hyprland.enable takes precedence if desktop.environment is "hyprland".
    };

    homeManager = {
      enable = true;
      themes = {
        hyprland = "future-aviation"; # Set to the theme you want for Hyprland
      };
    };

    packages = {
      nixos = with pkgs; [ # Optiplex-specific system packages (previously in core.nix or default.nix)
        # From old core.nix:
        vim
        wget
        fd
        firefox
        kitty
        htop
        pavucontrol
        mullvad-vpn
        # Add any other system packages specific to Optiplex
      ];
      homeManager = with pkgs; [ # Optiplex-specific user packages (previously in core.nix user packages)
        jamesdsp
        remmina
        vscode
        librewolf
        brave
        ungoogled-chromium
        discord-canary
        qbittorrent
      ];
    };

    apps = {
      defaultBrowser = "librewolf";
    };

    profiles = {
      gaming = {
        enable = true;
        partydeck.enable = true;
      };
      development.kernel.enable = true;
    };

    services = {
      ssh.enable = true;
      vscodeServer.enable = true;
    };

  };

  # === Additional nixos configuration for this host ===
  hardware.ckb-next.enable = true;
  services.mullvad-vpn.enable = true;
  # In your NixOS configuration
  services.flatpak.enable = true;

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup"; # Your existing setting
    extraSpecialArgs = { inherit inputs; customConfig = config.customConfig; };
    # Use the username from customConfig
    users.${config.customConfig.user.name} = { pkgs', lib', config'', ... }: { # config'' here is the HM config being built for this user
      imports = [ 
        # === Common User Environment Modules ===
        ../../modules/home-manager/default.nix

        # === Theme Module ===
        ../../modules/home-manager/themes/future-aviation/default.nix
      ];
    };
  };
  
}

# ~/nixos-config/hosts/optiplex/default.nix
{ inputs, pkgs, lib, config, ... }: # Standard module arguments. `config` is the final NixOS config.

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
      shell = pkgs.bash; # Or your preferred shell for Optiplex user
    };
    
    system = {
      hostName = "optiplex"; # Actual hostname for this machine
      stateVersion = "24.11"; # DO NOT CHANGE
      timeZone = "America/Chicago"; # As per your old core.nix
      locale = "en_US.UTF-8"; # As per your old core.nix
    };
    
    desktop = {
      environment = "hyprland"; # Set Optiplex to use Hyprland
      displayManager = {
        enable = true; # false will go to TTY but not autolaunch a DE
        type = "none"; # Or "greetd", "gdm", or "none" based on your preference for Optiplex
      };
    };

    hardware = {
      nvidia = {
        enable = true; # Set to true if Optiplex has an NVIDIA GPU needing proprietary drivers
      };
    };

    programs = {
      hyprland.enable = true; # Defaults based on desktop.environment
      # cosmic.enable = true;   # Set this true if desktop.environment is "cosmic"
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
        # Add any other system packages specific to Optiplex
      ];
      homeManager = with pkgs; [ # Optiplex-specific user packages (previously in core.nix user packages)
        jamesdsp
        remmina
        vscode
        librewolf
        ungoogled-chromium
        discord-canary
      ];
    };

    apps = {
      defaultBrowser = "librewolf";
    };

    profiles = {
      gaming.enable = true;
      development.fpga-ice40.enable = false; # Enable FPGA Ice40 profile
    };

    services = {
      ssh.enable = true;
      vscodeServer.enable = true;
    };

  };

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup"; # Your existing setting
    extraSpecialArgs = { inherit inputs; };
    # Use the username from customConfig
    users.${config.customConfig.user.name} = { pkgs', lib', config'', ... }: { # config'' here is the HM config being built for this user
      imports = [ ./home.nix ];

      # Set the VALUES for hmCustomConfig options
      # These will be part of the 'config''' object that ./home.nix receives
      hmCustomConfig = {
        user = {
          name = config.customConfig.user.name; # 'config' here is the outer NixOS config
          email = config.customConfig.user.email;
          loginName = config.customConfig.user.name;
          homeDirectory = "/home/${config.customConfig.user.name}";
          shell = config.customConfig.user.shell;
        };
        desktop = config.customConfig.desktop.environment;
        theme = config.customConfig.homeManager.theme.name;
        systemStateVersion = config.customConfig.system.stateVersion;
        packages = config.customConfig.packages.homeManager;
      };
    };
  };
}
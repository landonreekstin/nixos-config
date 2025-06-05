# ~/nixos-config/hosts/optiplex/default.nix
{ inputs, pkgs, lib, config, ... }: # Standard module arguments. `config` is the final NixOS config.

{
  imports = [
    # Hardware-specific configuration for this host
    ./hardware-configuration.nix
    # Define our custom options (makes `config.customConfig` available for use below)
    ../../modules/nixos/common-options.nix

    # Universal host options
    ../../modules/nixos/common/default.nix          # User, system basics, nix settings

    # Import ALL shared NixOS modules.
    #    These modules will be refactored later to use `lib.mkIf` based on `config.customConfig`.
    #    For now, they are imported, and their internal logic will be made conditional and imported with a default.nix.
    ../../modules/nixos/desktop/cosmic.nix         # COSMIC DE system settings
    ../../modules/nixos/desktop/hyprland.nix       # Hyprland system settings
    ../../modules/nixos/desktop/display-manager.nix# Display manager logic
    ../../modules/nixos/hardware/nvidia.nix        # NVIDIA GPU settings
    #../../modules/nixos/services/networking.nix    # Network configuration
    #../../modules/nixos/services/audio.nix      # Pipewire audio
    ../../modules/nixos/services/ssh.nix           # SSH server
    ../../modules/nixos/services/vscode-server.nix
    ../../modules/nixos/profiles/gaming.nix        # Gaming profile (conditional import later)

    inputs.nixos-vscode-server.nixosModules.default
    inputs.nixos-cosmic.nixosModules.default

  ];

  # === Optiplex Specific Values for `customConfig` ===
  # These values are for the options defined in `../../modules/nixos/common-options.nix`.
  customConfig = {
    
    user = {
      name = "lando"; # Your username for the Optiplex
      # home = "/home/lando"; # Defaults correctly based on user.name
      shell = pkgs.bash; # Or your preferred shell for Optiplex user
    };
    
    system = {
      hostName = "optiplex"; # Actual hostname for this machine
      stateVersion = "24.11"; # As per your old config (can be "23.11" or "24.05" too)
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
      theme = {
        enable = true;
        name = "future-aviation"; # Your current theme
      };
      modules = {
        # hyprland.enable = true; # Defaults if desktop.environment is "hyprland"
        # waybar.enable = true;   # Defaults if desktop.environment is "hyprland"
      };
    };

    packages = {
      nixos = with pkgs; [ # Optiplex-specific system packages (previously in core.nix or default.nix)
        # From old core.nix:
        vim
        wget
        firefox
        kitty
        htop
        pavucontrol
        # Add any other system packages specific to Optiplex
      ];
      homeManager = with pkgs; [ # Optiplex-specific user packages (previously in core.nix user packages)
        jamesdsp
        remmina
      ];
    };

    apps = {
      defaultBrowser = "librewolf";
    };

    profiles = {
      gaming.enable = true;
    };

    services = {
      ssh.enable = true;
      vscodeServer.enable = true;
    };

  };

  # === Settings driven by customConfig that might not be in a separate module yet ===

  # Home Manager configuration for this Host
  home-manager = lib.mkIf config.customConfig.homeManager.enable {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup"; # Your existing setting
    extraSpecialArgs = { # Pass inputs and the evaluated `customConfig` to HM modules
      inherit inputs;
      customConfig = config.customConfig; # Pass the host-specific evaluated options
    };
    # Use the username from customConfig
    users.${config.customConfig.user.name} = {
      imports = [
        # This points to Optiplex's specific home.nix
        ./home.nix
      ];
    };
  };

}
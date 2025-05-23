# ~/nixos-config/hosts/optiplex/default.nix
{ config, pkgs, inputs, lib, ... }:

{
  imports =
    [
      # Hardware configuration specific to this host
      ./hardware-configuration.nix

      # Core system configuration (users, nix settings, locale, etc.)
      ../../modules/nixos/core.nix

      # Desktop Environment
      ../../modules/nixos/desktop/cosmic.nix
      ../../modules/nixos/desktop/hyprland.nix
      ../../modules/nixos/desktop/display-manager.nix

      # Hardware Modules (GPU, etc.)
      ../../modules/nixos/hardware/nvidia.nix
      # Add other hardware modules if needed (e.g., intel-graphics.nix)

      # Service Modules
      ../../modules/nixos/services/networking.nix
      ../../modules/nixos/services/pipewire.nix
      ../../modules/nixos/services/ssh.nix

      # vscode server for remote ssh
      inputs.nixos-vscode-server.nixosModules.default

      # Profile Modules (placeholder concept for later)
      # ../../modules/nixos/profiles/development.nix
      ../../modules/nixos/profiles/gaming.nix
    ];

  # ==> Enable Desktop Profiles for this Host <==
  profiles.desktop.cosmic.enable = true;
  profiles.desktop.hyprland.enable = true;

  # ==> Select Display Manager for this Host <==
  #profiles.desktop.displayManager = "cosmic";
  #profiles.desktop.displayManager = "greetd";
  #profiles.desktop.displayManager = "sddm";
  profiles.desktop.displayManager = "none"; # For ricing over VNC

  # ==> Host Specific Settings <==
  networking.hostName = "optiplex"; # Set the hostname for this specific machine

  # Set the state version for this host based on its initial install
  system.stateVersion = "24.11";

  # Enable vscode server for remote ssh
  services.vscode-server.enable = true; # Enable the service from the module
  programs.nix-ld.enable = true;      # Enable the nix-ld wrapper environment
  programs.nix-ld.libraries = with pkgs; [ # Add common libraries often needed by downloaded binaries
      stdenv.cc.cc.lib
      zlib
      # Add others here if vscode server specifically complains later
  ];

  # ==> Home Manager Configuration for this Host <==
  home-manager = {
    useGlobalPkgs = true; # Use system's nixpkgs for Home Manager packages
    useUserPackages = true; # Allow Home Manager to manage packages in user profile
    backupFileExtension = "hm-backup"; # Backup existing dotfiles
    
    # Define users managed by Home Manager on this host
    users = {
      # Manage the 'lando' user
      lando = { pkgs, config, lib, inputs, ... }: {
        imports = [
          ./home.nix
        ];
      };
    };
    
    extraSpecialArgs = { inherit inputs; };

  };

  # Nixpkgs configuration specific to this host (if any)
  nixpkgs.config = {
    allowUnfree = true; # Moved from the main config, applied via nvidia module now
  };

}

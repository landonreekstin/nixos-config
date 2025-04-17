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

      # Hardware Modules (GPU, etc.)
      ../../modules/nixos/hardware/nvidia.nix
      # Add other hardware modules if needed (e.g., intel-graphics.nix)

      # Service Modules
      ../../modules/nixos/services/networking.nix
      ../../modules/nixos/services/pipewire.nix
      ../../modules/nixos/services/ssh.nix

      # Profile Modules (placeholder concept for later)
      # ../../modules/nixos/profiles/development.nix
      # ../../modules/nixos/profiles/gaming.nix
    ];

  # ==> Host Specific Settings <==
  networking.hostName = "optiplex"; # Set the hostname for this specific machine

  # Set the state version for this host based on its initial install
  system.stateVersion = "24.11";

  # You could override module settings here if needed for this specific host
  # For example:
  # services.openssh.settings.PermitRootLogin = "yes"; # (Don't actually do this!)

  # Nixpkgs configuration specific to this host (if any)
  nixpkgs.config = {
    allowUnfree = true; # Moved from the main config, applied via nvidia module now
  };

}

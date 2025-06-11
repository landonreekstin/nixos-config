# ~/nixos-config/modules/nixos/services/networking.nix
{ config, pkgs, lib, ... }:

{
  networking.hostName = config.customConfig.system.hostName;

  # Enable NetworkManager
  networking.networkmanager.enable = true; # Handles wired and wireless connections

  # Disable firewall for now (as in original config)
  # Enable and configure later if needed
  networking.firewall.enable = true;
}

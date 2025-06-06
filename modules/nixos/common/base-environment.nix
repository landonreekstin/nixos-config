# ~/nixos-config/modules/nixos/common/base-environment.nix
{ config, pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    git
    fastfetch
    # Any other truly universal CLI packages
  ] ++ config.customConfig.packages.nixos; # Appends host-specific system packages

  system.stateVersion = config.customConfig.system.stateVersion; # Set state version from customConfig
}
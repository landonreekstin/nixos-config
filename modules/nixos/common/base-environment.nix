# ~/nixos-config/modules/nixos/common/base-environment.nix
{ config, pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    git
    vim
    fastfetch
    nettools
    wget
    fd
    htop
    usbutils
    # Any other truly universal CLI packages
    bat
    glow
    gh
  ] ++ config.customConfig.packages.nixos; # Appends host-specific system packages

  # Point gh at the user's config directory even when running as root (e.g. sudo claude-code)
  environment.variables.GH_CONFIG_DIR = "${config.customConfig.user.home}/.config/gh";

  system.stateVersion = config.customConfig.system.stateVersion; # Set state version from customConfig
}
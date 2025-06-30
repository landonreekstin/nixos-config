# ~/nixos-config/modules/home-manager/common/home-base.nix
# vvv Add `customConfig` to the function arguments vvv
{ pkgs, config, lib, inputs, customConfig, ... }:

{
  # === User and Home Configuration (now read directly from `customConfig`) ===
  home.username = customConfig.user.name;
  home.homeDirectory = customConfig.user.home;
  home.stateVersion = customConfig.system.stateVersion;
  home.packages = customConfig.packages.homeManager;

  # == Enable Home Manager management ==
  programs.home-manager.enable = true;
}
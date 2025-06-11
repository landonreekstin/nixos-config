# ~/nixos-config/modules/home-manager/common/home-base.nix
{ pkgs, config, lib, inputs, ... }:

{

  # === User and Home Configuration (from customConfig) ===
  # These must be defined in your customConfig for this host/user.
  home.username = config.hmCustomConfig.user.loginName;
  home.homeDirectory = config.hmCustomConfig.user.homeDirectory;
  home.stateVersion = config.hmCustomConfig.systemStateVersion;
  home.packages = config.hmCustomConfig.packages;

  # == Enable Home Manager management ==
  # This must be enabled for Home Manager to work.
  programs.home-manager.enable = true;

}

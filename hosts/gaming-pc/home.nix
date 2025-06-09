# ~/nixos-config/hosts/optiplex/home.nix
{ pkgs, config, lib, inputs, ... }:

{

  imports = [
    # ====== Custom Option Definitions ======
    #../../modules/home-manager/common-options.nix

    # === Common User Environment Modules ===
    ../../modules/home-manager/common/git.nix
    ../../modules/home-manager/system/default.nix

    # === Program Modules ===
    # Import kitty if it's generally used on this type of host,
    # or make its import conditional via lib.mkIf based on customConfig.
    ../../modules/home-manager/programs/kitty.nix

    # === Desktop Environment / Window Manager Specific Modules ===
    # These are specific to this host's setup (Hyprland desktop)
    ../../modules/home-manager/hyprland/default.nix # Imports hyprland functionality
    ../../modules/home-manager/de-wm-components/waybar/default.nix # Imports waybar functionality
    
    # === Theme Module ===
    # Dynamically import the theme based on customConfig.
    # Ensure config.customConfig.theme is defined in your NixOS/HM options
    # and set for this host.
    ../../modules/home-manager/themes/future-aviation/default.nix
  ];

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

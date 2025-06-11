# ~/nixos-config/hosts/optiplex/home.nix
{ pkgs, config, lib, inputs, ... }:

{

  imports = [
    # ====== Custom Option Definitions ======
    #../../modules/home-manager/common-options.nix

    # === Common User Environment Modules ===
    ../../modules/home-manager/default.nix

    # === Theme Module ===
    # Dynamically import the theme based on customConfig.
    # Ensure config.customConfig.theme is defined in your NixOS/HM options
    # and set for this host.
    ../../modules/home-manager/themes/future-aviation/default.nix
  ];

  # home options and home-manager.enable moved to common/home-base.nix
  # set hmcustomConfig options here
}

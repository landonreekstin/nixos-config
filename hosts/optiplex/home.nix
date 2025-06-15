# ~/nixos-config/hosts/optiplex/home.nix
{ pkgs, config, lib, inputs, ... }:

{

  imports = [
    # === Common User Environment Modules ===
    ../../modules/home-manager/default.nix

    # === Theme Module ===
    ../../modules/home-manager/themes/future-aviation/default.nix
  ];

  # home options and home-manager.enable moved to common/home-base.nix
  # set hmcustomConfig options here
}

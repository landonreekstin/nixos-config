# ~/nixos-config/hosts/blaney-pc/home.nix
{ pkgs, config, lib, inputs, ... }:

{

  imports = [
    # === Common User Environment Modules ===
    ../../modules/home-manager/default.nix

    # === Theme Module ===
    ../../modules/home-manager/themes/future-aviation/default.nix
  ];

}

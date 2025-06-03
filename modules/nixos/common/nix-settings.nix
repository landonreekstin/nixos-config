# ~/nixos-config/modules/nixos/common/nix-settings.nix
{ config, pkgs, lib, ... }:
{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    # Binary sources
    substituters = [
      "https://cache.nixos.org/"
      "https://cosmic.cachix.org/"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    auto-optimise-store = config.customConfig.nix.optimiseStore; # Driven by option
  };

  # Garbage collection
  nix.gc = {
    automatic = config.customConfig.nix.gc.automatic; # Driven by option
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Dynamic linked libraries
  programs.nix-ld = lib.mkIf config.customConfig.nix.nix-ld.enable {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
    ];
  };
}
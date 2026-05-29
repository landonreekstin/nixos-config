# ~/nixos-config/modules/nixos/common/nix-settings.nix
{ config, pkgs, lib, ... }:
{

  environment.systemPackages = [ pkgs.nh ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    # Binary sources
    substituters = [
      "https://cache.nixos.org/"
      "https://cosmic.cachix.org/"
      "https://nix-community.cachix.org"
      # optiplex-nas binary cache — add back once nix-cache is set up on optiplex-nas:
      # "http://192.168.1.76:5000"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      # optiplex-nas-cache public key — add back once generated on optiplex-nas:
      # nix-store --generate-binary-cache-key optiplex-nas-cache \
      #   /root/secrets/cache-private-key.pem /root/secrets/cache-public-key.pem
      # then paste the contents of /root/secrets/cache-public-key.pem here
    ];
    auto-optimise-store = true;
  };

  nixpkgs.config.allowUnfree = true;

  # Garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Dynamic linked binaries
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
    ];
  };
}
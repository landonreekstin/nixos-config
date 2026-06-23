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
      "http://192.168.1.76:5000"   # optiplex-nas local binary cache (LAN)
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "optiplex-nas-cache:ZNikP70uFzhvVzu3v1AjprY9SYxGELhmCAzC6PFznAQ="
    ];
    auto-optimise-store = true;
    # Reduce connection timeout so an unreachable NAS cache (e.g. off LAN) is
    # skipped quickly rather than blocking for the default 5 seconds.
    connect-timeout = 3;
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "electron-39.8.10"            # used by aerotheme-plasma on optiplex
    "librewolf-151.0.2-1"         # marked insecure upstream; remove when fixed
    "librewolf-unwrapped-151.0.2-1"
  ];

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

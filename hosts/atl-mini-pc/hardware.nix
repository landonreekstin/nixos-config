# ~/nixos-config/hosts/atl-mini-pc/hardware.nix
{ config, pkgs, lib, ... }:

{
  customConfig.hardware = {
    nvidia = {
      enable = false;
    };
  };

  # No explicit videoDrivers: the default (modesetting) is what this Intel box
  # wants. It used to say [ "i810" ], which was already wrong — xf86-video-i810
  # drives i810/i815-era chips and was dropped from nixpkgs long ago. 25.11 and
  # earlier silently ignored unknown driver names; 26.05 throws instead, so the
  # stale entry became a hard eval failure.
}

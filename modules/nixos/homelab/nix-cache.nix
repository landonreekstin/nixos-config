# ~/nixos-config/modules/nixos/homelab/nix-cache.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.nixCache;
in
{
  config = lib.mkIf cfg.enable {

    services.nix-serve = {
      enable = true;
      port = 5000;
      openFirewall = true;
      secretKeyFile = "/root/secrets/cache-private-key.pem";
    };

    # Allow trusted users to push store paths to this machine via SSH (nix copy --to ssh://...)
    nix.settings.trusted-users = [ "root" "@wheel" ];

    # Keep cached paths longer on the NAS than the default 7 days
    nix.gc.options = lib.mkForce "--delete-older-than 30d";

  };
}

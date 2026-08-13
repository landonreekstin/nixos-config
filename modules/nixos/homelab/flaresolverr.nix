# ~/nixos-config/modules/nixos/homelab/flaresolverr.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.flaresolverr;
in
{
  options.customConfig.homelab.flaresolverr = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable FlareSolverr, a Cloudflare bypass proxy for indexers.";
    };
  };

  config = lib.mkIf cfg.enable {

    services.flaresolverr = {
      enable = true;
      openFirewall = true;
    };

  };
}

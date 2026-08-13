# ~/nixos-config/modules/nixos/homelab/options.nix
{ lib, ... }:

# Homelab options that no single module owns. Every other homelab option is
# declared by the module implementing it (homelab/jellyfin.nix owns
# customConfig.homelab.jellyfin, and so on) — only options shared by several
# modules belong here.
{
  # Implemented by both reverse-proxy-nas.nix and reverse-proxy-mini.nix, which
  # select on the host, so neither one owns the option.
  options.customConfig.homelab = with lib; {
    reverseProxy = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Nginx reverse proxy for homelab web services (routes .lan hostnames to local ports).";
      };
    };
  };
}

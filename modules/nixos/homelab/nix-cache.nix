# ~/nixos-config/modules/nixos/homelab/nix-cache.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.nixCache;
in
{
  options.customConfig.homelab.nixCache = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable nix-serve to host a local Nix binary cache on port 5000.";
    };
    clientEnable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Use the NAS binary cache as a substituter on this host. Rarely needs turning
        off — nix.settings.fallback makes an unreachable cache degrade rather than
        block — but gives a declarative escape hatch for a host that is permanently
        off the LAN, without editing the shared nix-settings module.
      '';
    };
    clientHost = mkOption {
      type = types.str;
      default = "192.168.1.76";
      description = ''
        Address at which the NAS nix binary cache (port 5000) is reached as a
        substituter from this host. Default is the legacy Main-LAN IP (a firewall
        alias post-migration, reachable from the LAN via rdr). Server-subnet hosts
        should override to 192.168.100.76 to reach it directly, since the legacy
        alias is not reachable from behind the firewall.
      '';
    };
  };

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

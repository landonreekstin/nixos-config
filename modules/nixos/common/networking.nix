# ~/nixos-config/modules/nixos/services/networking.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.networking;
in
{
  networking.hostName = config.customConfig.system.hostName;

  # Enable NetworkManager
  networking.networkmanager.enable = cfg.networkmanager.enable;

  networking.interfaces = lib.mkMerge [
    (lib.mkIf cfg.staticIP.enable {
      ${cfg.staticIP.interface} = {
        useDHCP = false;
        ipv4.addresses = [ {
          address = cfg.staticIP.address;
          prefixLength = 24;
        } ];
      };
    })
    (lib.mkIf (cfg.wakeOnLan.enable && cfg.wakeOnLan.interface != null) {
      ${cfg.wakeOnLan.interface}.wakeOnLan.enable = true;
    })
  ];

  networking.defaultGateway = if cfg.staticIP.enable then cfg.staticIP.gateway else null;
  networking.nameservers = lib.mkIf cfg.staticIP.enable [
    cfg.staticIP.gateway
    "1.1.1.1"
    "8.8.8.8"
  ];

  networking.firewall.enable = cfg.firewall.enable;
}

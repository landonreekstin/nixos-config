# ~/nixos-config/modules/nixos/services/networking.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.networking;
in
{
  networking.hostName = config.customConfig.system.hostName;

  # Enable NetworkManager
  networking.networkmanager.enable = cfg.networkmanager.enable;

  networking.interfaces = lib.mkIf cfg.staticIP.enable {
    ${cfg.staticIP.interface} = {
      useDHCP = false;
      ipv4.addresses = [ {
        address = cfg.staticIP.address;
        prefixLength = 24;
      } ];
    };
  };

  networking.defaultGateway = if cfg.staticIP.enable then cfg.staticIP.gateway else null;  
  networking.nameservers = [
    cfg.staticIP.gateway
    "1.1.1.1"
    "8.8.8.8"
  ];

  networking.firewall.enable = cfg.firewall.enable;
}

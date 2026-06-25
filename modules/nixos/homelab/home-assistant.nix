# ~/nixos-config/modules/nixos/homelab/home-assistant.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.homeAssistant;
in
{
  config = lib.mkIf cfg.enable {
    services.home-assistant = {
      enable = true;
      openFirewall = true;
      extraComponents = [
        "default_config"
        "met"
        "tplink"
        "cync"
        "wyoming"
        "radio_browser"
      ];
      config = {
        homeassistant = {
          name = "Home";
          unit_system = "us_customary";
          time_zone = "America/Chicago";
        };
        http.server_port = cfg.port;
      };
    };
  };
}

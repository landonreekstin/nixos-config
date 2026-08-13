# ~/nixos-config/modules/nixos/homelab/home-assistant.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.homeAssistant;
in
{
  options.customConfig.homelab.homeAssistant = with lib; {
    enable = mkEnableOption "Home Assistant Core smart home server";
    port = mkOption {
      type = types.port;
      default = 8123;
      description = "Port for Home Assistant to listen on.";
    };
    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = "Override the Home Assistant package (e.g. to pin a newer version for backup restore compatibility).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.home-assistant = {
      enable = true;
      package = lib.mkIf (cfg.package != null) cfg.package;
      openFirewall = true;
      extraComponents = [
        "default_config"
        "met"
        "tplink"
        "cync"
        "wyoming"
        "radio_browser"
        "google_translate"
        "google_generative_ai_conversation"
      ];
      config = {
        homeassistant = {
          name = "Home";
          unit_system = "us_customary";
          time_zone = "America/Chicago";
        };
        http.server_port = cfg.port;
        automation = "!include automations.yaml";
      };
    };
  };
}

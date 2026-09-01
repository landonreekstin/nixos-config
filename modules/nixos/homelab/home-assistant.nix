# ~/nixos-config/modules/nixos/homelab/home-assistant.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.homelab.homeAssistant;
in
{
  options.customConfig.homelab.homeAssistant = with lib; {
    enable = mkEnableOption "Home Assistant Core smart home server";
    # HA no longer reads http.server_port from YAML — port is managed in the UI
    # (Settings > System > Network). Keep this value in sync with the UI if changed;
    # it is still consumed by the nginx reverse proxy (reverse-proxy-mini.nix).
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
      # Copy configuration.yaml (rather than symlinking a read-only /nix/store file)
      # so preStart can strip the upstream module's http.server_host/server_port defaults —
      # see the sed below.
      configWritable = true;
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
        automation = "!include automations.yaml";
      };
    };

    # HA 2026.x moved http config (trusted_proxies, use_x_forwarded_for, port) to the UI
    # under Settings > System > Network and raises the "yaml_still_present_after_migration"
    # repair as long as any http: block is in configuration.yaml. Our Nix config no longer
    # sets any http.* keys, but nixpkgs' home-assistant module always emits defaults for
    # http.server_host and http.server_port from its option submodule. Strip the block
    # from the writable copy on every start.
    #
    # sed -i is blocked by the HA service's SystemCallFilter (fchown), so write to a temp
    # file and cat it back — cat doesn't fchown/chmod and preserves the original file's
    # owner and mode.
    systemd.services.home-assistant.preStart = lib.mkAfter ''
      _ha_cfg=${config.services.home-assistant.configDir}/configuration.yaml
      ${pkgs.gnused}/bin/sed '/^http:/,/^[a-z]/{ /^http:/d; /^[a-z]/!d; }' "$_ha_cfg" > "$_ha_cfg.new"
      cat "$_ha_cfg.new" > "$_ha_cfg"
      rm -f "$_ha_cfg.new"
    '';
  };
}

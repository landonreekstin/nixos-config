# ~/nixos-config/modules/nixos/homelab/home-assistant.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.homelab.homeAssistant;

  # python-kasa's get_protocol() builds its transport lookup key from device
  # family + encryption type only — login_version is captured in the connection
  # parameters and then ignored. IOT-family devices on current TP-Link firmware
  # advertise KLAP with login_version 2 and use the V2 auth hashes, so they get
  # paired with the V1 transport and authentication can never succeed. The
  # symptom is a Kasa device that is reachable and has correct credentials but
  # fails every login, leaving its HA entities permanently unavailable.
  #
  # The two layers are orthogonal: the message format stays IotProtocol, only
  # the crypto/handshake moves to KlapTransportV2. Verified 2026-09-01 against
  # two KL125 bulbs on the LAN — IotProtocol+KlapTransport raised
  # AuthenticationError, IotProtocol+KlapTransportV2 authenticated and completed
  # a full update().
  #
  # Present in python-kasa 0.10.2 and upstream master alike; nixpkgs unstable is
  # also 0.10.2, so no version bump fixes it. Drop this once upstream honours
  # login_version when selecting the KLAP transport.
  kasaAnchor = "protocol_transport_key = (";
  kasaPatched =
    "if protocol_name == \"IOT\" and ctype.encryption_type is DeviceEncryptionType.Klap and ctype.login_version == 2:\n"
    + "        return IotProtocol(transport=KlapTransportV2(config=config))\n"
    + "\n"
    + "    protocol_transport_key = (";

  withKasaKlapV2 = hass: hass.override {
    packageOverrides = _self: super: {
      python-kasa = super.python-kasa.overrideAttrs (old: {
        # --replace-fail so a nixpkgs bump that moves this anchor breaks the
        # build loudly instead of silently dropping the fix.
        postPatch = (old.postPatch or "") + ''
          substituteInPlace kasa/device_factory.py \
            --replace-fail ${lib.escapeShellArg kasaAnchor} ${lib.escapeShellArg kasaPatched}
        '';
      });
    };
  };

  basePackage = if cfg.package != null then cfg.package else pkgs.home-assistant;
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
      package = withKasaKlapV2 basePackage;
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

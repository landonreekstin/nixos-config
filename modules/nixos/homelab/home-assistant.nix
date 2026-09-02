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

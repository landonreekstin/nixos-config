# ~/nixos-config/modules/nixos/homelab/mullvad.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.mullvad;
in
{
  options.customConfig.homelab.mullvad = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Mullvad VPN daemon for system-wide VPN.";
    };
  };

  config = lib.mkIf cfg.enable {

    services.mullvad-vpn.enable = true;

    # Declaratively apply settings after the daemon starts.
    # Account login still requires a one-time manual `mullvad account login`.
    systemd.services.mullvad-daemon.postStart = let
      mullvad = config.services.mullvad-vpn.package;
    in ''
      while ! ${mullvad}/bin/mullvad status >/dev/null 2>&1; do sleep 1; done
      ${mullvad}/bin/mullvad auto-connect set on
      ${mullvad}/bin/mullvad lan set allow
    '';

  };
}

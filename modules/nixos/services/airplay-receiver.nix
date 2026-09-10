# ~/nixos-config/modules/nixos/services/airplay-receiver.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.customConfig.services.airplayReceiver;

  # UxPlay picks random ports unless told otherwise, which can't be expressed as a
  # static firewall rule. `-p` pins it to the legacy fixed set (TCP 7000/7001/7100,
  # UDP 6000/6001/7011) that openFirewall below opens, so the wrapper and the
  # firewall stay in sync. Extra args are passed through for live tweaking of the
  # GStreamer sink (e.g. `airplay -vs glimagesink` if the default misbehaves).
  airplay = pkgs.writeShellScriptBin "airplay" ''
    exec ${pkgs.uxplay}/bin/uxplay -p -n ${lib.escapeShellArg cfg.name} "$@"
  '';
in
{
  options.customConfig.services.airplayReceiver = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the UxPlay AirPlay mirroring receiver, letting iOS devices mirror
        their screen to this host over the LAN. Provides the `airplay` command;
        the receiver is started on demand rather than as a daemon, since it needs
        to render into the logged-in graphical session.
      '';
    };

    name = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "Name advertised to iOS in the Screen Mirroring list.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Open the fixed AirPlay ports used by the `airplay` wrapper's `-p` flag.
        mDNS (UDP 5353) is opened separately by services.avahi.openFirewall.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.uxplay airplay ];

    # iOS discovers AirPlay receivers over Bonjour; without a publishing mDNS
    # responder the host never appears in the Screen Mirroring list at all.
    services.avahi = {
      enable = true;
      openFirewall = true;
      publish = {
        enable = true;
        userServices = true;
      };
      nssmdns4 = true;
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ 7000 7001 7100 ];
      allowedUDPPorts = [ 6000 6001 7011 ];
    };
  };
}

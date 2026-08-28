# ~/nixos-config/hosts/blaney-pc/networking.nix
{ config, pkgs, lib, ... }:

let
  # Homelab WireGuard VPN via a KDE-toggleable NetworkManager profile (restricted peer,
  # 10.10.0.5, NAS-only). Flip to `false` to eval this host without the sops secret
  # present. Prerequisites, both already done for blaney-pc:
  #   1. blaney-pc's real age key replaces age1PLACEHOLDER_blaney-pc in .sops.yaml
  #   2. secrets/blaney-pc.yaml exists with `wg-nm-private-key` (Blaney's WG private key)
  blaneyWgVpn = true;
in
{
  customConfig.services = {
    ssh.enable = false;
    vscodeServer.enable = false;

    # Weekly automated git sync + rebuild, then power off. Desktop-safe settings:
    autoUpdate = {
      enable = true;
      shutdownAfterRebuild = true;   # power off after a successful update
      skipIfActiveSession = true;    # never rebuild/power-off while it's in use
      lowPriority = true;            # nice/ionice the rebuild
      persistent = false;            # don't fire a surprise rebuild+shutdown on next boot
    };

    # Homelab VPN as a KDE-toggleable NetworkManager WireGuard profile (restricted
    # peer 10.10.0.5, NAS-only). Gated by blaneyWgVpn at the top of this file.
    wireguard.nmClient = lib.mkIf blaneyWgVpn {
      enable = true;
      connectionName = "homelab-vpn";
      interfaceName = "wg-homelab";
      autoconnect = false;              # Blaney toggles it in the KDE network applet
      address = "10.10.0.5/32";
      dns = "192.168.1.76";             # NAS resolver -> .lan works (nginx-gated)
      sopsFile = ../../secrets/blaney-pc.yaml;
      peer = {
        publicKey = "Z1ZtZiXE59cBZvmjkvcWr5nlEtmHVJJ16P0pb4QtFiY=";
        endpoint = "68.184.198.204:51822";
        allowedIPs = "192.168.1.76/32;";  # restricted: NAS only
        persistentKeepalive = 25;
      };
    };
  };
}

# ~/nixos-config/hosts/blaney-pc/networking.nix
{ config, pkgs, lib, ... }:

let
  # Homelab WireGuard VPN as a NetworkManager profile Blaney toggles from the desktop
  # network applet (restricted peer 10.10.0.5, NAS-only).
  #
  # Flip to `false` to get this host rebuilding again if the sops secret can't be
  # decrypted — that happens if /etc/ssh/ssh_host_ed25519_key on blaney-pc is no longer
  # the key `secrets/blaney-pc.yaml` was encrypted to (see the PR for how to re-key).
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

    # Homelab VPN. Gated by blaneyWgVpn at the top of this file.
    wireguard.nmClient = lib.mkIf blaneyWgVpn {
      enable = true;
      connectionName = "homelab-vpn";
      interfaceName = "wg-homelab";
      autoconnect = false;              # Blaney toggles it in the network applet
      address = "10.10.0.5/32";
      sopsFile = ../../secrets/blaney-pc.yaml;

      # Deliberately no `dns`. As a restricted peer this host only routes 192.168.1.76
      # into the tunnel, and pf does not rdr port 53 on the legacy alias for restricted
      # peers (docs/networking.md) — pointing NM at it with ignore-auto-dns would take
      # Blaney's DNS down for as long as the VPN is on. Restricted peers reach homelab
      # services by IP, so `.lan` resolution is not needed here.
      peer = {
        publicKey = "Z1ZtZiXE59cBZvmjkvcWr5nlEtmHVJJ16P0pb4QtFiY=";
        endpoint = "68.184.198.204:51822";
        allowedIPs = "192.168.1.76/32;";  # restricted: NAS only
        persistentKeepalive = 25;         # he's behind NAT; keep the mapping alive
      };
    };
  };
}

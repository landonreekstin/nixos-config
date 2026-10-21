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

    # lando's SSH access for nix work, over the homelab VPN only (so only while Blaney has
    # it switched on). A separate `lando` account — never insideabush's — with sudo limited
    # to an allowlist and a desktop notification here on every connect/disconnect. See
    # modules/nixos/services/remote-admin.nix.
    remoteAdmin = lib.mkIf blaneyWgVpn {
      enable = true;
      interface = "wg-homelab";
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOIskZoPWjwNZiMshj1N4qsotaRneJH7Noa195EiZj3e lando@gaming-pc"
      ];
      # Own file, not blaney-pc.yaml: it can be created from any host with just the public
      # keys, while editing an existing sops file needs the admin key (asus-laptop only).
      passwordSopsFile = ../../secrets/blaney-pc-admin.yaml;
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
        # restricted: NAS only — plus lando's two gaming-pc peers (10.10.0.2 roaming,
        # 10.10.0.11 wg-nas), so his SSH into this host (remoteAdmin above) is accepted
        # by WireGuard and the replies go back into the tunnel. optiplex-fw passes only
        # tcp/22 from those two to 10.10.0.5; this host still can't reach them.
        allowedIPs = "192.168.1.76/32;10.10.0.2/32;10.10.0.11/32;";
        persistentKeepalive = 25;         # he's behind NAT; keep the mapping alive
      };
    };
  };
}

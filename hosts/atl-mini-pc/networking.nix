# ~/nixos-config/hosts/atl-mini-pc/networking.nix
{ config, pkgs, lib, ... }:

let
  # Flip to true once secrets/atl-mini-pc.yaml exists and is encrypted to this host's age key
  # (it is still a placeholder in .sops.yaml). Holds the Wi-Fi SSID/password and the VPN
  # private key. While false, only autoUpdate below is live. Steps: docs/hosts/atl-mini-pc.md.
  atlSecrets = false;
in
{
  config = lib.mkMerge [ {
  customConfig.services = {
    # lando's keys land on heather's account via modules/nixos/common/users-groups.nix.
    ssh.enable = true;
    vscodeServer.enable = true;

    # Homelab VPN, always on, so lando can `ssh atl` from gaming-pc (10.10.0.2 / .11) while
    # nobody is here to help. optiplex-fw has the peer and passes tcp/22 from those two.
    wireguard.client = lib.mkIf atlSecrets {
      enable = true;
      autoStart = true;
      interfaceName = "wg-homelab";
      address = "10.10.0.19/32";
      privateKeyFile = config.sops.secrets.wg-homelab-key.path;
      peer = {
        publicKey = "Z1ZtZiXE59cBZvmjkvcWr5nlEtmHVJJ16P0pb4QtFiY=";
        # A residential IP. If Spectrum ever changes it, this line is the fix, and
        # autoUpdate (or mom's `update && rebuild`) is how the fix reaches this machine.
        endpoint = "68.184.198.204:51822";
        # Split tunnel: lando's two gaming-pc peers (his SSH in), the NAS alias for
        # Jellyfin (http://192.168.1.76:8096) and Jellyseerr (:5055), and mini-server, which
        # pushes the offsite restic backup to the rest-server below. She is an ordinary
        # restricted peer on optiplex-fw. Everything else of hers stays local, so the VPN
        # can't break her internet. (If her own LAN ever has a device at .76, this /32 wins.)
        allowedIPs = [ "10.10.0.2/32" "10.10.0.11/32" "192.168.1.76/32" "192.168.100.103/32" ];
        persistentKeepalive = 25; # behind her router's NAT; keep the mapping open
      };
    };

    # Weekly git pull + rebuild from GitHub, which doesn't need the VPN, so a broken tunnel
    # (new home IP, re-keyed server) can still be repaired remotely.
    autoUpdate = {
      enable = true;
      skipIfActiveSession = true; # never rebuild under her
      lowPriority = true;
      persistent = true;          # catch up on boot if it was off Monday 03:00
    };
  };
  }

  (lib.mkIf atlSecrets {
    # Offsite backup target (Homelab 2.0 doc, Stage 0). mini-server pushes its HA, Vaultwarden,
    # game-server and Forgejo state here nightly with restic, encrypted on its side, so
    # nothing here can read it. APPEND-ONLY: a compromised pusher can add snapshots but
    # cannot delete old ones. No auth: the only clients that can reach it are the
    # WireGuard AllowedIPs above, and the port is open on wg-homelab alone.
    services.restic.server = {
      enable = true;
      appendOnly = true;
      listenAddress = "8000";
      extraFlags = [ "--no-auth" ];
    };
    networking.firewall.interfaces."wg-homelab".allowedTCPPorts = [ 8000 ];

    sops.secrets.wg-homelab-key = { };
    sops.secrets.wifi-env = { };   # WIFI_SSID=… and WIFI_PSK=… lines

    # System-wide Wi-Fi, so the machine is online (and on the VPN, and updating) after an
    # unattended reboot. Her original profile keeps its password in KWallet, which only
    # unlocks at her login. That profile stays; this one just outranks it.
    networking.networkmanager.ensureProfiles = {
      environmentFiles = [ config.sops.secrets.wifi-env.path ];
      profiles.home-wifi-system = {
        connection = {
          id = "home-wifi-system";
          type = "wifi";
          autoconnect = true;
          autoconnect-priority = 10;
          permissions = "";        # all users, no login needed
        };
        wifi = { mode = "infrastructure"; ssid = "$WIFI_SSID"; };
        wifi-security = { key-mgmt = "wpa-psk"; psk = "$WIFI_PSK"; };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };
    };
  })
  ];
}

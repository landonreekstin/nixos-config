# ~/nixos-config/modules/nixos/common/lan-records.nix
#
# Single source of truth for the .lan zone. NOT a module — a plain attrset,
# `import`ed by the two places that need to agree on these records:
#
#   modules/nixos/common/lan-hosts.nix  -> networking.extraHosts  (every client)
#   modules/nixos/homelab/dns.nix       -> Unbound local-data     (optiplex-nas)
#
# Before this file the two lists were maintained by hand and had already drifted.
{
  # Names served by optiplex-nas. The address is deliberately NOT stored here:
  # how you reach the NAS depends on which side of the firewall you sit on, so
  # each consumer supplies it (see lanHosts.nasAddress).
  nasNames = [
    "home" "nas" "jellyfin" "jellyseerr" "transmission"
    "radarr" "sonarr" "bazarr" "prowlarr" "nix-cache" "reader"
    # Music stack: music -> Navidrome (listen), ombi -> requests,
    # lidarr -> album manager, slskd -> Soulseek client.
    "lidarr" "music" "ombi" "slskd" "soularr"
    # Read-only HTTP file drop for VPN users (homelab/public-files.nix).
    "files"
    # Games: gamarr -> PC game + ROM requests and downloads, qbittorrent ->
    # the torrent client it imports from (Transmission serves the media stack).
    "gamarr" "qbittorrent"
  ];

  # Names whose address is the same from everywhere (mini-server, server subnet).
  # A list of pairs rather than an attrset, so generated output keeps this order
  # instead of being alphabetised by mapAttrsToList.
  fixedRecords = [
    { name = "mini.lan";          addr = "192.168.100.103"; }
    { name = "homeassistant.lan"; addr = "192.168.100.103"; }
    { name = "vaultwarden.lan";   addr = "192.168.100.103"; }
    { name = "dashboard.lan";     addr = "192.168.100.103"; }
  ];
}

# ~/nixos-config/hosts/gaming-pc/vars.nix
# Host-level flags shared by more than one of this host's config files.
# Plain attrset (not a module) — `let` cannot span files, so files that need a
# flag do `let vars = import ./vars.nix; in ...`.
{
  # Post-migration flag for reaching optiplex-nas over a dedicated LAN WireGuard tunnel.
  # Flip to `true` ONLY after all four steps are complete:
  #   1. optiplex-nas is physically on the 192.168.100.0/24 segment at 192.168.100.76.
  #   2. optiplex-fw has the updated pf.conf loaded and the 192.168.1.76 alias on re0.
  #   3. A wg-nas keypair has been generated and the public key added to
  #      /etc/hostname.wg0 on optiplex-fw as a peer with `allowed-ips 10.10.0.11/32`.
  #   4. The wg-nas private key has been added to secrets/gaming-pc.yaml as
  #      `wg-nas-private-key`.
  # When enabled, Samba traffic to the NAS is tunneled over WireGuard on the LAN
  # instead of traversing 192.168.1.x in cleartext.
  # Consumed by: networking.nix (wg-nas tunnel + sops secret), homelab.nix (NAS address).
  nasViaLanWg = true;
}

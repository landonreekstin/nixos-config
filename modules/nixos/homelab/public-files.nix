# ~/nixos-config/modules/nixos/homelab/public-files.nix
#
# A read-only file drop for VPN users, served over HTTP.
#
# Restricted WireGuard peers (see docs/networking.md) have no way to receive a
# file from the homelab. Samba is the wrong tool for them on three counts: pf
# deliberately withholds 445/139 from restricted peers, the one `storage` share
# is `read only = no` behind a single shared credential so it cannot be handed
# out read-only, and CIFS neither resumes a dropped transfer nor performs over a
# WAN link. Serving GET has no write path to get wrong, resumes for free via
# Range requests, and needs no firewall change at all — port 80 to the NAS is
# already in the restricted peers' pf allow-list.
#
# Full design and verification steps: docs/runbooks/nas-public-share.md
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.publicFiles;
in
{
  options.customConfig.homelab.publicFiles = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Serve a read-only, browsable file drop over HTTP at files.lan/public/.";
    };
    path = mkOption {
      type = types.str;
      default = "/mnt/storage/public";
      description = ''
        Directory served at /public/. Lives on the storage array so files can be
        hardlinked in from elsewhere on the same btrfs filesystem at no cost.
      '';
    };
    owner = mkOption {
      type = types.str;
      default = config.customConfig.user.name;
      defaultText = "config.customConfig.user.name";
      description = "Owner of the drop directory.";
    };
    serverAliases = mkOption {
      type = types.listOf types.str;
      default = [ "192.168.1.76" ];
      description = ''
        Extra Host header values this vhost answers to. The literal IP is not
        optional: restricted VPN peers resolve through 1.1.1.1 and cannot look up
        `.lan` at all, so they reach the NAS only by address — and nginx matches
        on Host. Without the alias they land on whichever vhost happens to be
        nginx's default (alphabetically first, currently bazarr.lan) instead of
        the file listing.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.path} 2775 ${cfg.owner} media -"
    ];

    services.nginx.virtualHosts."files.lan" = {
      inherit (cfg) serverAliases;
      locations."/public/" = {
        alias = "${cfg.path}/";
        extraConfig = ''
          autoindex on;
          autoindex_exact_size off;
          autoindex_localtime on;
          # GET/HEAD only -- nothing here should ever accept an upload.
          limit_except GET HEAD { deny all; }
        '';
      };
    };
  };
}

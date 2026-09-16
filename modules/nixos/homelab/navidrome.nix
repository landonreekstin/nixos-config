# ~/nixos-config/modules/nixos/homelab/navidrome.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.navidrome;
  mediaCfg = config.customConfig.homelab.mediaSetup;
in
{
  options.customConfig.homelab.navidrome = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable Navidrome, a music server and streamer for the library Lidarr
        fills. Serves its own web UI and the Subsonic API, so phone clients
        (Symfonium, substreamer, play:Sub, ...) work against it directly.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 4533;
      description = "Port Navidrome listens on. Fronted by nginx as music.lan.";
    };

    musicFolder = mkOption {
      type = types.str;
      default = "${mediaCfg.storagePath}/media/music";
      defaultText = literalExpression ''"''${config.customConfig.homelab.mediaSetup.storagePath}/media/music"'';
      description = "Music library root. Created and owned by media-setup.nix; Navidrome only reads it.";
    };
  };

  config = lib.mkIf cfg.enable {

    services.navidrome = {
      enable = true;
      settings = {
        # Bind on all interfaces, matching lidarr/ombi/slskd which all listen
        # broadly. nginx still fronts it as music.lan, but the direct
        # host:port must also work: VPN peers and anything without the .lan
        # zone in its resolver reach these services by IP, and a loopback-only
        # bind silently breaks exactly those clients while music.lan keeps
        # working from the NAS itself.
        Address = "0.0.0.0";
        Port = cfg.port;
        MusicFolder = cfg.musicFolder;
      };
    };

    # Library dirs are 2775 lando:media. Navidrome bind-mounts MusicFolder
    # read-only anyway, but the group membership keeps it readable regardless of
    # what umask Lidarr's imports land with.
    users.users.navidrome.extraGroups = [ "media" ];

    # The upstream module emits a tmpfiles rule creating MusicFolder as
    # ":700 :navidrome:navidrome". media-setup.nix already declares that same
    # path as "2775 lando media" in 00-nixos.conf, and two /etc/tmpfiles.d
    # fragments claiming one path is a duplicate-line warning whose winner
    # depends on filename ordering. Re-declare navidrome's own state dirs and
    # simply leave MusicFolder out, so there is exactly one rule for it.
    systemd.tmpfiles.settings.navidromeDirs = lib.mkForce {
      "/var/lib/navidrome"."d" = {
        mode = "700";
        user = "navidrome";
        group = "navidrome";
      };
      "/var/lib/navidrome/cache"."d" = {
        mode = "700";
        user = "navidrome";
        group = "navidrome";
      };
    };

  };
}

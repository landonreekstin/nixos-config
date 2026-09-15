# ~/nixos-config/modules/nixos/homelab/slskd.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.slskd;
  mediaCfg = config.customConfig.homelab.mediaSetup;
in
{
  options.customConfig.homelab.slskd = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable slskd, a Soulseek client with a web UI and REST API. Exists
        because public torrent indexers are thin on music: soularr drives this
        from Lidarr's wanted list (homelab/soularr.nix) as a second source
        alongside Prowlarr/Transmission.
      '';
    };

    webPort = mkOption {
      type = types.port;
      default = 5030;
      description = "Port for the slskd web UI and REST API. Fronted by nginx as slskd.lan.";
    };

    listenPort = mkOption {
      type = types.port;
      default = 50300;
      description = ''
        Soulseek network listen port. Note this host routes everything through
        Mullvad, which no longer offers port forwarding, so incoming peer
        connections do not arrive regardless of what is set here - see
        docs/music.md.
      '';
    };

    credentialsFile = mkOption {
      type = types.path;
      example = "/run/secrets/slskd-credentials";
      description = ''
        Environment file defining SLSKD_SLSK_USERNAME and SLSKD_SLSK_PASSWORD
        (the slsknet.org account) plus SLSKD_USERNAME and SLSKD_PASSWORD (the
        web UI login). Required: slskd cannot connect without a Soulseek account.
      '';
    };

    apiKey = mkOption {
      type = types.str;
      # Deliberately in the world-readable nix store, and pinned to 127.0.0.1
      # below. It only grants access to slskd's API from this machine, and
      # anyone who can read the store already has a shell here. The Soulseek
      # account password - the secret that actually matters - lives in sops and
      # arrives through credentialsFile.
      default = "1c1de81751184757bf280066612a94858b6bfc6323fb2124";
      description = "Localhost-only API key used by soularr to drive slskd.";
    };

    shareMusic = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Share the music library read-only on the Soulseek network. Soulseek is a
        reciprocal network; sharing nothing gets you deprioritised by peers.
      '';
    };

    downloadDir = mkOption {
      type = types.str;
      default = "${mediaCfg.storagePath}/downloads/slskd";
      defaultText = literalExpression ''"''${config.customConfig.homelab.mediaSetup.storagePath}/downloads/slskd"'';
      description = "Where slskd puts completed downloads. soularr reads from here.";
    };

    incompleteDir = mkOption {
      type = types.str;
      default = "${mediaCfg.storagePath}/downloads/slskd-incomplete";
      defaultText = literalExpression ''"''${config.customConfig.homelab.mediaSetup.storagePath}/downloads/slskd-incomplete"'';
      description = ''
        In-flight downloads. On storagePath rather than cachePath for the same
        reason Transmission's is - see the incomplete-dir note in
        homelab/transmission.nix.
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    services.slskd = {
      enable = true;
      environmentFile = cfg.credentialsFile;
      # Upstream declares `domain` with no default, so it has to be set even to
      # opt out. null is the opt-out: it suppresses slskd's own nginx vhost,
      # which would otherwise bypass the reverse-proxy-nas.nix registry that
      # every other service here is listed in.
      domain = null;
      # Opens the Soulseek listen port, not the web port. Inert on this host
      # (the NixOS firewall is off; optiplex-fw filters) but kept for correctness.
      openFirewall = true;

      settings = {
        web = {
          port = cfg.webPort;
          authentication.api_keys.soularr = {
            key = cfg.apiKey;
            role = "readwrite";
            # Must include the IPv4-mapped IPv6 form. slskd's listener reports a
            # loopback client as ::ffff:127.0.0.1, and a plain 127.0.0.1/32
            # network never matches it because the address families differ - the
            # symptom is every single API call 401ing with "not included in CIDR
            # range(s) for API key soularr".
            cidr = "127.0.0.1/32,::1/128,::ffff:127.0.0.1/128";
          };
        };
        soulseek.listen_port = cfg.listenPort;
        directories = {
          downloads = cfg.downloadDir;
          incomplete = cfg.incompleteDir;
        };
        shares.directories = lib.optional cfg.shareMusic "${mediaCfg.storagePath}/media/music";
      };
    };

    users.users.slskd.extraGroups = [ "media" ];

    systemd.services.slskd.serviceConfig = {
      # Downloads land in a 2775 lando:media SGID dir shared with Lidarr and
      # soularr; without this the group write bit is dropped and soularr (which
      # runs as slskd:media) cannot move the finished album out.
      UMask = "0002";

      # Upstream sets PrivateUsers = true. That maps only the unit's own uid/gid
      # into the user namespace, so slskd loses its supplementary "media"
      # membership and cannot write into the shared download dirs.
      PrivateUsers = lib.mkForce false;

      # Upstream derives ReadOnlyPaths from shares.directories through a
      # builtins.split whose result is a list of match groups, i.e. a nested
      # list. Set the plain string list instead.
      ReadOnlyPaths = lib.mkForce (lib.optional cfg.shareMusic "${mediaCfg.storagePath}/media/music");
    };

    # Deliberately NOT using services.slskd.domain / .nginx: those build their
    # own virtual host and would bypass the reverse-proxy-nas.nix registry that
    # every other service here is listed in.

  };
}

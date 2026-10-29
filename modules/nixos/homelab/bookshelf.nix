# ~/nixos-config/modules/nixos/homelab/bookshelf.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.bookshelf;
  mediaCfg = config.customConfig.homelab.mediaSetup;
  downloadsPath = "${mediaCfg.storagePath}/downloads";
  envFile = "/run/bookshelf/env";
  # Not an option: the port lives in the container's own config.xml, so a
  # Nix-side setting would not move the listener. Fronted as bookshelf.lan.
  port = 8787;
in
{
  options.customConfig.homelab.bookshelf = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable Bookshelf, the audiobook manager (the *arr that grabs books).
        It is a maintained fork of Readarr, which upstream retired in 2025 along
        with the metadata server stock Readarr depends on. Not in nixpkgs, so
        this runs the upstream container.
      '';
    };

    image = mkOption {
      type = types.str;
      # The hardcover-* tags use the Hardcover-backed metadata server
      # (hardcover.bookinfo.pro, baked into the image as METADATA_URL).
      # Bump the tag AND the digest together - see docs/audiobooks.md.
      default = "ghcr.io/pennydreadful/bookshelf:hardcover-v0.4.21.182@sha256:67498dd5ece516867d72ee642abd6c1a66b36a135c8f7da0127109564372beb1";
      description = "Bookshelf container image, pinned by tag and digest.";
    };

    libraryPath = mkOption {
      type = types.str;
      default = "${mediaCfg.storagePath}/media/audiobooks";
      defaultText = literalExpression ''"''${config.customConfig.homelab.mediaSetup.storagePath}/media/audiobooks"'';
      description = "Audiobook library root. Created by media-setup.nix; Bookshelf writes it, Audiobookshelf reads it.";
    };
  };

  config = lib.mkIf cfg.enable {

    users.users.bookshelf = {
      isSystemUser = true;
      group = "bookshelf";
    };
    users.groups.bookshelf = { };

    systemd.tmpfiles.rules = [
      "d /var/lib/bookshelf 0750 bookshelf bookshelf -"
    ];

    virtualisation.docker.enable = true;
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers.bookshelf = {
      image = cfg.image;
      autoStart = true;
      # Host networking, like kokoro in article2pod.nix: Transmission is
      # reachable at 127.0.0.1:9091, DNS goes through the host's Unbound, and
      # the UI listens broadly like every other *arr here.
      extraOptions = [ "--network=host" ];
      # Downloads and library are mounted at the SAME paths they have on the
      # host. Transmission reports host paths for finished torrents, and with
      # identical paths inside the container they resolve as-is - no remote
      # path mapping to configure. The whole downloads/ tree goes in so the
      # import can hardlink rather than copy.
      volumes = [
        "/var/lib/bookshelf:/config"
        "${downloadsPath}:${downloadsPath}"
        "${cfg.libraryPath}:${cfg.libraryPath}"
      ];
      environment = {
        TZ = config.time.timeZone;
        # linuxserver base image: imports must stay group-writable for the
        # media group, the same reason arr.nix sets UMask=0002 on the native
        # *arrs (Docker otherwise gives the process its own 0022).
        UMASK = "002";
      };
      # PUID/PGID are numeric, and neither bookshelf (unnumbered system user)
      # nor media has a pinned id, so they are resolved at start - the same
      # approach soularr.nix takes for its --user.
      environmentFiles = [ envFile ];
    };

    # preStart runs before `docker run`, which is when Docker reads --env-file.
    systemd.services.docker-bookshelf.preStart = ''
      mkdir -p /run/bookshelf
      {
        echo "PUID=$(${pkgs.coreutils}/bin/id -u bookshelf)"
        echo "PGID=$(${pkgs.getent}/bin/getent group media | ${pkgs.coreutils}/bin/cut -d: -f3)"
      } > ${envFile}
    '';

    networking.firewall.allowedTCPPorts = [ port ];
  };
}

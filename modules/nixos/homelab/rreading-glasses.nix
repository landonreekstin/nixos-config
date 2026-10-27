# ~/nixos-config/modules/nixos/homelab/rreading-glasses.nix
{ config, lib, ... }:

let
  cfg = config.customConfig.homelab.rreadingGlasses;
  dbName = "rreading-glasses";
in
{
  options.customConfig.homelab.rreadingGlasses = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Self-host rreading-glasses, the Hardcover-backed book metadata proxy
        Bookshelf searches through. The shared public instance
        (hardcover.bookinfo.pro, baked into the Bookshelf image) is rate-limited
        to the point of timing out on every search, so this runs a private one
        against our own Hardcover API token. Bookshelf is pointed at it by
        bookshelf-provision.nix.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 8788;
      description = "Port the metadata proxy listens on (loopback use only; Bookshelf is host-networked).";
    };

    image = mkOption {
      type = types.str;
      # The `hardcover` tag is the Hardcover build (`latest` is Goodreads).
      # Upstream only publishes moving tags, so this pins the digest alone.
      default = "blampe/rreading-glasses@sha256:3f017a51d9007b715303a20f481c822e4df66485fc9e5f57f6fdf1de840dc02f";
      description = "rreading-glasses container image (hardcover build), pinned by digest.";
    };

    hardcoverAuthFile = mkOption {
      type = types.path;
      description = ''
        File holding the whole Hardcover Authorization header, including the
        `Bearer ` prefix. Hardcover expires API tokens every January 1, so this
        needs regenerating yearly - see docs/audiobooks.md. Must be readable
        by uid 65532, the image's built-in nonroot user.
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    # Its only state is a metadata cache that grows as it is queried, so a
    # loopback-only database with trust auth for its one role is enough - there
    # is no password to manage, and nothing in it is private.
    services.postgresql = {
      enable = true;
      ensureDatabases = [ dbName ];
      ensureUsers = [{
        name = dbName;
        ensureDBOwnership = true;
      }];
      authentication = lib.mkAfter ''
        host ${dbName} ${dbName} 127.0.0.1/32 trust
      '';
    };

    virtualisation.docker.enable = true;
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers.rreading-glasses = {
      image = cfg.image;
      autoStart = true;
      entrypoint = "/main";
      cmd = [ "serve" "--hardcover-auth-file=/run/secrets/hardcover-auth" ];
      volumes = [ "${cfg.hardcoverAuthFile}:/run/secrets/hardcover-auth:ro" ];
      # Host networking so it reaches Postgres on 127.0.0.1 and Bookshelf
      # reaches it the same way. The port is deliberately not opened in the
      # firewall.
      # --memory: the app sizes its in-memory cache from the cgroup limit and
      # would otherwise claim most of the host's RAM (upstream recommends a cap).
      extraOptions = [ "--network=host" "--memory=512m" ];
      environment = {
        PORT = toString cfg.port;
        POSTGRES_HOST = "127.0.0.1";
        POSTGRES_USER = dbName;
        POSTGRES_DATABASE = dbName;
      };
    };

    # postgresql.target, not .service: the target also covers
    # postgresql-setup.service, which is what creates the role and database.
    systemd.services.docker-rreading-glasses = {
      after = [ "postgresql.target" ];
      requires = [ "postgresql.target" ];
    };
  };
}

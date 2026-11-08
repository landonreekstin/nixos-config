# ~/nixos-config/modules/nixos/homelab/forgejo.nix
# Forgejo: our own git server, for game repos that lando and Blaney work on together
# (prin-rpg first). HTTP only, on one port. Everyone, VPN peers included, reaches it at
# http://192.168.1.76:3000, which optiplex-fw redirects to this host
# (docs/networking.md "Forgejo"). No SSH: git runs over HTTP with an access token, and
# WireGuard already encrypts the VPN leg.
#
# Accounts are made by hand (registration is off); docs/forgejo.md has the steps.
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.forgejo;
  fj = config.services.forgejo;

  # The forgejo CLI (`sudo forgejo-admin user create ...`) as the service user, against
  # the live app.ini. The package's own binary isn't on PATH and needs both of these.
  adminCli = pkgs.writeShellScriptBin "forgejo-admin" ''
    exec /run/wrappers/bin/sudo -u ${fj.user} ${lib.getExe fj.package} \
      --work-path ${fj.stateDir} --config ${fj.customDir}/conf/app.ini admin "$@"
  '';
in
{
  options.customConfig.homelab.forgejo = with lib; {
    enable = mkEnableOption "Forgejo git server";
    port = mkOption {
      type = types.port;
      default = 3000;
      description = "HTTP port for the web UI and git over HTTP.";
    };
    publicUrl = mkOption {
      type = types.str;
      default = "http://192.168.1.76:${toString cfg.port}/";
      description = ''
        The address everyone uses (Forgejo's ROOT_URL, so clone URLs and links show it).
        The host's own address (192.168.100.103) is unreachable for restricted VPN peers;
        the firewall's legacy NAS alias is the one address they all route.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.forgejo = {
      enable = true;
      database.type = "sqlite3";
      lfs.enable = true;
      settings = {
        server = {
          HTTP_ADDR = "0.0.0.0";
          HTTP_PORT = cfg.port;
          ROOT_URL = cfg.publicUrl;
          DOMAIN = "192.168.1.76";
          DISABLE_SSH = true;
        };
        service = {
          DISABLE_REGISTRATION = true;
          REQUIRE_SIGNIN_VIEW = true;
        };
        # Merge commits only, like the GitHub repos were.
        "repository.pull-request".DEFAULT_MERGE_STYLE = "merge";
        session.COOKIE_SECURE = false;
        # No outgoing mail on this host.
        mailer.ENABLED = false;
      };

      # Daily consistent dump (database + repos), taken before the 04:00 restic run so
      # game-backup.nix carries it to the NAS.
      dump = {
        enable = true;
        interval = "03:30";
        type = "tar.zst";
        age = "3d";
      };
    };

    services.restic.backups.mini-server.paths =
      lib.mkIf config.customConfig.homelab.gameBackup.enable [ config.services.forgejo.dump.backupDir ];

    environment.systemPackages = [ adminCli ];

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}

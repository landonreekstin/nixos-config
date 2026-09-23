# ~/nixos-config/modules/nixos/homelab/gamarr.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.gamarr;
  mediaCfg = config.customConfig.homelab.mediaSetup;
  arrCfg = config.customConfig.homelab.arr;
  qbtCfg = config.customConfig.homelab.qbittorrent;

  # Prowlarr writes its key here on first run. Note this is NOT the
  # .config/<App>/config.xml path Lidarr and Bazarr use - the nixpkgs Prowlarr
  # module points the app straight at its StateDirectory.
  prowlarrConfigXml = "/var/lib/prowlarr/config.xml";

  # Where the privileged pre-start drops the key for the service proper.
  prowlarrKeyFile = "${cfg.dataDir}/.prowlarr-api-key";

  romsDir  = "${cfg.libraryPath}/roms";
  vaultDir = "${cfg.libraryPath}/vault";

  # Gamarr's own download/staging directory. A dedicated category dir under
  # downloads/torrents, like the lidarr one in media-setup.nix, so its grabs are
  # separable from everything else Transmission is running.
  #
  # QB_SAVE_PATH names it despite the qBittorrent-flavoured name: internally it
  # is the single staging path for every client. It is what Gamarr passes to
  # Transmission as the per-torrent download location (internal/download/
  # manager.go:122), where it stages direct Myrient/Vimm downloads (manager.go:
  # 464), and the source side of the hardlink trial in the settings UI
  # (internal/api/handlers_extra.go:201).
  # Single-sourced from qBittorrent when it is the client: Gamarr has NO remote
  # path mapping, so the path it thinks a torrent landed at and the path the
  # client reports must be byte-identical or every import fails.
  stagingDir =
    if qbtCfg.enable
    then qbtCfg.downloadDir
    else "${mediaCfg.storagePath}/downloads/torrents/gamarr";

  # Prowlarr runs with DynamicUser=yes, so /var/lib/prowlarr is a symlink into
  # /var/lib/private, which is 0700 root:root. config.xml itself is 0644, but an
  # unprivileged process cannot traverse the parent to reach it - so this cannot
  # be done from the service's own user the way lidarr-provision.nix does it
  # (that unit runs as root).
  #
  # Hence a privileged pre-start: ExecStartPre entries prefixed with "+" run as
  # root with the sandboxing lifted, which is the documented way to do exactly
  # this. It copies the key out to a file owned by the service user, and nothing
  # else about the unit gains privilege.
  preStartScript = pkgs.writeShellScript "gamarr-pre-start" ''
    set -euo pipefail

    sed=${pkgs.gnused}/bin/sed

    log() { echo "[gamarr] $*" >&2; }

    # qBittorrent's unit is Type=simple, so systemd calls it active the moment
    # the process forks - well before its WebUI binds. After=qbittorrent.service
    # therefore orders the start but guarantees nothing about readiness, and
    # Gamarr logs a pair of connection-refused errors on every boot. It does
    # recover on the watcher's next 30s tick, so this is purely about not
    # shipping alarming-looking errors in the journal at every boot.
    ${lib.optionalString qbtCfg.enable ''
      for _ in $(seq 1 30); do
        if ${pkgs.curl}/bin/curl -sf -o /dev/null --max-time 2 \
             "http://127.0.0.1:${toString qbtCfg.webPort}/api/v2/app/version"; then
          break
        fi
        sleep 1
      done
    ''}

    # Prowlarr only writes <ApiKey> once its first-run bootstrap finishes, which
    # can trail our start even with After=prowlarr.service. Wait, but bounded: a
    # missing key costs the Prowlarr/Torznab sources only - the Myrient and Vimm
    # sources need no key and would still work - so this must never become a
    # permanent boot block.
    KEY=""
    for _ in $(seq 1 30); do
      if [ -r "${prowlarrConfigXml}" ]; then
        KEY=$($sed -n 's:.*<ApiKey>\(.*\)</ApiKey>.*:\1:p' "${prowlarrConfigXml}" || true)
        [ -n "$KEY" ] && break
      fi
      sleep 2
    done

    if [ -n "$KEY" ]; then
      umask 0077
      printf 'PROWLARR_API_KEY=%s\n' "$KEY" > "${prowlarrKeyFile}"
      chown ${cfg.user}:${cfg.group} "${prowlarrKeyFile}"
      log "Prowlarr API key published to ${prowlarrKeyFile}"
    else
      # Leave no stale key behind: a rotated-away key that still parsed once
      # would otherwise keep being handed to Gamarr as though it were current.
      rm -f "${prowlarrKeyFile}"
      log "WARNING: no <ApiKey> in ${prowlarrConfigXml} after 60s;"
      log "WARNING: starting without Prowlarr - only the DDL/scrape sources will return hits."
    fi
  '';
in
{
  options.customConfig.homelab.gamarr = with lib; {
    enable = mkEnableOption "Gamarr, an *arr-style manager for PC games and ROMs";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ../../../pkgs/gamarr { };
      defaultText = literalExpression "pkgs.callPackage ../../../pkgs/gamarr { }";
      description = "The gamarr package to use.";
    };

    port = mkOption {
      type = types.port;
      default = 5001;
      description = "Port for the Gamarr web UI.";
    };

    user = mkOption {
      type = types.str;
      default = "gamarr";
      description = "User account under which Gamarr runs.";
    };

    group = mkOption {
      type = types.str;
      default = "gamarr";
      description = "Group under which Gamarr runs.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/gamarr";
      description = "State directory for Gamarr's SQLite database and settings.";
    };

    libraryPath = mkOption {
      type = types.str;
      description = ''
        Library root. Gamarr sorts ROMs into <literal>roms/&lt;platform&gt;/</literal>
        and PC games into <literal>vault/</literal> beneath this. Must be on the
        same filesystem as the download directory for hardlink imports.
      '';
    };

    rawgKeyFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Path to a file containing <literal>RAWG_API_KEY=...</literal>, used for
        cover art, descriptions and the release calendar. Gamarr runs without
        it, just without metadata. Managed by sops-nix.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users = lib.mkIf (cfg.user == "gamarr") {
      gamarr = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.dataDir;
      };
    };
    users.groups = lib.mkIf (cfg.group == "gamarr") { gamarr = { }; };

    systemd.services.gamarr = {
      description = "Gamarr game and ROM manager";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ]
        ++ lib.optional arrCfg.prowlarr.enable "prowlarr.service"
        ++ lib.optional config.customConfig.homelab.transmission.enable "transmission.service"
        ++ lib.optional qbtCfg.enable "qbittorrent.service"
        ++ lib.optional (cfg.rawgKeyFile != null) "sops-nix.service";
      wants = lib.optional (cfg.rawgKeyFile != null) "sops-nix.service";

      # 7z and unrar are shelled out to for EXTRACT_ARCHIVES (internal/download/
      # manager.go:963-965). nixpkgs' p7zip is built without the non-free RAR
      # codec, and PC game releases are routinely .rar, so unrar has to be here
      # too - 7z alone would fail exactly on the releases that need extracting.
      path = [ pkgs.p7zip pkgs.unrar ];

      environment = {
        GAMARR_PORT = toString cfg.port;
        DATA_DIR = cfg.dataDir;

        GAMES_ROMS_PATH = romsDir;
        GAMES_VAULT_PATH = vaultDir;
        QB_SAVE_PATH = stagingDir;


        # Hardlink keeps the torrent seeding and costs no extra disk; storagePath
        # is one btrfs filesystem, so the link always resolves. Fall back to a
        # copy rather than erroring out if that ever stops being true.
        IMPORT_MODE = "hardlink";
        IMPORT_HARDLINK_FALLBACK = "copy";
        EXTRACT_ARCHIVES = "true";

        # Gamarr is qBittorrent-only on the import side: watchGameTorrent and
        # the orphan watcher both poll m.qb exclusively, and the Transmission
        # client only ever implements AddTorrent. Pointing this at a real qBit
        # is what makes a grab actually complete, import and organise.
        #
        # QB_URL also has a non-empty default (http://qbittorrent:8080) and is
        # treated as configured whenever set, so it is never safe to leave alone:
        # unset, it retries a host that does not resolve forever. Upstream reads
        # it with envStrAllowEmpty so "" disables the client outright.
        QB_URL = lib.optionalString qbtCfg.enable "http://127.0.0.1:${toString qbtCfg.webPort}";
        QB_CATEGORY = "games";
        TRANSMISSION_URL = "http://127.0.0.1:9091/transmission/rpc";
        PROWLARR_URL = "http://127.0.0.1:9696";
      }
      // lib.optionalAttrs config.customConfig.homelab.flaresolverr.enable {
        # Vimm gates its download form behind Cloudflare Turnstile; without this
        # that source can search but cannot resolve a download.
        FLARESOLVERR_URL = "http://127.0.0.1:8191";
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;

        # "+" runs this as root with sandboxing lifted - see the note on
        # preStartScript for why that is unavoidable here.
        ExecStartPre = [ "+${preStartScript}" ];
        ExecStart = lib.getExe cfg.package;

        # The key file is optional ("-"): Gamarr is useful without Prowlarr, and
        # the pre-start deliberately does not create it when no key was found.
        EnvironmentFile = [ "-${prowlarrKeyFile}" ]
          ++ lib.optional (cfg.rawgKeyFile != null) "-${cfg.rawgKeyFile}";

        Restart = "on-failure";
        RestartSec = 10;
        StateDirectory = "gamarr";
        WorkingDirectory = cfg.dataDir;

        # Imports create the per-platform directories under roms/. At the default
        # 0022 the group write bit is dropped and nothing else in the media group
        # can manage what lands there - same reason as radarr in arr.nix.
        UMask = "0002";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        # NOT RestrictSUIDSGID: imports replicate the source directory's mode
        # (fileops/import.go uses info.Mode()), and every directory under
        # storagePath is 2775 by the media-group convention in media-setup.nix.
        # That makes the call mkdirat(..., 02775), which this option rejects
        # with EPERM - every PC import failed at "Organize failed: mkdir ...
        # operation not permitted". NoNewPrivileges above is what actually
        # blocks privilege escalation here; gamarr is already in the media
        # group, so an SGID-media file gains it nothing.
        # One writable path spanning BOTH the staging dir and the library, not
        # one entry each: systemd turns every ReadWritePaths entry into its own
        # bind mount, and the kernel refuses to hardlink across bind mounts even
        # when they are the same filesystem underneath. Two entries here fail
        # every import with EXDEV - Gamarr detects this at startup and warns.
        #
        # This is no wider than the DAC reality: gamarr is in the media group,
        # and every directory under storagePath is 2775 <user>:media, so the group
        # already grants write. The media tree is the data worth protecting, and
        # Gamarr has no business in it, so it is mapped back to read-only.
        ReadWritePaths = [ cfg.dataDir mediaCfg.storagePath ];
        ReadOnlyPaths = [ "${mediaCfg.storagePath}/media" ];
      };
    };
  };
}

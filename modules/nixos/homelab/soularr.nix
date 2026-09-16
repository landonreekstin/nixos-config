# ~/nixos-config/modules/nixos/homelab/soularr.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.soularr;
  slskdCfg = config.customConfig.homelab.slskd;
  mediaCfg = config.customConfig.homelab.mediaSetup;

  stateDir = "/var/lib/soularr";
  configXml = "/var/lib/lidarr/.config/Lidarr/config.xml";
  docker = "${config.virtualisation.docker.package}/bin/docker";

  runScript = pkgs.writeShellScript "soularr-run" ''
    set -euo pipefail

    sed=${pkgs.gnused}/bin/sed

    log() { echo "[soularr] $*" >&2; }

    # Lidarr mints its API key on first run and keeps it in config.xml, so it
    # cannot be a nix-store value; read it fresh on every start (same approach
    # as homelab/lidarr-provision.nix).
    KEY=$($sed -n 's:.*<ApiKey>\(.*\)</ApiKey>.*:\1:p' ${configXml})
    if [ -z "$KEY" ]; then
      log "ERROR: could not read <ApiKey> from ${configXml}; is Lidarr running?"
      exit 1
    fi

    # ---------------------------------------------------------------
    # The two download_dir keys are TWO VIEWS OF ONE DIRECTORY, not two
    # directories. This is the single easiest thing here to get wrong, and
    # getting it wrong fails in a way that looks like something else entirely.
    #
    # From soularr's source (soularr.py ~line 776):
    #     import_folder_fullpath = slskd_download_dir  + folder_name   # writes here
    #     lidarr_import_fullpath = lidarr_download_dir + folder_name   # tells Lidarr this
    #
    # So it collects the album into a subfolder of the SLSKD download dir and
    # never writes anywhere else; [Lidarr] download_dir is purely a path
    # translation - "what does that same directory look like to Lidarr?".
    # Lidarr runs natively here, so it is the plain host path.
    #
    # Point it at some other directory and Lidarr reports
    #   "Folder/File specified for import scan [...] doesn't exist"
    # on every single album, because it is being handed a path that by
    # construction nothing ever creates.
    # ---------------------------------------------------------------
    ${pkgs.coreutils}/bin/install -m 0640 -o slskd -g media /dev/null ${stateDir}/config.ini
    cat > ${stateDir}/config.ini <<EOF
    [Lidarr]
    api_key = $KEY
    host_url = http://127.0.0.1:${toString config.services.lidarr.settings.server.port}
    download_dir = ${slskdCfg.downloadDir}
    disable_sync = False

    [Slskd]
    api_key = ${slskdCfg.apiKey}
    host_url = http://127.0.0.1:${toString slskdCfg.webPort}
    url_base = /
    download_dir = /downloads
    delete_searches = False
    stalled_timeout = 3600
    remote_queue_timeout = 300

    [Release Settings]
    use_selected_lidarr_release = False
    use_most_common_tracknum = True
    allow_multi_disc = True
    accepted_countries = Europe,Japan,United Kingdom,United States,[Worldwide],Australia,Canada
    skip_region_check = False
    accepted_formats = CD,Digital Media,Vinyl

    [Search Settings]
    search_timeout = 5000
    maximum_peer_queue = 50
    minimum_peer_upload_speed = 0
    minimum_filename_match_ratio = 0.8
    minimum_search_interval = 5
    allowed_filetypes = ${cfg.allowedFiletypes}
    album_prepend_artist = False
    search_type = incrementing_page
    number_of_albums_to_grab = ${toString cfg.albumsPerRun}
    search_source = missing
    failed_import_denylist = True

    [Download Settings]
    download_filtering = True
    use_extension_whitelist = False
    extensions_whitelist = lrc,nfo,txt
    rename_download_folders = True

    [Logging]
    level = INFO
    format = [%(levelname)s|%(module)s|L%(lineno)d] %(asctime)s: %(message)s
    datefmt = %Y-%m-%dT%H:%M:%S%z
    log_to_file = True
    log_file = soularr.log
    max_bytes = 1048576
    backup_count = 3
    EOF

    # ---------------------------------------------------------------
    # Run as slskd:media rather than root. soularr moves and renames files
    # inside slskd's download dir, and root-owned 0755 results would be
    # un-importable (and un-deletable) by Lidarr, which runs as lidarr:media.
    # The ids are resolved here rather than baked in because slskd is an
    # unnumbered system user.
    #
    # This is also why soularr is a hand-written unit instead of an
    # oci-containers entry like article2pod's kokoro container:
    # virtualisation.oci-containers has no way to express --user.
    # ---------------------------------------------------------------
    uid=$(${pkgs.coreutils}/bin/id -u slskd)
    gid=$(${pkgs.getent}/bin/getent group media | ${pkgs.coreutils}/bin/cut -d: -f3)

    # ---------------------------------------------------------------
    # umask 0002 inside the container, via an entrypoint wrapper.
    #
    # Every other service in this stack gets this from systemd's UMask=, but
    # that does not reach a container - Docker gives the process its own 0022.
    # The result is that the album folder soularr assembles is drwxr-sr-x,
    # group "media" has no write bit, and Lidarr (which is in
    # media) can COPY the tracks into the library but cannot then unlink the
    # sources. Lidarr treats that as a failed import and rolls the whole thing
    # back, leaving orphans in both directories and zero trackfiles registered.
    # The symptom in its log is:
    #   UnauthorizedAccessException ... Permission denied
    #
    # The image's own entrypoint is `tini -g --` with cmd /app/run.sh; this
    # wraps it rather than replacing it so tini still reaps children.
    # ---------------------------------------------------------------
    log "Starting soularr as $uid:$gid (interval ${toString cfg.interval}s)"
    exec ${docker} run --rm --name soularr \
      --network=host \
      --user "$uid:$gid" \
      --entrypoint /bin/sh \
      -e TZ="${config.time.timeZone}" \
      -e SCRIPT_INTERVAL="${toString cfg.interval}" \
      -e WEBUI_ENABLED="true" \
      -e WEBUI_PORT="${toString cfg.webPort}" \
      -v ${stateDir}:/data \
      -v ${slskdCfg.downloadDir}:/downloads \
      ${cfg.image} \
      -c 'umask 0002; exec tini -g -- /app/run.sh'
  '';
in
{
  options.customConfig.homelab.soularr = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable soularr, the bridge that makes Lidarr + slskd an actual pipeline:
        it reads Lidarr's missing-albums list, searches Soulseek, downloads the
        best match, assembles it into a tidy album folder inside slskd's
        download directory and fires Lidarr's DownloadedAlbumsScan at it. Not
        packaged in nixpkgs, so this runs the upstream container.
      '';
    };

    image = mkOption {
      type = types.str;
      # Pinned by digest: the upstream tag is a rolling :latest, and an
      # unattended `docker run` would otherwise silently change versions
      # underneath us. Re-pin with:
      #   docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/mrusse/soularr:latest
      default = "ghcr.io/mrusse/soularr@sha256:c4f97924fabfce4e0de539d821ea7d20519b95c4815a707bacfc9d7212597f20";
      description = "Container image for soularr, pinned by digest.";
    };

    interval = mkOption {
      type = types.int;
      default = 900;
      description = ''
        Seconds between search passes, passed to the container as
        SCRIPT_INTERVAL. The image runs its own loop rather than exiting after
        one pass, so this is the schedule - there is no systemd timer. Soulseek
        searches are slow and rate-limited by peers, so this is deliberately
        longer than upstream's 300s default.
      '';
    };

    webPort = mkOption {
      type = types.port;
      default = 8265;
      description = "Port for soularr's own web UI. Fronted by nginx as soularr.lan.";
    };

    albumsPerRun = mkOption {
      type = types.int;
      default = 5;
      description = "How many missing albums to attempt per pass.";
    };

    allowedFiletypes = mkOption {
      type = types.str;
      default = "flac 24/192,flac 16/44.1,flac,mp3 320,mp3";
      description = "Comma-separated preference order of accepted formats, best first.";
    };
  };

  config = lib.mkIf cfg.enable {

    assertions = [{
      assertion = config.customConfig.homelab.slskd.enable && config.customConfig.homelab.arr.lidarr.enable;
      message = "customConfig.homelab.soularr requires both homelab.slskd and homelab.arr.lidarr to be enabled.";
    }];

    virtualisation.docker.enable = true;

    # 0770 slskd:media so the container (running as slskd:media) can write its
    # config, rotating log and failed-import denylist back out.
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0770 slskd media -"
    ];

    # Long-running, not a oneshot on a timer: the upstream image does not exit
    # after a pass, it loops internally on SCRIPT_INTERVAL and serves a web UI
    # alongside. Wrapping that in a timer just means every run hangs until the
    # unit's start timeout fires.
    systemd.services.soularr = {
      description = "soularr: fill Lidarr's missing albums from Soulseek";
      after = [ "network-online.target" "docker.service" "lidarr.service" "slskd.service" ];
      wants = [ "network-online.target" ];
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        # --rm cleans up on a graceful exit, but not after a hard kill, and the
        # fixed --name would then collide on restart.
        ExecStartPre = "-${docker} rm -f soularr";
        ExecStart = runScript;
        ExecStop = "-${docker} stop soularr";
        Restart = "on-failure";
        RestartSec = "30s";
        SyslogIdentifier = "soularr";
        Nice = "10";
      };
    };

  };
}

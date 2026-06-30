# ~/nixos-config/modules/nixos/homelab/article2pod.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.article2pod;

  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    fastapi
    uvicorn
    trafilatura
    feedgen
    pydantic
  ]);

  workerEnv = pkgs.python3.withPackages (ps: with ps; [
    trafilatura
    feedgen
  ]);

  appSrc = ./article2pod-src;

  commonEnv = {
    ARTICLE2POD_DB          = "${cfg.statePath}/db.sqlite";
    ARTICLE2POD_AUDIO       = "${cfg.storagePath}/audio";
    ARTICLE2POD_HOSTNAME    = cfg.hostname;
    ARTICLE2POD_TITLE       = cfg.podcastTitle;
    ARTICLE2POD_AUTHOR      = cfg.podcastAuthor;
    ARTICLE2POD_DESCRIPTION = cfg.podcastDescription;
    KOKORO_URL              = "http://127.0.0.1:${toString cfg.kokoroPort}";
    KOKORO_VOICE            = cfg.kokoroVoice;
    TTS_BACKEND             = cfg.ttsBackend;
    PIPER_URL               = cfg.piperUrl;
    FLARESOLVERR_URL        = cfg.flareSolverrUrl;
    PYTHONPATH              = "${appSrc}";
  };
in
{
  config = lib.mkIf cfg.enable {

    # ── Secrets ──────────────────────────────────────────────────────────────
    sops.secrets."article2pod-token" = {};   # uses defaultSopsFile = secrets/optiplex-nas.yaml

    # ── System user ──────────────────────────────────────────────────────────
    users.users.article2pod = {
      isSystemUser = true;
      group        = "article2pod";
      home         = cfg.statePath;
    };
    users.groups.article2pod = {};

    # ── Directory layout ─────────────────────────────────────────────────────
    systemd.tmpfiles.rules = [
      "d ${cfg.storagePath}       0755 article2pod article2pod - -"
      "d ${cfg.storagePath}/audio 0755 article2pod article2pod - -"
      "d ${cfg.statePath}         0700 article2pod article2pod - -"
      # UID 1000 = appuser inside the Kokoro container (must be writable for model download)
      "d ${cfg.modelsPath}        0755 1000 1000 - -"
    ];

    # ── Kokoro TTS container ─────────────────────────────────────────────────
    virtualisation.docker.enable  = true;
    virtualisation.docker.package = pkgs.docker_29;
    # No daemon-level DNS override — host-networked containers inherit the host's
    # /etc/resolv.conf (127.0.0.1 → Unbound → DoT), which Mullvad allows through.
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers.kokoro-fastapi = {
      image = cfg.kokoroImage;
      autoStart = true;
      # Host networking: container shares host's network stack, so DNS (Unbound)
      # works correctly and the port is directly accessible at 127.0.0.1:8880.
      # No ports mapping needed with --network=host.
      volumes = [ "${cfg.modelsPath}:/app/api/src/models" ];
      extraOptions = [
        "--network=host"
        "--cpus=2"
        "--memory=6g"
      ];
      environment = {
        PYTHONDONTWRITEBYTECODE = "1";
        DEVICE = "cpu";
        DOWNLOAD_MODEL = "true";
      };
    };

    # ── API service ───────────────────────────────────────────────────────────
    systemd.services.article2pod-api = {
      description = "article2pod ingest API and RSS feed server";
      after       = [ "network.target" "sops-nix.service" ];
      wants       = [ "sops-nix.service" ];
      wantedBy    = [ "multi-user.target" ];
      environment = commonEnv;
      serviceConfig = {
        Type            = "simple";
        User            = "article2pod";
        Group           = "article2pod";
        EnvironmentFile = config.sops.secrets."article2pod-token".path;
        ExecStart       = "${pythonEnv}/bin/uvicorn app:app --host 127.0.0.1 --port ${toString cfg.port}";
        WorkingDirectory = "${appSrc}";
        Restart         = "on-failure";
        RestartSec      = "5s";
        SyslogIdentifier = "article2pod";
        CPUQuota        = "25%";
        Nice            = "10";
      };
    };

    # ── Worker service (oneshot, runs on timer) ───────────────────────────────
    systemd.services.article2pod-worker = {
      description = "article2pod synthesis worker";
      after       = [
        "network.target"
        "article2pod-api.service"
        "docker-kokoro-fastapi.service"
        "sops-nix.service"
      ];
      wants       = [ "docker-kokoro-fastapi.service" ];
      path        = [ pkgs.ffmpeg ];
      environment = commonEnv // {
        PYTHONPATH = "${appSrc}";
      };
      serviceConfig = {
        Type             = "oneshot";
        User             = "article2pod";
        Group            = "article2pod";
        ExecStart        = "${workerEnv}/bin/python ${appSrc}/worker.py";
        SyslogIdentifier = "article2pod-worker";
        CPUQuota         = "100%";
        Nice             = "15";
      };
    };

    # ── Worker timer (every 2 minutes) ────────────────────────────────────────
    systemd.timers.article2pod-worker = {
      wantedBy    = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/2";
        Persistent = true;
      };
    };

    # ── nginx: proxy API + static audio ──────────────────────────────────────
    services.nginx.virtualHosts."${cfg.hostname}" = {
      locations = {
        "/" = {
          proxyPass       = "http://127.0.0.1:${toString cfg.port}";
          proxyWebsockets = true;
        };
        "/audio/" = {
          alias       = "${cfg.storagePath}/audio/";
          extraConfig = "add_header Accept-Ranges bytes;";
        };
      };
    };

  };
}

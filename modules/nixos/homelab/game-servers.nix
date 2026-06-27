# ~/nixos-config/modules/nixos/homelab/game-servers.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.gameServers;
  anyEnabled = cfg.astroneer.enable
    || cfg.minecraftSurvival.enable
    || cfg.minecraftMinigames.enable
    || cfg.minecraftBedrock.enable;
in
{
  config = lib.mkIf anyEnabled {
    virtualisation.docker.enable = true;
    virtualisation.docker.package = pkgs.docker_29;
    virtualisation.oci-containers.backend = "docker";

    sops.secrets."minecraft-survival-rcon" = lib.mkIf cfg.minecraftSurvival.enable {
      sopsFile = ../../../secrets/mini-server.yaml;
    };
    sops.secrets."minecraft-minigames-rcon" = lib.mkIf cfg.minecraftMinigames.enable {
      sopsFile = ../../../secrets/mini-server.yaml;
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root - -"
    ]
    ++ lib.optionals cfg.astroneer.enable [
      "d ${cfg.dataDir}/astroneer 0755 root root - -"
      # Pre-create Saved/ so the explicit bind mount overrides the image's VOLUME declaration
      "d ${cfg.dataDir}/astroneer/Astro 0755 root root - -"
      "d ${cfg.dataDir}/astroneer/Astro/Saved 0755 root root - -"
      "d ${cfg.dataDir}/astroneer/Astro/Saved/SaveGames 0755 root root - -"
    ]
    ++ lib.optionals cfg.minecraftSurvival.enable [
      "d ${cfg.dataDir}/minecraft-survival 0755 root root - -"
    ]
    ++ lib.optionals cfg.minecraftMinigames.enable [
      "d ${cfg.dataDir}/minecraft-minigames 0755 root root - -"
    ]
    ++ lib.optionals cfg.minecraftBedrock.enable [
      "d ${cfg.dataDir}/minecraft-bedrock 0755 root root - -"
    ];

    virtualisation.oci-containers.containers = lib.mkMerge [
      (lib.mkIf cfg.astroneer.enable {
        astroneer-server = {
          image = "whalybird/astroneer-server";
          autoStart = false;
          ports = [
            "${toString cfg.astroneer.port}:${toString cfg.astroneer.port}/udp"
            "${toString cfg.astroneer.queryPort}:${toString cfg.astroneer.queryPort}/udp"
          ];
          volumes = [
            "${cfg.dataDir}/astroneer:/astrotux/AstroneerServer"
            # Explicit bind mount overrides the image's VOLUME declaration so saves
            # and config go to our host directory instead of an anonymous Docker volume.
            "${cfg.dataDir}/astroneer/Astro/Saved:/astrotux/AstroneerServer/Astro/Saved"
          ];
        };
      })

      (lib.mkIf cfg.minecraftSurvival.enable {
        minecraft-survival = {
          image = "itzg/minecraft-server";
          autoStart = false;
          ports = [ "${toString cfg.minecraftSurvival.port}:25565/tcp" ];
          volumes = [ "${cfg.dataDir}/minecraft-survival:/data" ];
          environment = {
            EULA = "TRUE";
            TYPE = "PAPER";
            ENABLE_RCON = "true";
            RCON_PORT = "25575";
          };
          extraOptions = [ "--env-file=${config.sops.secrets."minecraft-survival-rcon".path}" ];
        };
      })

      (lib.mkIf cfg.minecraftMinigames.enable {
        minecraft-minigames = {
          image = "itzg/minecraft-server";
          autoStart = false;
          ports = [ "${toString cfg.minecraftMinigames.port}:25565/tcp" ];
          volumes = [ "${cfg.dataDir}/minecraft-minigames:/data" ];
          environment = {
            EULA = "TRUE";
            TYPE = "PAPER";
            ENABLE_RCON = "true";
            RCON_PORT = "25575";
          };
          extraOptions = [ "--env-file=${config.sops.secrets."minecraft-minigames-rcon".path}" ];
        };
      })

      (lib.mkIf cfg.minecraftBedrock.enable {
        minecraft-bedrock = {
          image = "itzg/minecraft-bedrock-server";
          autoStart = false;
          ports = [
            "${toString cfg.minecraftBedrock.port}:${toString cfg.minecraftBedrock.port}/udp"
            "${toString cfg.minecraftBedrock.portV6}:${toString cfg.minecraftBedrock.portV6}/udp"
          ];
          volumes = [ "${cfg.dataDir}/minecraft-bedrock:/data" ];
          environment.EULA = "TRUE";
        };
      })
    ];
  };
}

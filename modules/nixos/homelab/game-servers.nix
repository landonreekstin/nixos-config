# ~/nixos-config/modules/nixos/homelab/game-servers.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.customConfig.homelab.gameServers;
  anyEnabled = cfg.astroneer.enable
    || cfg.minecraftSurvival.enable
    || cfg.minecraftMinigames.enable
    || cfg.minecraftBedrock.enable
    || cfg.minecraftBedrockLandon.enable
    || cfg.minecraftBedrockVenator.enable;
in
{
  options.customConfig.homelab.gameServers = with lib; {
    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/game-servers";
      description = "Parent directory for all game server OCI container volume mounts.";
    };
    astroneer = {
      enable = mkEnableOption "Astroneer dedicated server (OCI container, autoStart = false)";
      port = mkOption {
        type = types.port;
        default = 7777;
        description = "Astroneer game port (UDP).";
      };
      queryPort = mkOption {
        type = types.port;
        default = 27777;
        description = "Astroneer server query port (UDP).";
      };
    };
    minecraftSurvival = {
      enable = mkEnableOption "Minecraft Survival server (Paper, OCI container, autoStart = false)";
      port = mkOption {
        type = types.port;
        default = 25565;
        description = "Minecraft Java edition TCP port.";
      };
    };
    minecraftMinigames = {
      enable = mkEnableOption "Minecraft Minigames server (Paper, OCI container, autoStart = false)";
      port = mkOption {
        type = types.port;
        default = 25566;
        description = "Minecraft Java edition TCP port.";
      };
    };
    minecraftBedrock = {
      enable = mkEnableOption "Minecraft Bedrock server (OCI container, autoStart = false)";
      port = mkOption {
        type = types.port;
        default = 19132;
        description = "Minecraft Bedrock IPv4 UDP port.";
      };
      portV6 = mkOption {
        type = types.port;
        default = 19133;
        description = "Minecraft Bedrock IPv6 UDP port.";
      };
    };
    minecraftBedrockLandon = {
      enable = mkEnableOption "Minecraft Bedrock server hosting the 'landon' world (OCI container, autoStart = false)";
      port = mkOption {
        type = types.port;
        default = 19134;
        description = "Minecraft Bedrock 'landon' IPv4 UDP port.";
      };
      portV6 = mkOption {
        type = types.port;
        default = 19135;
        description = "Minecraft Bedrock 'landon' IPv6 UDP port.";
      };
    };
    minecraftBedrockVenator = {
      enable = mkEnableOption "Minecraft Bedrock server hosting the 'venator' world (OCI container, autoStart = false)";
      port = mkOption {
        type = types.port;
        default = 19136;
        description = "Minecraft Bedrock 'venator' IPv4 UDP port.";
      };
      portV6 = mkOption {
        type = types.port;
        default = 19137;
        description = "Minecraft Bedrock 'venator' IPv6 UDP port.";
      };
    };
  };

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
    ]
    ++ lib.optionals cfg.minecraftBedrockLandon.enable [
      "d ${cfg.dataDir}/minecraft-bedrock-landon 0755 root root - -"
    ]
    ++ lib.optionals cfg.minecraftBedrockVenator.enable [
      "d ${cfg.dataDir}/minecraft-bedrock-venator 0755 root root - -"
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

      (lib.mkIf cfg.minecraftBedrockLandon.enable {
        minecraft-bedrock-landon = {
          image = "itzg/minecraft-bedrock-server";
          autoStart = false;
          ports = [
            "${toString cfg.minecraftBedrockLandon.port}:${toString cfg.minecraftBedrockLandon.port}/udp"
            "${toString cfg.minecraftBedrockLandon.portV6}:${toString cfg.minecraftBedrockLandon.portV6}/udp"
          ];
          volumes = [ "${cfg.dataDir}/minecraft-bedrock-landon:/data" ];
          environment = {
            EULA = "TRUE";
            LEVEL_NAME = "landon";
            # BDS defaults to 19132/19133 inside the container; the itzg image writes
            # SERVER_PORT/SERVER_PORT_V6 into server.properties so BDS actually listens
            # on the custom ports we're bind-mapping.
            SERVER_PORT = toString cfg.minecraftBedrockLandon.port;
            SERVER_PORT_V6 = toString cfg.minecraftBedrockLandon.portV6;
          };
        };
      })

      (lib.mkIf cfg.minecraftBedrockVenator.enable {
        minecraft-bedrock-venator = {
          image = "itzg/minecraft-bedrock-server";
          autoStart = false;
          ports = [
            "${toString cfg.minecraftBedrockVenator.port}:${toString cfg.minecraftBedrockVenator.port}/udp"
            "${toString cfg.minecraftBedrockVenator.portV6}:${toString cfg.minecraftBedrockVenator.portV6}/udp"
          ];
          volumes = [ "${cfg.dataDir}/minecraft-bedrock-venator:/data" ];
          environment = {
            EULA = "TRUE";
            LEVEL_NAME = "venator";
            SERVER_PORT = toString cfg.minecraftBedrockVenator.port;
            SERVER_PORT_V6 = toString cfg.minecraftBedrockVenator.portV6;
          };
        };
      })
    ];
  };
}

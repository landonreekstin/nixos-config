# ~/nixos-config/modules/nixos/programs/comfyui.nix
{ config, pkgs, lib, ... }:

# ComfyUI (node-based image/video generation UI) in a GPU container.
#
# ComfyUI is not in nixpkgs and its Python stack and custom nodes change weekly, so it runs
# from the yanwk/comfyui-boot image (podman + NVIDIA CDI) instead of being packaged here.
# Everything it keeps lives under dataDir, outside the store and outside git:
#
#   dataDir/root       the container's /root: ComfyUI itself, custom nodes, pip installs
#   dataDir/models     model weights (checkpoints, diffusion_models, vae, loras, ...)
#   dataDir/input, output, workflows
#
# Models are never declared in Nix: download them into dataDir/models by hand or with
# ComfyUI-Manager in the web UI. See docs/comfyui.md.
#
# Access: the container shares the host network and ComfyUI listens on every address, so
# the host firewall is the gate. The port is NOT opened generally; it is accepted only on
# `interfaces` and only from `allowedSources`. On gaming-pc that is wg-nas from lando's
# full VPN peers, which optiplex-fw routes to 10.10.0.11 with their own addresses.
let
  cfg = config.customConfig.programs.comfyui;
  port = toString cfg.port;
in
{
  options.customConfig.programs.comfyui = with lib; {
    enable = mkEnableOption "ComfyUI in a GPU container";

    image = mkOption {
      type = types.str;
      # Dated tag + digest, so a restart never silently changes versions. To bump, pick a
      # newer cu130-slim-<date> tag on Docker Hub and take its digest from the tags API.
      default = "docker.io/yanwk/comfyui-boot:cu130-slim-20261026@sha256:31f8937601a23e680f3c779f73a42dd98e5b69f10314c7bec1a43c5a62bd35b7";
      description = "ComfyUI container image (cu130 needs NVIDIA driver 580 or newer).";
    };

    port = mkOption {
      type = types.port;
      default = 8188;
      description = "Port the ComfyUI web UI listens on.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/comfyui";
      description = "Where ComfyUI, its custom nodes, models and outputs are kept.";
    };

    interfaces = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "wg-nas" ];
      description = "Interfaces the web UI is reachable on (besides localhost).";
    };

    allowedSources = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "10.10.0.2/32" ];
      description = "IPv4 addresses/CIDRs allowed to reach the web UI on `interfaces`.";
    };

    extraArgs = mkOption {
      type = types.str;
      # Not bare --fast: that also turns on fp8 matrix multiplication, which makes some
      # fp8 checkpoints (merged all-in-one Qwen edit models) output pure noise.
      default = "--fast fp16_accumulation";
      description = "Extra ComfyUI command-line arguments.";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.nvidia-container-toolkit.enable = true;
    virtualisation.podman.enable = true;

    # models is group-writable so lando can download weights without sudo.
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
      "d ${cfg.dataDir}/root 0755 root root -"
      "d ${cfg.dataDir}/models 2775 root users -"
      "d ${cfg.dataDir}/hf-hub 0755 root root -"
      "d ${cfg.dataDir}/torch-hub 0755 root root -"
      "d ${cfg.dataDir}/input 2775 root users -"
      "d ${cfg.dataDir}/output 2775 root users -"
      "d ${cfg.dataDir}/workflows 2775 root users -"
    ];

    virtualisation.oci-containers.containers.comfyui = {
      image = cfg.image;
      autoStart = true;
      volumes = [
        "${cfg.dataDir}/root:/root"
        "${cfg.dataDir}/models:/root/ComfyUI/models"
        "${cfg.dataDir}/hf-hub:/root/.cache/huggingface/hub"
        "${cfg.dataDir}/torch-hub:/root/.cache/torch/hub"
        "${cfg.dataDir}/input:/root/ComfyUI/input"
        "${cfg.dataDir}/output:/root/ComfyUI/output"
        "${cfg.dataDir}/workflows:/root/ComfyUI/user/default/workflows"
      ];
      # The image runs `main.py --listen --port 8188 $CLI_ARGS`; a later --port wins.
      environment.CLI_ARGS = "--port ${port} ${cfg.extraArgs}";
      extraOptions = [
        "--network=host"
        "--device=nvidia.com/gpu=all"
        "--security-opt=label=disable"
      ];
    };

    # The first start pulls a several-GB image; the default start timeout is too short.
    systemd.services.podman-comfyui.serviceConfig.TimeoutStartSec = lib.mkForce "30min";

    networking.firewall.extraCommands = lib.concatMapStrings (iface:
      lib.concatMapStrings (src: ''
        iptables -A nixos-fw -i ${iface} -s ${src} -p tcp --dport ${port} -j nixos-fw-accept
      '') cfg.allowedSources
    ) cfg.interfaces;
  };
}

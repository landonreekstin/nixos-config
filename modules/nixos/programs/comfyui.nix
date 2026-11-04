# ~/nixos-config/modules/nixos/programs/comfyui.nix
{ config, pkgs, lib, utils, ... }:

# ComfyUI (node-based image/video generation UI) in a GPU container.
#
# ComfyUI is not in nixpkgs and its Python stack and custom nodes change weekly, so it runs
# from the yanwk/comfyui-boot image (podman + NVIDIA CDI) instead of being packaged here.
# Everything it keeps lives outside the store and outside git:
#
#   dataDir/root       the container's /root: ComfyUI itself, custom nodes, pip installs
#   dataDir/models     model weights (checkpoints, diffusion_models, vae, loras, ...)
#   dataDir/hf-hub, torch-hub   download caches
#
# Personal data (uploads, generated files with their prompts embedded, saved workflows,
# settings and ComfyUI's own log) goes in `private.dir` when that is set, otherwise in
# dataDir/{input,output,workflows}. ComfyUI's preview/temp files are kept in RAM only.
#
# With `private.dir` set, ComfyUI only runs while `private.mountPoint` is mounted: it is not
# started at boot, refuses to start without the mount, and is stopped when it goes away
# (BindsTo the mount unit systemd creates for any mount). So nothing personal ever lands on
# the local disk when the private share isn't there.
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
  priv = cfg.private;
  usePrivate = priv.dir != null;
  mountUnit = "${utils.escapeSystemdPath priv.mountPoint}.mount";

  # comfy-start / comfy-stop: one command each way, private share included.
  # private-share runs without DISPLAY/WAYLAND_DISPLAY so it doesn't open a file manager.
  mountShare = lib.optionalString usePrivate ''
    env -u DISPLAY -u WAYLAND_DISPLAY private-share
  '';
  unmountShare = lib.optionalString usePrivate ''
    env -u DISPLAY -u WAYLAND_DISPLAY private-share -u
  '';

  comfyStart = pkgs.writeShellApplication {
    name = "comfy-start";
    runtimeInputs = [ pkgs.curl pkgs.iproute2 pkgs.gawk ];
    text = ''
      SUDO=/run/wrappers/bin/sudo
      ${mountShare}
      echo "Starting ComfyUI..."
      "$SUDO" systemctl start podman-comfyui
      for _ in $(seq 1 100); do
        curl -sf -o /dev/null "http://127.0.0.1:${port}/" && break
        sleep 3
      done
      if ! curl -sf -o /dev/null "http://127.0.0.1:${port}/"; then
        echo "ComfyUI didn't come up. Logs:  journalctl -u podman-comfyui -e" >&2
        exit 1
      fi
      echo "ComfyUI is ready:"
      echo "  here:        http://localhost:${port}"
      ifaces=(${lib.escapeShellArgs cfg.interfaces})
      for iface in "''${ifaces[@]}"; do
        addr=$(ip -4 -o addr show "$iface" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1)
        if [ -n "$addr" ]; then echo "  over VPN:    http://$addr:${port}"; fi
      done
      echo "Stop it (and free the GPU) with:  comfy-stop"
    '';
  };

  comfyStop = pkgs.writeShellApplication {
    name = "comfy-stop";
    text = ''
      SUDO=/run/wrappers/bin/sudo
      echo "Stopping ComfyUI..."
      "$SUDO" systemctl stop podman-comfyui
      ${unmountShare}
      if command -v nvidia-smi >/dev/null; then
        echo "GPU memory in use now: $(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader)"
      fi
      echo "GPU is free for gaming."
    '';
  };

  personalVolumes =
    if usePrivate then [
      "${priv.dir}/input:/root/ComfyUI/input"
      "${priv.dir}/output:/root/ComfyUI/output"
      "${priv.dir}/user:/root/ComfyUI/user"
    ] else [
      "${cfg.dataDir}/input:/root/ComfyUI/input"
      "${cfg.dataDir}/output:/root/ComfyUI/output"
      "${cfg.dataDir}/workflows:/root/ComfyUI/user/default/workflows"
    ];
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
      description = "Where ComfyUI, its custom nodes, models and caches are kept.";
    };

    private = {
      dir = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "/mnt/nas-private/generated";
        description = ''
          Where uploads, outputs, saved workflows, settings and logs go. Must be under
          `private.mountPoint`. When set, ComfyUI only runs while that is mounted.
        '';
      };
      mountPoint = mkOption {
        type = types.str;
        default = "/mnt/nas-private";
        description = "The (manually mounted) filesystem `private.dir` lives on.";
      };
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
    assertions = [{
      assertion = !usePrivate || lib.hasPrefix "${priv.mountPoint}/" priv.dir;
      message = "customConfig.programs.comfyui.private.dir must be under private.mountPoint.";
    }];

    hardware.nvidia-container-toolkit.enable = true;
    virtualisation.podman.enable = true;

    environment.systemPackages = [ comfyStart comfyStop ];

    # models is group-writable so lando can download weights without sudo.
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
      "d ${cfg.dataDir}/root 0755 root root -"
      "d ${cfg.dataDir}/models 2775 root users -"
      "d ${cfg.dataDir}/hf-hub 0755 root root -"
      "d ${cfg.dataDir}/torch-hub 0755 root root -"
    ] ++ lib.optionals (!usePrivate) [
      "d ${cfg.dataDir}/input 2775 root users -"
      "d ${cfg.dataDir}/output 2775 root users -"
      "d ${cfg.dataDir}/workflows 2775 root users -"
    ];

    virtualisation.oci-containers.containers.comfyui = {
      image = cfg.image;
      # Behind a manual mount there is nothing to start at boot.
      autoStart = !usePrivate;
      volumes = [
        "${cfg.dataDir}/root:/root"
        "${cfg.dataDir}/models:/root/ComfyUI/models"
        "${cfg.dataDir}/hf-hub:/root/.cache/huggingface/hub"
        "${cfg.dataDir}/torch-hub:/root/.cache/torch/hub"
      ] ++ personalVolumes;
      # The image runs `main.py --listen --port 8188 $CLI_ARGS`; a later --port wins.
      environment.CLI_ARGS = "--port ${port} ${cfg.extraArgs}";
      extraOptions = [
        "--network=host"
        "--device=nvidia.com/gpu=all"
        "--security-opt=label=disable"
        # previews and temp images: RAM only
        "--tmpfs=/root/ComfyUI/temp"
      ];
    };

    systemd.services.podman-comfyui = lib.mkMerge [
      # The first start pulls a several-GB image; the default start timeout is too short.
      { serviceConfig.TimeoutStartSec = lib.mkForce "30min"; }

      (lib.mkIf usePrivate {
        bindsTo = [ mountUnit ];
        after = [ mountUnit ];
        # Checked before anything is created, so a missing mount can never leave
        # directories (or data) on the root filesystem.
        preStart = lib.mkBefore ''
          if ! ${pkgs.util-linux}/bin/mountpoint -q ${lib.escapeShellArg priv.mountPoint}; then
            echo "comfyui: ${priv.mountPoint} is not mounted; run private-share first" >&2
            exit 1
          fi
          mkdir -p ${lib.escapeShellArg priv.dir}/{input,output,user}
        '';
      })
    ];

    networking.firewall.extraCommands = lib.concatMapStrings (iface:
      lib.concatMapStrings (src: ''
        iptables -A nixos-fw -i ${iface} -s ${src} -p tcp --dport ${port} -j nixos-fw-accept
      '') cfg.allowedSources
    ) cfg.interfaces;
  };
}

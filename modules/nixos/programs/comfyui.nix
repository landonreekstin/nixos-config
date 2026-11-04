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

  # Offline isolation. ComfyUI runs on an `internal` podman network: a bridge with no
  # route out, no DNS and no NAT. A host-side proxy (comfyui-proxy) carries connections
  # *in* to it, and an nftables table of our own drops anything *new* coming from the
  # bridge, so the container can't use gaming-pc itself (or host forwarding) as a way out
  # either. Separate table = a drop here can't be overridden by an accept elsewhere.
  podmanBin = "${config.virtualisation.podman.package}/bin/podman";
  netName = "comfyui-offline";
  bridge = "comfynet0";
  subnet = "10.90.88.0/29";
  containerIp = "10.90.88.2";
  nft = "${pkgs.nftables}/bin/nft";
  nftTable = "comfyui_isolation";
  maintPort = toString cfg.maintenance.port;

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

  # comfy-batch: one edit prompt over every image under a directory, results saved beside
  # their sources. Model-agnostic: it runs a saved API-format workflow from ComfyUI.
  comfyBatch = pkgs.writers.writePython3Bin "comfy-batch" {
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./comfy-batch.py);

  # comfy-maintenance: the only instance with internet, for installing custom nodes and
  # models through ComfyUI-Manager. None of the personal data is mounted in it.
  comfyMaintenance = pkgs.writeShellApplication {
    name = "comfy-maintenance";
    runtimeInputs = [ pkgs.curl pkgs.iproute2 pkgs.gawk ];
    text = ''
      SUDO=/run/wrappers/bin/sudo
      echo "Starting ComfyUI MAINTENANCE mode (internet on, no personal data)..."
      echo "(this stops the normal offline ComfyUI if it is running)"
      "$SUDO" systemctl start podman-comfyui-maintenance
      for _ in $(seq 1 100); do
        curl -sf -o /dev/null "http://127.0.0.1:${maintPort}/" && break
        sleep 3
      done
      if ! curl -sf -o /dev/null "http://127.0.0.1:${maintPort}/"; then
        echo "It didn't come up. Logs:  journalctl -u podman-comfyui-maintenance -e" >&2
        exit 1
      fi
      echo "Maintenance ComfyUI is ready (use the Manager here; don't generate here):"
      echo "  here:        http://localhost:${maintPort}"
      ifaces=(${lib.escapeShellArgs cfg.interfaces})
      for iface in "''${ifaces[@]}"; do
        addr=$(ip -4 -o addr show "$iface" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1)
        if [ -n "$addr" ]; then echo "  over VPN:    http://$addr:${maintPort}"; fi
      done
      echo "When done:  comfy-stop   (then comfy-start for the normal offline one)"
    '';
  };

  comfyStop = pkgs.writeShellApplication {
    name = "comfy-stop";
    text = ''
      SUDO=/run/wrappers/bin/sudo
      echo "Stopping ComfyUI..."
      "$SUDO" systemctl stop podman-comfyui podman-comfyui-maintenance
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

    maintenance.port = mkOption {
      type = types.port;
      default = 8189;
      description = ''
        Port of the maintenance instance (`comfy-maintenance`): the only one with internet,
        for installing nodes/models, with no personal data mounted.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = !usePrivate || lib.hasPrefix "${priv.mountPoint}/" priv.dir;
      message = "customConfig.programs.comfyui.private.dir must be under private.mountPoint.";
    }];

    hardware.nvidia-container-toolkit.enable = true;
    virtualisation.podman.enable = true;

    environment.systemPackages = [ comfyStart comfyStop comfyBatch comfyMaintenance ];

    # models is group-writable so lando can download weights without sudo.
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
      "d ${cfg.dataDir}/root 0755 root root -"
      "d ${cfg.dataDir}/models 2775 root users -"
      "d ${cfg.dataDir}/hf-hub 0755 root root -"
      "d ${cfg.dataDir}/torch-hub 0755 root root -"
      "d ${cfg.dataDir}/maintenance-user 0755 root root -"
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
      # The image runs `main.py --listen --port 8188 $CLI_ARGS`. Inside its own network
      # namespace it always listens on 8188; comfyui-proxy publishes that as `port`.
      # --offline: a Content-Security-Policy that stops the web UI in the browser from
      # contacting the internet, and no paid cloud ("partner") nodes.
      environment = {
        CLI_ARGS = "--offline ${cfg.extraArgs}";
        HF_HUB_OFFLINE = "1";
        TRANSFORMERS_OFFLINE = "1";
        DO_NOT_TRACK = "1";
      };
      extraOptions = [
        "--network=${netName}"
        "--ip=${containerIp}"
        "--dns=none"
        # no hand-crafted packets (they could be aimed past the missing route)
        "--cap-drop=NET_RAW"
        "--device=nvidia.com/gpu=all"
        "--security-opt=label=disable"
        # previews and temp images: RAM only
        "--tmpfs=/root/ComfyUI/temp"
      ];
    };

    # Same install, with internet and host networking, but none of the personal data:
    # input/output are RAM-only and user/ is a local maintenance-only folder.
    virtualisation.oci-containers.containers.comfyui-maintenance = {
      image = cfg.image;
      autoStart = false;
      volumes = [
        "${cfg.dataDir}/root:/root"
        "${cfg.dataDir}/models:/root/ComfyUI/models"
        "${cfg.dataDir}/hf-hub:/root/.cache/huggingface/hub"
        "${cfg.dataDir}/torch-hub:/root/.cache/torch/hub"
        "${cfg.dataDir}/maintenance-user:/root/ComfyUI/user"
      ];
      environment.CLI_ARGS = "--port ${maintPort} ${cfg.extraArgs}";
      extraOptions = [
        "--network=host"
        "--device=nvidia.com/gpu=all"
        "--security-opt=label=disable"
        "--tmpfs=/root/ComfyUI/temp"
        "--tmpfs=/root/ComfyUI/input"
        "--tmpfs=/root/ComfyUI/output"
      ];
    };

    # Both share dataDir/root, so only one runs at a time.
    systemd.services.podman-comfyui-maintenance = {
      conflicts = [ "podman-comfyui.service" ];
      serviceConfig.TimeoutStartSec = lib.mkForce "30min";
    };

    # Carries connections in to the isolated container. The firewall rules below gate
    # who may reach `port`, exactly as when ComfyUI itself listened on the host.
    systemd.services.comfyui-proxy = {
      description = "Forward port ${port} to the offline ComfyUI container";
      bindsTo = [ "podman-comfyui.service" ];
      after = [ "podman-comfyui.service" ];
      wantedBy = [ "podman-comfyui.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:${port},fork,reuseaddr TCP:${containerIp}:8188";
        DynamicUser = true;
        Restart = "on-failure";
        SuccessExitStatus = [ 143 ];  # socat on SIGTERM
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
      };
    };

    systemd.services.podman-comfyui = lib.mkMerge [
      {
        # The first start pulls a several-GB image; the default start timeout is too short.
        serviceConfig.TimeoutStartSec = lib.mkForce "30min";
        conflicts = [ "podman-comfyui-maintenance.service" ];
        # Recreated every start so it always matches what is declared here.
        preStart = ''
          ${podmanBin} network rm -f ${netName} >/dev/null 2>&1 || true
          ${podmanBin} network create --internal --subnet ${subnet} \
            --interface-name ${bridge} ${netName} >/dev/null
        '';
      }

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
        iptables -A nixos-fw -i ${iface} -s ${src} -p tcp --dport ${maintPort} -j nixos-fw-accept
      '') cfg.allowedSources
    ) cfg.interfaces + ''
      # Nothing new may come from the offline ComfyUI's bridge, to this host or through
      # it (IPv4 and IPv6). Replies to connections the host opened (the proxy) still flow.
      ${nft} delete table inet ${nftTable} 2>/dev/null || true
      ${nft} -f - <<'NFT'
      table inet ${nftTable} {
        chain input {
          type filter hook input priority -10; policy accept;
          iifname "${bridge}" ct state established,related accept
          iifname "${bridge}" drop
        }
        chain forward {
          type filter hook forward priority -10; policy accept;
          iifname "${bridge}" drop
          oifname "${bridge}" drop
        }
      }
      NFT
    '';
    networking.firewall.extraStopCommands = ''
      ${nft} delete table inet ${nftTable} 2>/dev/null || true
    '';
  };
}

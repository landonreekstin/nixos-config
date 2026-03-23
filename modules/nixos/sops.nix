# ~/nixos-config/modules/nixos/sops.nix
{ config, pkgs, lib, inputs, ... }:
let
  cfg = config.customConfig;
in
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops = {
    defaultSopsFile = ../../secrets/${config.networking.hostName}.yaml;
    defaultSopsFormat = "yaml";
    # Derive age identity from the host's SSH ed25519 host key at runtime
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = lib.mkMerge [
      # User password hash - enabled per-host via customConfig.user.sopsPasswordEnable
      (lib.mkIf cfg.user.sopsPasswordEnable {
        user-password-hash = {
          neededForUsers = true;  # Available at boot before user login
        };
      })
      # Media-linker API keys - enabled per-host via customConfig.homelab.mediaLinker.sopsEnvEnable
      (lib.mkIf cfg.homelab.mediaLinker.sopsEnvEnable {
        media-linker-env = {
          owner = "root";
          mode = "0400";
        };
      })
    ];
  };

  # Auto-configure media-linker envFile when using sops
  customConfig.homelab.mediaLinker.envFile = lib.mkIf cfg.homelab.mediaLinker.sopsEnvEnable
    config.sops.secrets.media-linker-env.path;

  # Tools for managing sops secrets and age keys
  environment.systemPackages = with pkgs; [
    sops
    age
    ssh-to-age
  ];
}

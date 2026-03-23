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

    # User password hash - enabled per-host via customConfig.user.sopsPasswordEnable
    secrets = lib.mkIf cfg.user.sopsPasswordEnable {
      user-password-hash = {
        neededForUsers = true;  # Available at boot before user login
      };
    };
  };

  # Tools for managing sops secrets and age keys
  environment.systemPackages = with pkgs; [
    sops
    age
    ssh-to-age
  ];
}

# ~/nixos-config/modules/nixos/sops.nix
{ config, pkgs, inputs, ... }:
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops = {
    defaultSopsFile = ../../secrets/${config.networking.hostName}.yaml;
    defaultSopsFormat = "yaml";
    # Derive age identity from the host's SSH ed25519 host key at runtime
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  # Tools for managing sops secrets and age keys
  environment.systemPackages = with pkgs; [
    sops
    age
    ssh-to-age
  ];
}

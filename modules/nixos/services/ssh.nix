# ~/nixos-config/modules/nixos/services/ssh.nix
{ config, pkgs, lib, ... }:

{
  # Enable OpenSSH daemon
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}

# ~/nixos-config/modules/nixos/services/ssh.nix
{ config, pkgs, lib, ... }:
lib.mkIf config.customConfig.services.ssh.enable {
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}

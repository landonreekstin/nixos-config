# ~/nixos-config/modules/nixos/services/ssh.nix
{ config, pkgs, lib, inputs, ... }: # inputs might not be needed here anymore unless ssh itself uses a flake input

let
  sshIsEnabled = config.customConfig.services.ssh.enable;
in
{
  # This module no longer imports vscode-server.
  # It only defines its own config block.
  config = lib.mkIf sshIsEnabled {
    services.openssh = {
      enable = true; # Enable the actual SSH service
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        # Add any other SSH specific settings here
      };
    };
  };
}
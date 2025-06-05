# ~/nixos-config/modules/nixos/services/vscode-server.nix
{ config, pkgs, lib, inputs, ... }: # 'inputs' is passed via specialArgs

let
  # Shortcut to the specific customConfig option for this module
  vscodeCfg = config.customConfig.services.vscodeServer;
in
{
  # Conditionally configure the VSCode server service
  config = lib.mkIf vscodeCfg.enable {
    services.vscode-server = {
      enable = true; # This is the actual NixOS option to enable the service
      # You can add other configurations for services.vscode-server here if needed
      # For example, if you want to tie it to specific users:
      # users = [ config.customConfig.user.name ]; # Automatically enable for the main user
      # Or control other options provided by the nixos-vscode-server module.
    };
  };
}
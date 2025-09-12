# ~/nixos-config/modules/nixos/services/default.nix
# This file serves as the import point for service modules.
{ ... }: # No specific args needed here usually, they are passed to the individual modules
{
  imports = [
    ./ssh.nix
    ./vscode-server.nix
    ./geoclue2.nix
    ./nixai.nix
    ./wireguard-server.nix
  ];
}
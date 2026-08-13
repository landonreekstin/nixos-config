# ~/nixos-config/hosts/blaney-pc/networking.nix
{ config, pkgs, lib, ... }:

{
  customConfig.services = {
    ssh.enable = false;
    vscodeServer.enable = false;

    # Weekly automated git sync + rebuild, then power off. Desktop-safe settings:
    autoUpdate = {
      enable = true;
      shutdownAfterRebuild = true;   # power off after a successful update
      skipIfActiveSession = true;    # never rebuild/power-off while it's in use
      lowPriority = true;            # nice/ionice the rebuild
      persistent = false;            # don't fire a surprise rebuild+shutdown on next boot
    };
  };
}

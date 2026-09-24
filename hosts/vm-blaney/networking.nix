# ~/nixos-config/hosts/vm-blaney/networking.nix
{ config, pkgs, lib, ... }:

{
  customConfig.services = {
    ssh.enable = false;
    vscodeServer.enable = false;

    # Mirror blaney-pc exactly so the shutdown guard has a real nixos-auto-update.timer to
    # read and the dialog wording matches. Harmless in a throwaway VM: persistent = false
    # means a VM that isn't running at 03:00 Monday never catches up, and a VM powering
    # itself off costs nothing.
    autoUpdate = {
      enable = true;
      shutdownAfterRebuild = true;
      skipIfActiveSession = true;
      lowPriority = true;
      persistent = false;
    };
  };
}

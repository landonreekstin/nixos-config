# ~/nixos-config/hosts/blaney-pc/networking.nix
{ config, pkgs, lib, ... }:

{
  customConfig.services = {
    ssh.enable = false;
    vscodeServer.enable = false;

    # Weekly automated git sync + rebuild, then power off. Desktop-safe settings:
    #
    # TEMPORARILY DISABLED for the nixos-26.05 upgrade. 26.05 makes systemd
    # stage-1 initrd the default and switches D-Bus to dbus-broker, both of which
    # only take effect on the next boot. With shutdownAfterRebuild = true this
    # host switches and immediately powers off, so its next power-on would be its
    # first-ever 26.05 boot — unattended, and insideabush cannot recover a failed
    # boot. Re-enable only after blaney-pc has been rebooted onto 26.05 in person.
    # TODO: set back to true once blaney-pc is verified on 26.05.
    autoUpdate = {
      enable = false;
      shutdownAfterRebuild = true;   # power off after a successful update
      skipIfActiveSession = true;    # never rebuild/power-off while it's in use
      lowPriority = true;            # nice/ionice the rebuild
      persistent = false;            # don't fire a surprise rebuild+shutdown on next boot
    };
  };
}

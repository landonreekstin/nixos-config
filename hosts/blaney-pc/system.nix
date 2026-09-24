# ~/nixos-config/hosts/blaney-pc/system.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    user = {
      name = "insideabush";
      email = "cblaney00@gmail.com";
      updateCmdPermission = false;
    };

    system = {
      hostName = "blaney-pc"; # Actual hostname for this machine
      stateVersion = "25.05"; # DO NOT CHANGE
      timeZone = "America/New_York"; # As per your old core.nix
      locale = "en_US.UTF-8"; # As per your old core.nix
    };

    bootloader.plymouth = {
      enable = true;
      theme = "hexa_retro";
    };

  };

  # The case's power button must not power the machine off behind our back: this host runs a
  # weekly unattended update that needs it left on, so the button is bound to the Win7 power
  # flyout instead (XF86PowerOff in modules/home-manager/themes/windows7-xfce/keybindings.nix),
  # which runs the shutdown guard. Without this, logind would still hard-poweroff on the key.
  services.logind.settings.Login.HandlePowerKey = "ignore";
}

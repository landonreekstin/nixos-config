# ~/nixos-config/hosts/vm-blaney/system.nix
{ config, pkgs, lib, ... }:

{
  customConfig = {

    user = {
      name = "insideabush";
      email = "cblaney00@gmail.com";
      updateCmdPermission = false;
    };

    system = {
      hostName = "vm-blaney";
      stateVersion = "25.05"; # match blaney-pc
      timeZone = "America/New_York";
      locale = "en_US.UTF-8";
    };

  };

  # Throwaway login password (ly has no autologin here; sign in as insideabush / "vm").
  users.users.${config.customConfig.user.name}.initialPassword = "vm";

  # The gaming stack (Steam/Heroic/Lutris) doesn't fit in vm-common's 20G throwaway disk.
  # Bump it for this VM only (qcow2 is thin-provisioned, so it costs host disk only as filled).
  virtualisation.vmVariant.virtualisation.diskSize = lib.mkForce 61440; # 60 GiB
}

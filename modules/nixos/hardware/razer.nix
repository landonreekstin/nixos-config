# ~/nixos-config/modules/nixos/hardware/peripherals.nix
{ config, pkgs, lib, ... }:

{
    environment.systemPackages = with pkgs; [
        openrazer-daemon
        polychromatic
        linuxKernel.packages.linux_zen.openrazer
    ];

    # === Enable Razer Device Support ===
    hardware.openrazer = {
        enable = true; # Enable OpenRazer for Razer device support
        users = [ config.customConfig.user.name ]; # Ensure OpenRazer runs for the user
    };

    users.users.${config.customConfig.user.name}.extraGroups = [
      "openrazer"
    ];

}
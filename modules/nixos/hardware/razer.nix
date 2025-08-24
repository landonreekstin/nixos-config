# ~/nixos-config/modules/nixos/hardware/razer.nix
{ config, pkgs, lib, ... }:

{
    # These packages provide the tools and GUI.
    environment.systemPackages = with pkgs; [
        #polychromatic
        openrazer-daemon
        razergenie

    ];

    # This option is the main switch. It automatically handles the
    # correct kernel module, so you don't need to add it above.
    hardware.openrazer.enable = true;

    # This option correctly adds your user to the 'openrazer' group
    # and makes the daemon aware of your user session.
    hardware.openrazer.users = [ config.customConfig.user.name ];

    # This is the crucial missing piece. Your user MUST be in the
    # 'plugdev' group to get permission to control the hardware.
    users.users.${config.customConfig.user.name}.extraGroups = [ "plugdev" "openrazer" ];
}
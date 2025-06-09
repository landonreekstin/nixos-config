# ~/nixos-config/modules/nixos/services/gammastep.nix
{ config, pkgs, lib, ... }:
{
    services.geoclue2 = {
        enable = true;
        submitData = true;
        appConfig.gammastep.isAllowed = true;
        appConfig.gammastep.isSystem = true;
    };
}
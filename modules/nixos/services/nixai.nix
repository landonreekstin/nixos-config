# ~/nixos-config/modules/nixos/services/nixai.nix
{ config, pkgs, lib, inputs, ... }:
{
    imports = [ inputs.nixai.nixosModules.default ];

    services.nixai = lib.mkIf config.customConfig.services.nixai.enable {
        enable = true;
        mcp.enable = true;
    };

}
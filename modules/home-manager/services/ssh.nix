{ config, lib, pkgs, customConfig, ... }:

let
    sshEnable = customConfig.services.ssh.enable;
    isLandoPC = customConfig.user.name == "lando";
in
{
    config = lib.mkIf (sshEnable && isLandoPC) {
        programs.ssh = {

            enable = true;
            enableDefaultConfig = false;

            matchBlocks = {
            "openbsd-t620" = {
                hostname = "192.168.1.136";
                user = "lando";
            };

            "optiplex-nas" = {
                hostname = "192.168.1.76";
                user = "lando";
            };

            "atl-mini-pc" = {
                hostname = "192.168.1.206";
                user = "heather";
            };

            "asus-m15" = {
                hostname = "192.168.1.57";
                user = "lando";
            };

            "mini-server" = {
                hostname = "192.168.100.103";
                user = "lando";
                proxyJump = "openbsd-t620";
            };

            "optiplex" = {
                hostname = "192.168.100.100";
                user = "lando";
                proxyJump = "openbsd-t620";
            };
            };

        };
    };
}
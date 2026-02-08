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
            "optiplex-fw" = {
                hostname = "192.168.1.189";
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

            "mini-server" = {
                hostname = "192.168.100.103";
                user = "lando";
                proxyJump = "optiplex-fw";
            };

            "optiplex" = {
                hostname = "192.168.100.100";
                user = "lando";
                proxyJump = "optiplex-fw";
            };
            };

        };
    };
}